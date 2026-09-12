import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/friends/data/friends_repository.dart';
import 'package:swipe_eat/features/friends/domain/vote_tally.dart';
import 'package:swipe_eat/features/friends/state/friends_controller.dart';
import 'package:swipe_eat/features/plans/models/plan_slot.dart';

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

  group('asking to join', () {
    test('the phone says what day it is, not the server', () async {
      // Same reason mark_plan_kept takes a date: the database clock is UTC
      // and Kuala Lumpur is +8, so a server-side "today" would close
      // tonight's plan eight hours early.
      final repository = FakeFriendsRepository();
      final controller = controllerFor(repository);

      await controller.askToJoin(501, DateTime(2026, 9, 12));

      expect(repository.joinRequests.single, (501, DateTime(2026, 9, 12)));
    });

    test('answering a request re-reads that one plan', () async {
      final repository = FakeFriendsRepository(
        planPeople: [testPlanPerson(7, 'u1', status: 'requested')],
      );
      final controller = controllerFor(repository);

      await controller.answerJoinRequest(7, 'u1', accept: true);

      expect(repository.joinAnswers.single, (7, 'u1', true));
      expect(repository.planPeopleAsked.single, [7]);
    });

    test('a plan that is not open to me raises rather than going quiet',
        () async {
      final repository = FakeFriendsRepository()
        ..failAskToJoinWith = StateError('That plan is not open to you.');
      final controller = controllerFor(repository);

      await expectLater(
        controller.askToJoin(501, DateTime(2026, 9, 12)),
        throwsStateError,
      );
    });
  });

  group('time votes', () {
    FakeFriendsRepository repositoryWithVotes() => FakeFriendsRepository(
          votes: [
            testPlanVote(PlanSlot.dinner, 'a'),
            testPlanVote(PlanSlot.supper, 'b'),
          ],
        );

    test('loadVotes reads one plan\'s tally', () async {
      final controller = controllerFor(repositoryWithVotes());

      await controller.loadVotes(7);

      expect(controller.votesFor(7), hasLength(2));
      expect(controller.votesFor(8), isEmpty);
    });

    test('a failed read leaves the page with no votes rather than an error',
        () async {
      final repository = repositoryWithVotes()..failVotesWith = 'nope';
      final controller = controllerFor(repository);

      await controller.loadVotes(7);

      expect(controller.votesFor(7), isEmpty);
      expect(controller.error, isNull);
    });

    test('a reset mid-read keeps the last account\'s tally out', () async {
      final controller = controllerFor(repositoryWithVotes());

      final inFlight = controller.loadVotes(7);
      controller.reset();
      await inFlight;

      expect(controller.votesFor(7), isEmpty);
    });

    test('voting sends the slot and then re-reads, rather than patching',
        () async {
      final repository = FakeFriendsRepository();
      final controller = controllerFor(repository);

      await controller.vote(7, time: '20:00:00');

      expect(repository.castVotes, [(7, '20:00:00', null)]);
      expect(repository.calls, ['vote', 'votes']);
    });

    test('changing my mind does not leave me voting twice', () async {
      final repository = FakeFriendsRepository(
        votes: [testPlanVote(PlanSlot.dinner, 'me')],
      );
      final controller = controllerFor(repository);
      await controller.loadVotes(7);

      // The server replaces the row; the fake stands in for that by handing
      // back the new tally on the next read.
      repository.setVotes([testPlanVote(PlanSlot.supper, 'me')]);
      await controller.vote(7, timeLabel: 'late');

      expect(controller.votesFor(7), hasLength(1));
      expect(controller.votesFor(7).single.slotKey, slotVoteKey(PlanSlot.supper));
    });

    test('answering an invite re-reads that plan\'s roster', () async {
      final repository = FakeFriendsRepository(
        planPeople: [testPlanPerson(7, 'a')],
      );
      final controller = controllerFor(repository);

      await controller.answerInvite(7, going: true);

      expect(repository.calls, ['answerInvite', 'planPeople']);
      expect(controller.peopleFor(7), hasLength(1));
    });

    test('votesFor hands back a list the caller cannot edit', () async {
      final controller = controllerFor(repositoryWithVotes());
      await controller.loadVotes(7);

      expect(
        () => controller.votesFor(7).add(testPlanVote(PlanSlot.noon, 'x')),
        throwsUnsupportedError,
      );
    });

    test('reset forgets the tallies with everything else', () async {
      final controller = controllerFor(repositoryWithVotes());
      await controller.loadVotes(7);

      controller.reset();

      expect(controller.votesFor(7), isEmpty);
    });
  });
}
