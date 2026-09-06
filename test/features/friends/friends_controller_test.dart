import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/friends/data/friends_repository.dart';
import 'package:swipe_eat/features/friends/state/friends_controller.dart';

import 'fake_friends_repository.dart';

/// The controller never touches `Supabase.instance` in these tests, and never
/// subscribes to auth: `followAuthChanges: false` is what keeps a unit test
/// off the singleton.
FriendsController controllerFor(FakeFriendsRepository repository) {
  return FriendsController(
    repository: repository,
    followAuthChanges: false,
  );
}

void main() {
  group('loading', () {
    test('ensureLoaded reads once, however many callers ask', () async {
      final repository = FakeFriendsRepository(
        friends: [testFriend('a', name: 'Aiman Zulkifli')],
      );
      final controller = controllerFor(repository);

      await Future.wait([
        controller.ensureLoaded(),
        controller.ensureLoaded(),
        controller.ensureLoaded(),
      ]);

      expect(repository.calls.where((c) => c == 'friends'), hasLength(1));
      expect(controller.count, 1);
      expect(controller.isLoaded, isTrue);
    });

    test('a second ensureLoaded after the first landed does not refetch',
        () async {
      final repository = FakeFriendsRepository(friends: [testFriend('a')]);
      final controller = controllerFor(repository);

      await controller.ensureLoaded();
      await controller.ensureLoaded();

      expect(repository.calls.where((c) => c == 'friends'), hasLength(1));
    });

    test('a failed load is not cached — the next call retries', () async {
      final repository = FakeFriendsRepository(friends: [testFriend('a')])
        ..failWith = StateError('offline');
      final controller = controllerFor(repository);

      await controller.ensureLoaded();
      expect(controller.error, isNotNull);
      expect(controller.isLoaded, isFalse);

      repository.failWith = null;
      await controller.ensureLoaded();

      expect(controller.error, isNull);
      expect(controller.count, 1);
    });

    test('a failed request list still lets the friends land', () async {
      // The friends are what four other screens wait on; a pending-request
      // badge is worth losing before a whole page is.
      final repository = FakeFriendsRepository(friends: [testFriend('a')])
        ..failRequestsWith = StateError('nope');
      final controller = controllerFor(repository);

      await controller.ensureLoaded();

      expect(controller.count, 1);
      expect(controller.requests, isEmpty);
      expect(controller.error, isNull);
    });

    test('notifies its listeners on load', () async {
      final repository = FakeFriendsRepository(friends: [testFriend('a')]);
      final controller = controllerFor(repository);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.ensureLoaded();

      expect(notifications, greaterThan(0));
    });
  });

  group('the name cache', () {
    test('answers "what is this id called"', () async {
      final repository = FakeFriendsRepository(
        friends: [
          testFriend('a', name: 'Aiman Zulkifli'),
          testFriend('b', name: 'Mei Kee Tan'),
        ],
      );
      final controller = controllerFor(repository);
      await controller.ensureLoaded();

      expect(controller.nameFor('a'), 'Aiman Zulkifli');
      expect(controller.nameFor('b'), 'Mei Kee Tan');
    });

    test('a stranger has no name, rather than a made-up one', () async {
      // The wishlist row already knows how to say "From a friend"; a controller
      // that invented "Someone" would take that decision away from it.
      final repository = FakeFriendsRepository(friends: [testFriend('a')]);
      final controller = controllerFor(repository);
      await controller.ensureLoaded();

      expect(controller.nameFor('nobody'), isNull);
      expect(controller.profileFor('nobody'), isNull);
      expect(controller.nameFor(null), isNull);
    });
  });

  group('requests', () {
    test('only an incoming request is one I can answer', () async {
      final repository = FakeFriendsRepository(
        requests: [
          testRequest('a', name: 'Aiman', incoming: true),
          testRequest('b', name: 'Mei Kee', incoming: false),
        ],
      );
      final controller = controllerFor(repository);
      await controller.ensureLoaded();

      expect(controller.requests, hasLength(2));
      expect(controller.incomingRequests, hasLength(1));
      expect(controller.incomingRequests.single.profile.id, 'a');
      // And the other half is the one the friends page shows under "Waiting
      // to hear back": still not a thing to do, but a thing to see.
      expect(controller.outgoingRequests, hasLength(1));
      expect(controller.outgoingRequests.single.profile.id, 'b');
    });

    test('accepting moves a person from requests into friends', () async {
      final repository = FakeFriendsRepository(
        requests: [testRequest('a', name: 'Aiman Zulkifli')],
      );
      final controller = controllerFor(repository);
      await controller.ensureLoaded();

      await controller.act('a', FriendAction.accept);

      expect(controller.requests, isEmpty);
      expect(controller.count, 1);
      expect(controller.nameFor('a'), 'Aiman Zulkifli');
    });

    test('declining drops the request without adding a friend', () async {
      final repository = FakeFriendsRepository(
        requests: [testRequest('a')],
      );
      final controller = controllerFor(repository);
      await controller.ensureLoaded();

      await controller.act('a', FriendAction.decline);

      expect(controller.requests, isEmpty);
      expect(controller.count, 0);
    });

    test('removing a friend drops them from the cache too', () async {
      final repository = FakeFriendsRepository(
        friends: [testFriend('a'), testFriend('b')],
      );
      final controller = controllerFor(repository);
      await controller.ensureLoaded();

      await controller.act('a', FriendAction.remove);

      expect(controller.count, 1);
      expect(controller.nameFor('a'), isNull);
    });
  });

  group('contact matching', () {
    test('hashes on the way past — a raw number never reaches the wire',
        () async {
      final repository = FakeFriendsRepository(matches: [testFriend('a')]);
      final controller = controllerFor(repository);

      await controller.matchContacts(['012-345 6789']);

      final sent = repository.sentHashes.single;
      expect(sent, hasLength(1));
      expect(sent.single, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(sent.single, isNot(contains('123456789')));
    });

    test('sending requests for the picked people refreshes the list', () async {
      final repository = FakeFriendsRepository();
      final controller = controllerFor(repository);
      await controller.ensureLoaded();
      repository.calls.clear();

      final sent = await controller.sendRequests(['a', 'b', 'c']);

      expect(sent, 3);
      expect(
        repository.actions.map((a) => a.$1),
        ['a', 'b', 'c'],
      );
      expect(
        repository.actions.every((a) => a.$2 == FriendAction.send),
        isTrue,
      );
      expect(repository.calls, contains('friends'));
    });

    test('sending nothing sends nothing, and does not refetch', () async {
      // Skip's contract, one layer down from the screen that owns it.
      final repository = FakeFriendsRepository();
      final controller = controllerFor(repository);
      await controller.ensureLoaded();
      repository.calls.clear();

      final sent = await controller.sendRequests(const []);

      expect(sent, 0);
      expect(repository.actions, isEmpty);
      expect(repository.calls, isNot(contains('friends')));
    });
  });

  group('reset', () {
    test('empties the cache so the next account starts clean', () async {
      final repository = FakeFriendsRepository(
        friends: [testFriend('a')],
        requests: [testRequest('b')],
      );
      final controller = controllerFor(repository);
      await controller.ensureLoaded();

      controller.reset();

      expect(controller.count, 0);
      expect(controller.requests, isEmpty);
      expect(controller.isLoaded, isFalse);
      expect(controller.nameFor('a'), isNull);
    });

    test(
        'a load in flight when reset lands cannot publish into the next '
        'account', () async {
      final repository = FakeFriendsRepository(friends: [testFriend('a')]);
      final controller = controllerFor(repository);

      final inFlight = controller.ensureLoaded();
      controller.reset();
      await inFlight;

      expect(controller.count, 0);
      expect(controller.isLoaded, isFalse);
    });
  });

  group('plan rosters', () {
    FakeFriendsRepository repositoryWithPeople() => FakeFriendsRepository(
          friends: [testFriend('a', name: 'Aiman Zulkifli')],
          planPeople: [
            testPlanPerson(1, 'a', name: 'Aiman Zulkifli', status: 'going'),
            testPlanPerson(1, 'z', name: 'Zara Khan', status: 'invited'),
            testPlanPerson(2, 'q', name: 'Quinn Lee', status: 'declined'),
          ],
        );

    test('a month of plans is one call, not one per card', () async {
      final repository = repositoryWithPeople();
      final controller = controllerFor(repository);

      await controller.loadPlanPeople([1, 2, 3]);

      expect(repository.planPeopleAsked, hasLength(1));
      expect(repository.planPeopleAsked.single, containsAll([1, 2, 3]));
    });

    test('groups the rows onto the plan each belongs to', () async {
      final controller = controllerFor(repositoryWithPeople());

      await controller.loadPlanPeople([1, 2]);

      expect(
        controller.peopleFor(1).map((person) => person.profile.name),
        ['Aiman Zulkifli', 'Zara Khan'],
      );
      expect(controller.peopleFor(2).single.status, 'declined');
    });

    test('a plan with nobody on it comes back empty, not missing', () async {
      // The calendar asks for every plan in the month; one with no guests must
      // answer "nobody" rather than leave the card waiting on a load that
      // already happened.
      final controller = controllerFor(repositoryWithPeople());

      await controller.loadPlanPeople([1, 9]);

      expect(controller.peopleFor(9), isEmpty);
    });

    test('names a guest who is not one of your friends', () async {
      // The reason this cache exists at all: Zara is on the plan and is a
      // stranger to me, so the friends map cannot name her and the card would
      // otherwise draw a blank face.
      final controller = controllerFor(repositoryWithPeople());

      await controller.loadPlanPeople([1]);

      expect(controller.nameFor('z'), isNull);
      expect(controller.peopleFor(1).last.profile.name, 'Zara Khan');
    });

    test('asking for nothing asks the server nothing', () async {
      final repository = repositoryWithPeople();
      final controller = controllerFor(repository);

      await controller.loadPlanPeople(const []);

      expect(repository.calls, isEmpty);
    });

    test('tells its listeners once the roster is in', () async {
      final controller = controllerFor(repositoryWithPeople());
      var notifications = 0;
      controller.addListener(() => notifications += 1);

      await controller.loadPlanPeople([1]);

      expect(notifications, 1);
    });

    test('a failed load leaves the rosters already held alone', () async {
      // A card that has been drawing "3 friends · 2 confirmed" should keep
      // saying so when the next month fails to load, rather than emptying.
      final repository = repositoryWithPeople();
      final controller = controllerFor(repository);
      await controller.loadPlanPeople([1]);

      repository.failPlanPeopleWith = Exception('offline');
      await controller.loadPlanPeople([2]);

      expect(controller.peopleFor(1), hasLength(2));
    });

    test('a roster in flight when reset lands is dropped', () async {
      final repository = repositoryWithPeople();
      final controller = controllerFor(repository);

      final inFlight = controller.loadPlanPeople([1]);
      controller.reset();
      await inFlight;

      expect(controller.peopleFor(1), isEmpty);
    });

    test('reset forgets the rosters with everything else', () async {
      final controller = controllerFor(repositoryWithPeople());
      await controller.loadPlanPeople([1]);

      controller.reset();

      expect(controller.peopleFor(1), isEmpty);
    });

    test('peopleFor hands back a list the caller cannot edit', () async {
      final controller = controllerFor(repositoryWithPeople());
      await controller.loadPlanPeople([1]);

      expect(
        () => controller.peopleFor(1).add(testPlanPerson(1, 'x')),
        throwsUnsupportedError,
      );
    });
  });
}
