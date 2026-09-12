import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swipe_eat/features/plans/data/plans_repository.dart';
import 'package:swipe_eat/features/plans/domain/plan_labels.dart';
import 'package:swipe_eat/features/plans/models/friend_plan.dart';
import 'package:swipe_eat/features/plans/models/plan.dart';
import 'package:swipe_eat/features/plans/state/plans_controller.dart';
import 'package:swipe_eat/features/restaurants/state/likes_controller.dart';

import 'fake_plans_repository.dart';

/// Drives the controller's auth subscription without a Supabase singleton,
/// the same seam [LikesController]'s own tests use.
class _FakeAuthEvents extends LikesAuthEvents {
  _FakeAuthEvents({this.userId});

  String? userId;
  // Lives for the length of one test and dies with it.
  // ignore: close_sinks
  final StreamController<AuthState> events = StreamController.broadcast();

  @override
  Stream<AuthState>? get changes => events.stream;

  @override
  String? get currentUserId => userId;
}

AuthState _signedIn(String userId) {
  final user = User(
    id: userId,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-08-24T00:00:00Z',
  );
  return AuthState(
    AuthChangeEvent.signedIn,
    Session(accessToken: 'token', tokenType: 'bearer', user: user),
  );
}

/// A Wednesday, which is what the prototype's calendar is drawn on. Every
/// label in these tests is a statement about this instant.
final DateTime kNow = DateTime(2026, 9, 2, 11);

PlansController buildController(
  FakePlansRepository repository, {
  DateTime? now,
  LikesController? likes,
}) {
  return PlansController(
    repository: repository,
    clock: () => now ?? kNow,
    followAuthChanges: false,
    likes: likes,
  );
}

