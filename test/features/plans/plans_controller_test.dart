import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/plans/data/plans_repository.dart';
import 'package:swipe_eat/features/plans/domain/plan_labels.dart';
import 'package:swipe_eat/features/plans/models/plan.dart';
import 'package:swipe_eat/features/plans/state/plans_controller.dart';
import 'package:swipe_eat/features/restaurants/state/likes_controller.dart';

import 'fake_plans_repository.dart';

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
  group('PlansController loading', () {
    test('flips past plans before it lists, and asks from the first of the '
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
      final repository = FakePlansRepository()..failList = StateError('offline');
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
          testPlan(1, restaurantId: 11, date: DateTime(2026, 9, 2), hour: 12,
              minute: 30),
          testPlan(2, restaurantId: 22, date: DateTime(2026, 9, 2), hour: 20),
          testPlan(3, restaurantId: 33, date: DateTime(2026, 9, 2), hour: null,
              minute: null, timeLabel: 'late'),
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
          testPlan(1, date: DateTime(2026, 9, 4), hour: null, minute: null,
              timeLabel: 'late'),
          testPlan(2, restaurantId: 7, date: DateTime(2026, 9, 4), hour: 12,
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
      });
      expect(controller.plans.single.id, id);
      expect(repository.listedFrom, hasLength(2));
    });

    test('cancel drops the row before the server answers, and puts it back '
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
