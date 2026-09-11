import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/dashboard/state/dashboard_tab_request.dart';
import 'package:swipe_eat/features/friends/presentation/friend_avatar.dart';
import 'package:swipe_eat/features/friends/state/friends_controller.dart';
import 'package:swipe_eat/features/plans/models/plan.dart';
import 'package:swipe_eat/features/plans/presentation/calendar_tab.dart';
import 'package:swipe_eat/features/plans/state/plans_controller.dart';

import '../../support/widget_test_support.dart';
import '../friends/fake_friends_repository.dart';
import 'fake_plans_repository.dart';

const Size _phoneViewport = Size(390, 844);
const Size _narrowViewport = Size(320, 568);

/// The Wednesday the prototype's calendar is drawn on.
final DateTime _now = DateTime(2026, 9, 2, 11);

/// Kuala Lumpur, so a plan with coordinates gets a real distance.
Position _kualaLumpur() {
  return Position(
    longitude: 101.6869,
    latitude: 3.1390,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

/// The two plans the design's own screenshot lists under "Today".
List<Plan> _designPlans() {
  return [
    testPlan(1,
        restaurantId: 11,
        date: DateTime(2026, 9, 2),
        hour: 12,
        minute: 30,
        name: 'Warung Kak Ros',
        neighbourhood: 'Kepong',
        latitude: 3.1950,
        longitude: 101.6320),
    testPlan(2,
        restaurantId: 22,
        date: DateTime(2026, 9, 2),
        hour: 20,
        name: 'Kuey Teow Ah Seng',
        neighbourhood: 'Pudu'),
    testPlan(3,
        restaurantId: 33,
        date: DateTime(2026, 9, 4),
        hour: 21,
        minute: 30,
        name: 'Chapati',
        neighbourhood: 'Brickfields'),
  ];
}

/// The design's third plan card: four people asked, one of whom said no.
List<Plan> _partyPlans() {
  return [
    testPlan(
      1,
      restaurantId: 11,
      date: DateTime(2026, 9, 4),
      hour: 20,
      name: 'Warung Kak Ros',
      neighbourhood: 'Kampung Baru',
      withFriends: true,
      members: const [
        PlanMember(userId: 'aiman', status: 'going'),
        PlanMember(userId: 'mei', status: 'going'),
        PlanMember(userId: 'syafiq', status: 'invited'),
        PlanMember(userId: 'nadia', status: 'declined'),
      ],
    ),
  ];
}

/// The same four people, with the names and faces `plan.members` cannot carry.
FakeFriendsRepository _partyRoster() {
  return FakeFriendsRepository(
    planPeople: [
      testPlanPerson(1, 'aiman', name: 'Aiman Zulkifli', status: 'going'),
      testPlanPerson(1, 'mei', name: 'Mei Kee Tan', status: 'going'),
      testPlanPerson(1, 'syafiq', name: 'Syafiq Yusof'),
      testPlanPerson(1, 'nadia', name: 'Nadia Rahim', status: 'declined'),
    ],
  );
}

class _Harness {
  _Harness(
    this.controller,
    this.repository,
    this.friends,
    this.friendsRepository,
    this.tabs,
    this.pushed,
  );

  final PlansController controller;
  final FakePlansRepository repository;
  final FriendsController friends;
  final FakeFriendsRepository friendsRepository;
  final DashboardTabRequest tabs;
  final List<String> pushed;
}

Future<_Harness> _pumpTab(
  WidgetTester tester, {
  List<Plan> rows = const [],
  FakePlansRepository? repository,
  FakeFriendsRepository? friendsRepository,
  Size viewport = _phoneViewport,
  TextScaler textScaler = TextScaler.noScaling,
  Position? position,
}) async {
  useViewport(tester, viewport);
  final backing = repository ?? FakePlansRepository(rows: rows);
  final controller = PlansController(
    repository: backing,
    clock: () => _now,
    followAuthChanges: false,
  );
  addTearDown(controller.dispose);
  final friendsBacking = friendsRepository ?? FakeFriendsRepository();
  final friends = FriendsController(
    repository: friendsBacking,
    followAuthChanges: false,
  );
  addTearDown(friends.dispose);
  final tabs = DashboardTabRequest();
  addTearDown(tabs.dispose);
  final pushed = <String>[];

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          backgroundColor: kBackgroundDark,
          body: CalendarTab(
            controller: controller,
            friends: friends,
            tabRequests: tabs,
            resolvePosition: () async => position ?? _kualaLumpur(),
          ),
        ),
      ),
      GoRoute(
        path: '/restaurant/:id',
        builder: (context, state) {
          pushed.add('/restaurant/${state.pathParameters['id']}');
          return const Scaffold(body: Text('detail'));
        },
      ),
      GoRoute(
        path: '/plans/:id',
        builder: (context, state) {
          pushed.add('/plans/${state.pathParameters['id']}');
          return const Scaffold(body: Text('plan'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _Harness(
    controller,
    backing,
    friends,
    friendsBacking,
    tabs,
    pushed,
  );
}

void main() {
  setUpAll(() => HttpOverrides.global = ImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  group('CalendarTab chrome', () {
    testWidgets('titles itself and offers both actions', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpTab(tester, rows: _designPlans());

      expect(find.text('Calendar'), findsOneWidget);
      expect(find.bySemanticsLabel('Search plans'), findsOneWidget);
      expect(find.bySemanticsLabel('New plan'), findsOneWidget);
      expect(find.text('September 2026'), findsOneWidget);
      // The month arrows, same control the date picker uses. Only forward:
      // the tab lists from today on, so there is nothing behind September.
      expect(find.bySemanticsLabel('Next month'), findsOneWidget);
      expect(find.bySemanticsLabel('Previous month'), findsNothing);
      handle.dispose();
    });

    testWidgets('"New plan" asks the dashboard for the deck', (tester) async {
      final harness = await _pumpTab(tester, rows: _designPlans());

      await tester.tap(find.bySemanticsLabel('New plan'));
      await tester.pumpAndSettle();

      expect(harness.tabs.index, 0);
      expect(harness.tabs.revision, 1);
    });
  });

  group('CalendarTab sections', () {
    testWidgets('groups the plans by day and counts each one', (tester) async {
      await _pumpTab(tester, rows: _designPlans());

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('2 plans'), findsOneWidget);
      expect(find.text('Fri 4'), findsOneWidget);
      expect(find.text('1 plan'), findsOneWidget);
    });

    testWidgets('a row carries the name, the detail line and the time',
        (tester) async {
      await _pumpTab(tester, rows: _designPlans());

      expect(find.text('Warung Kak Ros'), findsOneWidget);
      // Who is coming, neighbourhood and, when a fix has landed, the
      // distance. Nobody was invited to this one, so it is "Just you".
      expect(find.text('Just you · Kepong · 8.7 km'), findsOneWidget);
      expect(find.text('12:30'), findsOneWidget);

      // No coordinates on this one, so the distance is left off rather than
      // guessed at.
      expect(find.text('Just you · Pudu'), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
    });

    testWidgets('a plan with no cover wears its initials', (tester) async {
      await _pumpTab(tester, rows: _designPlans());

      expect(find.text('WK'), findsOneWidget);
      // Twice: once on the row, once inside the ember ring on the 4th. Today's
      // cell keeps its cream disc and its number, so WK is on the row alone.
      expect(find.text('CH'), findsNWidgets(2));
    });

    testWidgets(
        'with no fix the rows drop the distance rather than inventing '
        'one', (tester) async {
      await _pumpTab(
        tester,
        rows: _designPlans(),
        position: Position(
          longitude: 102.933333,
          latitude: 1.850000,
          timestamp: DateTime.fromMillisecondsSinceEpoch(0),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
          isMocked: true,
        ),
      );

      expect(find.text('Just you · Kepong'), findsOneWidget);
    });

    testWidgets('a row reads as one sentence and answers both gestures',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpTab(tester, rows: _designPlans());

      final node = tester.getSemantics(find.text('Warung Kak Ros'));
      expect(node.label, 'Warung Kak Ros, Just you · Kepong · 8.7 km, 12:30');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.longPress),
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('tapping a row opens the plan, not the place', (tester) async {
      // The place is one tap further in, from the plan's own header: a plan
      // now has a time to vote on and a roster to answer, and the card is the
      // only way to either of them.
      final harness = await _pumpTab(tester, rows: _designPlans());

      await tester.tap(find.text('Warung Kak Ros'));
      await tester.pumpAndSettle();

      expect(harness.pushed, ['/plans/1']);
    });
  });

  group('CalendarTab cancelling', () {
    testWidgets('a long press asks first, and "Keep it" keeps it',
        (tester) async {
      final harness = await _pumpTab(tester, rows: _designPlans());

      await tester.longPress(find.text('Warung Kak Ros'));
      await tester.pumpAndSettle();

      // A sheet, not a dialog.
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Cancel Warung Kak Ros?'), findsOneWidget);

      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(harness.repository.cancelled, isEmpty);
      expect(find.text('Warung Kak Ros'), findsOneWidget);
    });

    testWidgets('"Cancel plan" takes it off the calendar', (tester) async {
      final harness = await _pumpTab(tester, rows: _designPlans());

      await tester.longPress(find.text('Warung Kak Ros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel plan'));
      await tester.pumpAndSettle();

      expect(harness.repository.cancelled, [1]);
      expect(find.text('Warung Kak Ros'), findsNothing);
      // The other plan that day is still there, and the count has followed.
      expect(find.text('1 plan'), findsNWidgets(2));
    });

    testWidgets('a refused cancel puts the row back and says so',
        (tester) async {
      final repository = FakePlansRepository(rows: _designPlans())
        ..failCancel = StateError('offline');
      final harness = await _pumpTab(tester, repository: repository);

      await tester.longPress(find.text('Warung Kak Ros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel plan'));
      await tester.pumpAndSettle();

      expect(find.text('Could not cancel that plan.'), findsOneWidget);
      expect(find.text('Warung Kak Ros'), findsOneWidget);
      expect(harness.repository.rows, hasLength(3));
    });
  });

  group('CalendarTab month arrows', () {
    testWidgets('steps forward and back through the months', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpTab(tester, rows: _designPlans());

      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();

      expect(find.text('October 2026'), findsOneWidget);
      // Nothing is planned in October, so the sections give way.
      expect(find.text('Nothing this month'), findsOneWidget);
      expect(find.text('Warung Kak Ros'), findsNothing);

      // Back is only offered once there is somewhere to go back to.
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsOneWidget);
      expect(find.bySemanticsLabel('Previous month'), findsNothing);
      expect(find.text('Warung Kak Ros'), findsOneWidget);
      handle.dispose();
    });
  });

  group('CalendarTab search', () {
    testWidgets('filters the sections by name and clears on close',
        (tester) async {
      await _pumpTab(tester, rows: _designPlans());

      await tester.tap(find.bySemanticsLabel('Search plans'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'chapati');
      await tester.pumpAndSettle();

      expect(find.text('Chapati'), findsOneWidget);
      expect(find.text('Warung Kak Ros'), findsNothing);

      await tester.enterText(find.byType(TextField), 'nothing here');
      await tester.pumpAndSettle();
      expect(find.text('Nothing matches that'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close search'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Warung Kak Ros'), findsOneWidget);
    });
  });

  group('CalendarTab empty state', () {
    testWidgets('says what to do about it, and offers the deck',
        (tester) async {
      final harness = await _pumpTab(tester);

      expect(find.text('No plans yet'), findsOneWidget);
      expect(find.text('Bite something, then pick a day.'), findsOneWidget);
      // The month grid stays: an empty calendar is still a calendar.
      expect(find.text('September 2026'), findsOneWidget);

      await tester.tap(find.text('Start swiping'));
      await tester.pumpAndSettle();

      expect(harness.tabs.index, 0);
    });

    testWidgets('a failed load offers a retry', (tester) async {
      final repository = FakePlansRepository()
        ..failList = StateError('offline');
      await _pumpTab(tester, repository: repository);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Could not load your plans.'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('No plans yet'), findsOneWidget);
    });
  });

  group('CalendarTab month grid', () {
    testWidgets('a planned day is announced with its count', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpTab(tester, rows: _designPlans());

      // A planned day wears its restaurant's cover in place of its number, so
      // these are found by what they announce rather than by what they draw.
      expect(
        find.bySemanticsLabel('Wed 2 Sep, today, 2 plans'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Fri 4 Sep, 1 plan'), findsOneWidget);
      expect(find.bySemanticsLabel('Mon 7 Sep'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the grid is a read-out here, not a picker', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpTab(tester, rows: _designPlans());

      expect(
        tester.getSemantics(find.text('7')).getSemanticsData().hasAction(
              SemanticsAction.tap,
            ),
        isFalse,
      );
      handle.dispose();
    });
  });

  group('CalendarTab people', () {
    testWidgets('a plan with guests says who is coming instead of the meal',
        (tester) async {
      await _pumpTab(
        tester,
        rows: _partyPlans(),
        friendsRepository: _partyRoster(),
      );

      // The design's third plan card, verbatim, with the neighbourhood this
      // row already knew how to add.
      expect(
        find.text('3 friends · 2 confirmed · Kampung Baru'),
        findsOneWidget,
      );
    });

    testWidgets('a plan nobody was invited to is still "Just you"',
        (tester) async {
      await _pumpTab(tester, rows: _designPlans());

      expect(find.byType(FriendAvatar), findsNothing);
    });

    testWidgets('the faces stop at three however many are coming',
        (tester) async {
      await _pumpTab(
        tester,
        rows: _partyPlans(),
        friendsRepository: _partyRoster(),
      );

      // Four are on the plan, one of whom said no; the stack draws three and
      // lets the line carry the number.
      expect(find.byType(FriendAvatar), findsNWidgets(kAvatarStackMax));
      expect(find.text('AZ'), findsOneWidget);
    });

    testWidgets('somebody who said no is neither counted nor drawn',
        (tester) async {
      await _pumpTab(
        tester,
        rows: [
          testPlan(
            1,
            date: DateTime(2026, 9, 4),
            name: 'Warung Kak Ros',
            neighbourhood: 'Kampung Baru',
            members: const [
              PlanMember(userId: 'aiman', status: 'going'),
              PlanMember(userId: 'nadia', status: 'declined'),
            ],
          ),
        ],
        friendsRepository: FakeFriendsRepository(
          planPeople: [
            testPlanPerson(1, 'aiman', name: 'Aiman Zulkifli', status: 'going'),
            testPlanPerson(1, 'nadia', name: 'Nadia Rahim', status: 'declined'),
          ],
        ),
      );

      expect(
        find.text('1 friend · 1 confirmed · Kampung Baru'),
        findsOneWidget,
      );
      expect(find.byType(FriendAvatar), findsOneWidget);
      expect(find.text('NA'), findsNothing);
    });

    testWidgets('somebody who said no leaves no pip on the day either',
        (tester) async {
      await _pumpTab(
        tester,
        rows: [
          testPlan(
            1,
            // Today, so the grid's only marked cell is this one: today's lone
            // dot is drawn only on a day with no pips.
            date: DateTime(2026, 9, 2),
            hour: 20,
            name: 'Warung Kak Ros',
            members: const [
              PlanMember(userId: 'aiman', status: 'going'),
              PlanMember(userId: 'nadia', status: 'declined'),
            ],
          ),
        ],
      );

      // One ember pip for the plan and one cream pip for Aiman. Nadia said no,
      // so she is absent from the grid exactly as she is from the faces.
      final pips = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle &&
            widget.constraints?.maxWidth == kCalendarDotSize,
      );
      expect(pips, findsNWidgets(2));
    });

    testWidgets('the count is right before the faces arrive', (tester) async {
      // The line is read off `plan.members`, which the plan itself carries, so
      // a roster that never lands costs the faces and nothing else.
      final friendsRepository = FakeFriendsRepository()
        ..failPlanPeopleWith = StateError('offline');
      await _pumpTab(
        tester,
        rows: _partyPlans(),
        friendsRepository: friendsRepository,
      );

      expect(
        find.text('3 friends · 2 confirmed · Kampung Baru'),
        findsOneWidget,
      );
      expect(find.byType(FriendAvatar), findsNothing);
      expect(friendsRepository.calls, contains('planPeople'));
    });

    testWidgets('the rosters are asked for once, not once per card',
        (tester) async {
      // `loadPlanPeople` notifies, and a notification rebuilds this tab. A
      // load fired from `build` would loop; this is the assertion that
      // catches it.
      final harness = await _pumpTab(
        tester,
        rows: _designPlans(),
        friendsRepository: _partyRoster(),
      );

      expect(harness.friendsRepository.planPeopleAsked, [
        [1, 2, 3],
      ]);
    });

    testWidgets('the same plans reloaded do not ask again', (tester) async {
      final harness = await _pumpTab(
        tester,
        rows: _designPlans(),
        friendsRepository: _partyRoster(),
      );

      await harness.controller.refresh();
      await tester.pumpAndSettle();

      expect(harness.friendsRepository.planPeopleAsked, hasLength(1));
    });

    testWidgets('a plan that was not there before is asked about',
        (tester) async {
      final harness = await _pumpTab(
        tester,
        rows: _designPlans(),
        friendsRepository: _partyRoster(),
      );

      harness.repository.setRows([
        ..._designPlans(),
        testPlan(9, date: DateTime(2026, 9, 20), name: 'Nasi Kandar Pelita'),
      ]);
      await harness.controller.refresh();
      await tester.pumpAndSettle();

      expect(harness.friendsRepository.planPeopleAsked, hasLength(2));
      expect(harness.friendsRepository.planPeopleAsked.last, contains(9));
    });

    testWidgets("the people line is part of the row's one sentence",
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpTab(
        tester,
        rows: _partyPlans(),
        friendsRepository: _partyRoster(),
      );

      final node = tester.getSemantics(find.text('Warung Kak Ros'));
      expect(
        node.label,
        'Warung Kak Ros, 3 friends · 2 confirmed · Kampung Baru, '
        '20:00',
      );
      // The faces themselves say nothing: the sentence has already counted
      // them.
      expect(find.bySemanticsLabel('AZ'), findsNothing);
      handle.dispose();
    });

    testWidgets('three faces and a long line fit the narrowest phone at a '
        'doubled text scale', (tester) async {
      await _pumpTab(
        tester,
        rows: _partyPlans(),
        friendsRepository: _partyRoster(),
        viewport: _narrowViewport,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);

      // The month grid alone fills a 568 pt screen at this scale, so the row
      // is below it rather than missing.
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FriendAvatar), findsNWidgets(kAvatarStackMax));
      expect(
        find.text('3 friends · 2 confirmed · Kampung Baru'),
        findsOneWidget,
      );
    });
  });

  group('CalendarTab layout', () {
    testWidgets(
        'does not overflow on the narrowest phone at a doubled text '
        'scale', (tester) async {
      await _pumpTab(
        tester,
        rows: _designPlans(),
        viewport: _narrowViewport,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Calendar'), findsOneWidget);
    });

    testWidgets('the day discs stay circles inside the month card',
        (tester) async {
      await _pumpTab(
        tester,
        rows: _designPlans(),
        viewport: _narrowViewport,
      );

      // The grid sits in a card, so its columns are narrower than the screen
      // divided by seven. A disc wider than its column is not dropped, it is
      // squashed into an ellipse — the grid drifts off the design without ever
      // reporting an overflow, so the check is the shape, not the exception.
      final discs = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
      );
      expect(discs, findsWidgets);
      for (var i = 0; i < discs.evaluate().length; i++) {
        final size = tester.getSize(discs.at(i));
        expect(size.width, size.height);
      }
      expect(
        tester.getSize(discs.first),
        const Size(kCalendarDaySize, kCalendarDaySize),
      );
    });

    testWidgets('the empty state survives the same', (tester) async {
      await _pumpTab(
        tester,
        viewport: _narrowViewport,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);

      // The month grid alone fills a 568 pt screen at this scale, so the
      // message is below it rather than missing.
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('No plans yet'), findsOneWidget);
    });
  });
}