void main() {
  group('PlansController auth following', () {
    PlansController following(
      FakePlansRepository repository,
      _FakeAuthEvents auth, {
      LikesController? likes,
    }) {
      return PlansController(
        repository: repository,
        clock: () => kNow,
        authEvents: auth,
        likes: likes,
      );
    }

    test('the replayed signedIn for the current account is not a change',
        () async {
      // Supabase replays its latest event to every new listener, so a
      // fresh-login launch sees signedIn for the account already loaded.
      // Treating that as a switch would empty the calendar it just filled.
      final repository = FakePlansRepository(
        rows: [testPlan(1, date: DateTime(2026, 9, 4))],
      );
      final auth = _FakeAuthEvents(userId: 'user-a');
      final controller = following(repository, auth);
      addTearDown(() {
        controller.dispose();
        auth.events.close();
      });
      await controller.ensureLoaded();

      auth.events.add(_signedIn('user-a'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.isLoaded, isTrue);
      expect(controller.upcoming, hasLength(1));
    });

    test('an actual account change dumps the calendar', () async {
      final repository = FakePlansRepository(
        rows: [testPlan(1, restaurantId: 306, date: DateTime(2026, 9, 4))],
      );
      final auth = _FakeAuthEvents(userId: 'user-a');
      final likes = LikesController(followAuthChanges: false);
      final controller = following(repository, auth, likes: likes);
      addTearDown(() {
        controller.dispose();
        likes.dispose();
        auth.events.close();
      });
      await controller.ensureLoaded();
      expect(likes.plannedRestaurantIds, {306});

      auth.events.add(_signedIn('user-b'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.isLoaded, isFalse);
      expect(controller.plans, isEmpty);
      expect(likes.plannedRestaurantIds, isEmpty,
          reason: "user A's plans must not mark tiles in user B's session");
    });

    test('signing out clears the calendar', () async {
      final repository = FakePlansRepository(
        rows: [testPlan(1, date: DateTime(2026, 9, 4))],
      );
      final auth = _FakeAuthEvents(userId: 'user-a');
      final controller = following(repository, auth);
      addTearDown(() {
        controller.dispose();
        auth.events.close();
      });
      await controller.ensureLoaded();

      auth.events.add(const AuthState(AuthChangeEvent.signedOut, null));
      await Future<void>.delayed(Duration.zero);

      expect(controller.isLoaded, isFalse);
      expect(controller.plans, isEmpty);
      expect(controller.stats.plansKept, 0);
    });
  });

  group('PlansController loading', () {
    test(
        'flips past plans before it lists, and asks from the first of the '
        'month', () async {
      final repository = FakePlansRepository(
        rows: [
          testPlan(1, date: DateTime(2026, 9, 1)),
          testPlan(2, restaurantId: 7, date: DateTime(2026, 9, 4)),
        ],
      );
      final controller = buildController(repository);
      addTearDown(controller.dispose);

      await controller.ensureLoaded();

      expect(repository.markedKeptOn.single, DateTime(2026, 9, 2));
      expect(repository.listedFrom.single, DateTime(2026, 9, 1));
      expect(repository.statsFor.single, DateTime(2026, 9, 2));
      // The 1st was in the past, so it came back kept rather than planned.
      expect(
        controller.plans.firstWhere((plan) => plan.id == 1).status,
        PlanStatus.kept,
      );
      expect(controller.isLoaded, isTrue);
      expect(controller.error, isNull);
    });

    test('loads once; a second call does not re-ask', () async {
      final repository = FakePlansRepository();
      final controller = buildController(repository);
      addTearDown(controller.dispose);

      await Future.wait([controller.ensureLoaded(), controller.ensureLoaded()]);
      await controller.ensureLoaded();

      expect(repository.listedFrom, hasLength(1));
    });

    test('a failed flip still lets the calendar load', () async {
      final repository = FakePlansRepository(
        rows: [testPlan(1, date: DateTime(2026, 9, 4))],
      )..failMarkKept = StateError('offline');
      final controller = buildController(repository);
      addTearDown(controller.dispose);

      await controller.ensureLoaded();

      expect(controller.error, isNull);
      expect(controller.plans, hasLength(1));
    });

    test('a failed list is reported and retried by the next call', () async {
      final repository = FakePlansRepository()
        ..failList = StateError('offline');
      final controller = buildController(repository);
      addTearDown(controller.dispose);

      await controller.ensureLoaded();
      expect(controller.error, 'Could not load your plans.');
      expect(controller.isLoaded, isFalse);

      await controller.ensureLoaded();
      expect(controller.error, isNull);
      expect(controller.isLoaded, isTrue);
      expect(repository.listedFrom, hasLength(2));
    });

    test('stats come through for the You tab', () async {
      final repository = FakePlansRepository(
        stats: const PlanStats(plansKept: 12, streakWeeks: 3),
      );
      final controller = buildController(repository);
      addTearDown(controller.dispose);

      await controller.ensureLoaded();

      expect(controller.stats.plansKept, 12);
      expect(controller.stats.streakWeeks, 3);
    });
  });

  group('PlansController labels', () {
    test('today before six is Today, after six is Tonight', () async {
      final repository = FakePlansRepository(
        rows: [
          testPlan(1,
              restaurantId: 11,
              date: DateTime(2026, 9, 2),
              hour: 12,
              minute: 30),
          testPlan(2, restaurantId: 22, date: DateTime(2026, 9, 2), hour: 20),
          testPlan(3,
              restaurantId: 33,
              date: DateTime(2026, 9, 2),
              hour: null,
              minute: null,
              timeLabel: 'late'),
        ],
      );
      final controller = buildController(repository);
      addTearDown(controller.dispose);
      await controller.ensureLoaded();

      expect(controller.plannedLabelFor(11), 'Today');
      expect(controller.plannedLabelFor(22), 'Tonight');
      expect(controller.plannedLabelFor(33), 'Tonight');
    });

    test('this month is "Fri 4"; a later month carries the month', () async {
      final repository = FakePlansRepository(
        rows: [
          testPlan(1, restaurantId: 11, date: DateTime(2026, 9, 4)),
          testPlan(2, restaurantId: 22, date: DateTime(2026, 10, 10)),
        ],
      );
      final controller = buildController(repository);
      addTearDown(controller.dispose);
      await controller.ensureLoaded();

      expect(controller.plannedLabelFor(11), 'Fri 4');
      expect(controller.plannedLabelFor(22), 'Sat 10 Oct');
    });

    test('the soonest plan wins when a place has two', () async {
      final repository = FakePlansRepository(
        rows: [
          testPlan(1, restaurantId: 11, date: DateTime(2026, 9, 20)),
          testPlan(2, restaurantId: 11, date: DateTime(2026, 9, 4)),
        ],
      );
      final controller = buildController(repository);
      addTearDown(controller.dispose);
      await controller.ensureLoaded();

      expect(controller.plannedLabelFor(11), 'Fri 4');
      expect(controller.plannedLabels[11], 'Fri 4');
    });

    test('a place with no plan has no label', () async {
      final controller = buildController(FakePlansRepository());
      addTearDown(controller.dispose);
      await controller.ensureLoaded();

      expect(controller.plannedLabelFor(99), isNull);
      expect(controller.isEmpty, isTrue);
    });

    test('a dinner that already happened is not planned any more', () async {
      final repository = FakePlansRepository(
        rows: [testPlan(1, restaurantId: 11, date: DateTime(2026, 9, 1))],
      );
      final controller = buildController(repository);
      addTearDown(controller.dispose);
      await controller.ensureLoaded();

      expect(controller.plans, hasLength(1));
      expect(controller.plannedRestaurantIds, isEmpty);
      expect(controller.plannedLabelFor(11), isNull);
    });
  });

  group('PlansController grouping', () {
    test('plansOn puts Late last', () async {
      final repository = FakePlansRepository(
        rows: [
          testPlan(1,
              date: DateTime(2026, 9, 4),
              hour: null,
              minute: null,
              timeLabel: 'late'),
          testPlan(2,
              restaurantId: 7,
              date: DateTime(2026, 9, 4),
              hour: 12,
              minute: 30),
          testPlan(3, restaurantId: 8, date: DateTime(2026, 9, 5)),
        ],
      );
      final controller = buildController(repository);
      addTearDown(controller.dispose);
      await controller.ensureLoaded();

      expect(
        controller.plansOn(DateTime(2026, 9, 4)).map((plan) => plan.id),
        [2, 1],
      );
      expect(controller.plannedDaysIn(DateTime(2026, 9)), {4, 5});
      expect(controller.plannedDaysIn(DateTime(2026, 10)), isEmpty);
    });

    test('upcoming keeps today and drops yesterday', () async {
      final repository = FakePlansRepository(
        rows: [
          testPlan(1, date: DateTime(2026, 9, 1)),
          testPlan(2, restaurantId: 7, date: DateTime(2026, 9, 2), hour: 9),
          testPlan(3, restaurantId: 8, date: DateTime(2026, 9, 9)),
        ],
      );
      final controller = buildController(repository);
      addTearDown(controller.dispose);
      await controller.ensureLoaded();

      expect(controller.upcoming.map((plan) => plan.id), [2, 3]);
    });
  });

  group('PlansController writing', () {
    test('create passes the day through and refreshes', () async {
      final repository = FakePlansRepository();
      final controller = buildController(repository);
      addTearDown(controller.dispose);
      await controller.ensureLoaded();

      final id = await controller.create(
        restaurantId: 306,
        date: DateTime(2026, 9, 4),
        time: '20:00:00',
        withFriends: true,
      );

      expect(repository.created.single, {
        'restaurantId': 306,
        'date': '2026-09-04',
        'time': '20:00:00',
        'timeLabel': null,
        'withFriends': true,
        'shared': false,
      });
      expect(controller.plans.single.id, id);
      expect(repository.listedFrom, hasLength(2));
    });

    test(
        'cancel drops the row before the server answers, and puts it back '
        'when the server refuses', () async {
      final repository = FakePlansRepository(
        rows: [testPlan(1, date: DateTime(2026, 9, 4))],
      );
      final controller = buildController(repository);
      addTearDown(controller.dispose);
      await controller.ensureLoaded();

      repository.failCancel = StateError('offline');
      await expectLater(controller.cancel(1), throwsStateError);
      expect(controller.plans, hasLength(1));

      await controller.cancel(1);
      expect(controller.plans, isEmpty);
      expect(repository.cancelled, [1, 1]);
    });

    test('a plan made with the switch on is created shared', () async {
      final repository = FakePlansRepository();
      final controller = buildController(repository);
      addTearDown(controller.dispose);
      await controller.ensureLoaded();

      await controller.create(
        restaurantId: 306,
        date: DateTime(2026, 9, 4),
        shared: true,
      );

      expect(repository.created.single['shared'], isTrue);
      expect(controller.plans.single.sharedWithFriends, isTrue);
    });

    test('setShared writes the flag and re-reads the row', () async {
      final repository = FakePlansRepository(
        rows: [testPlan(1, date: DateTime(2026, 9, 4))],
      );
      final controller = buildController(repository);
      addTearDown(controller.dispose);
      await controller.ensureLoaded();
      expect(controller.plans.single.sharedWithFriends, isFalse);

      await controller.setShared(1, true);

      expect(repository.sharedSet.single, (1, true));
      expect(controller.plans.single.sharedWithFriends, isTrue);
    });

    test('setTime moves the slot and re-reads', () async {
      final repository = FakePlansRepository(
        rows: [testPlan(1, date: DateTime(2026, 9, 4))],
      );
      final controller = buildController(repository);
      addTearDown(controller.dispose);
      await controller.ensureLoaded();

      await controller.setTime(1, timeLabel: 'late');

      expect(repository.retimed.single, {
        'planId': 1,
        'time': null,
        'timeLabel': 'late',
      });
      expect(repository.listedFrom, hasLength(2));
    });

    test('reset forgets the account and reloads on the next ensureLoaded',
        () async {
      final repository = FakePlansRepository(
        rows: [testPlan(1, date: DateTime(2026, 9, 4))],
      );
      final controller = buildController(repository);
      addTearDown(controller.dispose);
      await controller.ensureLoaded();
      expect(controller.plans, hasLength(1));

      controller.reset();
      expect(controller.plans, isEmpty);
      expect(controller.isLoaded, isFalse);

      await controller.ensureLoaded();
      expect(controller.plans, hasLength(1));
      expect(repository.listedFrom, hasLength(2));
    });
  });

  group("PlansController friends' plans", () {
    test('the calendar reads them from today, not the first of the month',
        () async {
      // The grid looks back to the first so a day already gone by still shows
      // a ring; a friend's evening that has already happened is not something
      // to ask to join.
      final repository = FakePlansRepository(
        friendPlans: [testFriendPlan(501, date: DateTime(2026, 9, 4))],
      );
      final controller = buildController(repository);
      addTearDown(controller.dispose);

      await controller.ensureLoaded();

      expect(repository.friendsListedFrom.single, DateTime(2026, 9, 2));
      expect(repository.listedFrom.single, DateTime(2026, 9, 1));
      expect(controller.friendsPlans.single.owner.name, 'Aisyah Rahman');
    });

    test('a server without the RPC still opens the calendar', () async {
      // Part B ships the client and the server separately, and a phone on the
      // old server must not lose its own evenings over a section it cannot
      // fill — the same rule the kept-flip follows.
      final repository = FakePlansRepository(
        rows: [testPlan(1, date: DateTime(2026, 9, 4))],
      );
      repository.failFriendsPlans = StateError('no such function');
      final controller = buildController(repository);
      addTearDown(controller.dispose);

      await controller.ensureLoaded();

      expect(controller.isLoaded, isTrue);
      expect(controller.error, isNull);
      expect(controller.plans, hasLength(1));
      expect(controller.friendsPlans, isEmpty);
    });

    test('reset drops them with the rest of the account', () async {
      final repository = FakePlansRepository(
        friendPlans: [testFriendPlan(501, date: DateTime(2026, 9, 4))],
      );
      final controller = buildController(repository);
      addTearDown(controller.dispose);
      await controller.ensureLoaded();
      expect(controller.friendsPlans, hasLength(1));

      controller.reset();

      expect(controller.friendsPlans, isEmpty);
    });
  });

  group('FriendPlan', () {
    test('decodes the row get_friends_plans sends', () {
      final plan = FriendPlan.fromJson(<String, dynamic>{
        'plan_id': 501,
        'owner_id': 'aisyah',
        'owner_name': 'Aisyah Rahman',
        'owner_avatar_url': '',
        'restaurant_id': 201,
        'restaurant_name': 'Nasi Kandar Pelita',
        'cover_url': 'https://a.example/1.jpg',
        'plan_date': '2026-09-04',
        'plan_time': '19:30:00',
        'time_label': null,
        'going_count': 3,
        'going_friends': <dynamic>[
          <String, dynamic>{'user_id': 'farah', 'name': 'Farah Idris'},
        ],
        'asked': true,
      });

      expect(plan.id, 501);
      expect(plan.owner.name, 'Aisyah Rahman');
      // An empty avatar is no avatar, not an empty URL to fetch.
      expect(plan.owner.avatarUrl, isNull);
      expect(plan.date, DateTime(2026, 9, 4));
      expect(plan.timeText, '19:30');
      expect(plan.goingCount, 3);
      expect(plan.goingFriends.single.name, 'Farah Idris');
      expect(plan.asked, isTrue);
    });

    test('a label-only plan reads back as the label', () {
      final plan = FriendPlan.fromJson(<String, dynamic>{
        'plan_id': 502,
        'owner_id': 'aiman',
        'owner_name': 'Aiman Zulkifli',
        'restaurant_id': 202,
        'restaurant_name': 'Sate Kajang',
        'plan_date': '2026-09-05',
        'plan_time': null,
        'time_label': 'late',
        'going_count': 0,
      });

      expect(plan.timeText, 'Late');
      expect(plan.goingFriends, isEmpty);
      expect(plan.asked, isFalse);
    });
  });

  group('PlansController feeds the Bites chips', () {
    test('a loaded plan marks its restaurant planned on LikesController',
        () async {
      final likes = LikesController(followAuthChanges: false);
      addTearDown(likes.dispose);
      final repository = FakePlansRepository(
        rows: [
          testPlan(1, restaurantId: 306, date: DateTime(2026, 9, 4)),
          testPlan(2, restaurantId: 42, date: DateTime(2026, 9, 1)),
        ],
      );
      final controller = buildController(repository, likes: likes);
      addTearDown(controller.dispose);

      expect(likes.plannedRestaurantIds, isEmpty);

      await controller.ensureLoaded();

      // Only the upcoming one: the 1st has already been and gone.
      expect(likes.plannedRestaurantIds, {306});
    });

    test('cancelling a plan clears the tile, and reset empties the set',
        () async {
      final likes = LikesController(followAuthChanges: false);
      addTearDown(likes.dispose);
      final repository = FakePlansRepository(
        rows: [testPlan(1, restaurantId: 306, date: DateTime(2026, 9, 4))],
      );
      final controller = buildController(repository, likes: likes);
      addTearDown(controller.dispose);
      await controller.ensureLoaded();
      expect(likes.plannedRestaurantIds, {306});

      await controller.cancel(1);
      expect(likes.plannedRestaurantIds, isEmpty);

      controller.reset();
      expect(likes.plannedRestaurantIds, isEmpty);
    });
  });

  group('plan labels', () {
    test('daySectionTitle names today and tomorrow', () {
      expect(daySectionTitle(DateTime(2026, 9, 2), kNow), 'Today');
      expect(daySectionTitle(DateTime(2026, 9, 3), kNow), 'Tomorrow');
      expect(daySectionTitle(DateTime(2026, 9, 4), kNow), 'Fri 4');
      expect(daySectionTitle(DateTime(2026, 10, 4), kNow), 'Sun 4 Oct');
    });

    test('the picked summary reads back the whole answer', () {
      expect(
        pickedSummary(DateTime(2026, 9, 4), '20:00'),
        'Fri 4 Sep · 20:00',
      );
    });

    test('meal labels follow the deck', () {
      expect(planMealLabel(testPlan(1, date: kNow, hour: 12, minute: 30)),
          'Lunch');
      expect(planMealLabel(testPlan(1, date: kNow, hour: 20)), 'Dinner');
      expect(
        planMealLabel(
          testPlan(1, date: kNow, hour: null, minute: null, timeLabel: 'late'),
        ),
        'Supper',
      );
    });

    test('plan counts are singular at one', () {
      expect(planCount(1), '1 plan');
      expect(planCount(2), '2 plans');
    });

    test('month arithmetic rolls the year over and knows February', () {
      expect(monthTitle(DateTime(2026, 9)), 'September 2026');
      expect(addMonths(DateTime(2026, 12), 1), DateTime(2027, 1));
      expect(daysInMonth(DateTime(2028, 2)), 29);
      expect(daysInMonth(DateTime(2026, 2)), 28);
    });

    test('initials fall back to two letters of one word', () {
      expect(testPlan(1, date: kNow, name: 'Warung Kak Ros').initials, 'WK');
      expect(testPlan(1, date: kNow, name: 'Chapati').initials, 'CH');
    });
  });

  group('plan wire formats', () {
    test('a date is formatted from its local parts', () {
      expect(formatPlanDate(DateTime(2026, 9, 4)), '2026-09-04');
      expect(formatPlanDate(DateTime(2026, 12, 31, 23, 30)), '2026-12-31');
    });

    test('a malformed date lands on the epoch rather than throwing', () {
      expect(parsePlanDate(null).year, 1970);
      expect(parsePlanDate('nonsense').year, 1970);
      expect(parsePlanDate('2026-09-04'), DateTime(2026, 9, 4));
    });

    test('a row decodes with its cover taken in position order', () {
      final plan = Plan.fromJson(<String, dynamic>{
        'id': 5,
        'restaurant_id': 306,
        'plan_date': '2026-09-04',
        'plan_time': '20:00:00',
        'time_label': null,
        'with_friends': true,
        'status': 'planned',
        'restaurants': <String, dynamic>{
          'id': 306,
          'name': 'Warung Kak Ros',
          'tag': 'Nasi lemak',
          'neighbourhood': 'Kepong',
          'latitude': 3.2,
          'longitude': 101.6,
          'restaurant_images': <dynamic>[
            <String, dynamic>{'url': 'https://b.example/2.jpg', 'position': 2},
            <String, dynamic>{'url': 'https://a.example/1.jpg', 'position': 1},
          ],
        },
        'plan_members': <dynamic>[
          <String, dynamic>{'user_id': 'u1', 'status': 'going'},
        ],
      });

      expect(plan.coverUrl, 'https://a.example/1.jpg');
      expect(plan.timeText, '20:00');
      expect(plan.neighbourhood, 'Kepong');
      expect(plan.members.single.isGoing, isTrue);
      expect(plan.status, PlanStatus.planned);
    });

    test('stats decode from the RPC row', () {
      final stats = PlanStats.fromJson(<String, dynamic>{
        'plans_kept': 12,
        'streak_weeks': 3,
      });
      expect(stats.plansKept, 12);
      expect(stats.streakWeeks, 3);

      const empty = PlanStats();
      expect(empty.plansKept, 0);
      expect(empty.streakWeeks, 0);
    });
  });
}
