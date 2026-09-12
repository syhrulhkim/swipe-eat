import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/plans/presentation/plan_date_page.dart';
import 'package:swipe_eat/features/profile/presentation/preference_controls.dart';
import 'package:swipe_eat/features/plans/state/plans_controller.dart';

import '../../support/widget_test_support.dart';
import 'fake_plans_repository.dart';

const Size _phoneViewport = Size(390, 844);
const Size _narrowViewport = Size(320, 568);

/// The Wednesday the prototype's calendar is drawn on.
final DateTime _now = DateTime(2026, 9, 2, 11);

const PlanDraft _draft = PlanDraft(
  restaurantId: 306,
  title: 'Warung Kak Ros',
  coverUrl: 'https://example.test/cover.jpg',
  neighbourhood: 'Kepong',
  tag: 'Nasi lemak',
);

class _Created {
  int? planId;
  bool? withFriends;
  int calls = 0;
}

Future<(FakePlansRepository, _Created)> _pumpPage(
  WidgetTester tester, {
  FakePlansRepository? repository,
  PlanDraft draft = _draft,
  Size viewport = _phoneViewport,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  useViewport(tester, viewport);
  final backing = repository ?? FakePlansRepository();
  final controller = PlansController(
    repository: backing,
    clock: () => _now,
    followAuthChanges: false,
  );
  addTearDown(controller.dispose);
  await controller.ensureLoaded();

  final created = _Created();

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: PlanDatePage(
        draft: draft,
        controller: controller,
        onCreated: (context, planId, withFriends) {
          created
            ..planId = planId
            ..withFriends = withFriends
            ..calls += 1;
        },
      ),
    ),
  );
  await tester.pumpAndSettle();

  return (backing, created);
}

/// Taps a day number in the grid. The number is unique inside one month, so
/// finding by text is enough.
Future<void> _tapDay(WidgetTester tester, int day) async {
  // Scrolled to first: on a 568 pt phone at a doubled text scale the last
  // week of the month starts below the fold.
  await tester.ensureVisible(find.text('$day'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('$day'));
  await tester.pumpAndSettle();
}

/// Taps a time chip. The design's `.slots` wraps onto a second line, so the
/// last chips can start below the fold on a short phone.
Future<void> _tapSlot(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

bool _lockInEnabled(WidgetTester tester) {
  final ink = tester.widget<InkWell>(
    find
        .ancestor(of: find.text('Lock it in'), matching: find.byType(InkWell))
        .first,
  );
  return ink.onTap != null;
}

/// Taps "Lock it in" and lets the request settle.
///
/// Not `pumpAndSettle`: a successful save leaves the button spinning until the
/// route changes, and in a test nothing changes it, so settling would time
/// out. Fixed frames are enough for a fake that answers on the next
/// microtask.
Future<void> _lockIn(WidgetTester tester) async {
  await tester.tap(find.text('Lock it in'));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() => HttpOverrides.global = ImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  group('PlanDatePage copy', () {
    testWidgets('asks the question and names the place', (tester) async {
      await _pumpPage(tester);

      expect(find.text('When are we going?'), findsOneWidget);
      expect(find.text('Warung Kak Ros'), findsOneWidget);
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('Bring friends'), findsOneWidget);
      expect(
        find.text("Optional — they'll get a vote on the time"),
        findsOneWidget,
      );
    });

    testWidgets('the summary waits for a day, then reads the answer back',
        (tester) async {
      await _pumpPage(tester);

      expect(find.text('Pick a day'), findsOneWidget);
      expect(find.text('Kak Ros · With friends'), findsOneWidget);

      await _tapDay(tester, 4);

      expect(find.text('Pick a day'), findsNothing);
      expect(find.text('Fri 4 Sep · 20:00'), findsOneWidget);
    });

    testWidgets('the summary follows the time chip', (tester) async {
      await _pumpPage(tester);
      await _tapDay(tester, 4);

      await _tapSlot(tester, 'Late');

      expect(find.text('Fri 4 Sep · Late'), findsOneWidget);
    });

    testWidgets('the summary reads "Just you" when the friend switch is off',
        (tester) async {
      await _pumpPage(tester);
      await _tapDay(tester, 4);

      await tester.ensureVisible(find.byType(PrefSwitch));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrefSwitch));
      await tester.pumpAndSettle();

      expect(find.text('Kak Ros · Just you'), findsOneWidget);
    });
  });

  group('PlanDatePage day grid', () {
    testWidgets('Lock it in waits for a day', (tester) async {
      await _pumpPage(tester);

      expect(_lockInEnabled(tester), isFalse);

      await _tapDay(tester, 4);

      expect(_lockInEnabled(tester), isTrue);
      // The label never becomes a count; the design has none.
      expect(find.text('Lock it in'), findsOneWidget);
    });

    testWidgets('a day that has passed cannot be chosen', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester);

      // The 1st is yesterday: no tap action on the node, and driving the
      // widget itself changes nothing either.
      final node = tester.getSemantics(find.text('1'));
      expect(node.label, 'Tue 1 Sep, past');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);

      await tester.ensureVisible(find.text('1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_lockInEnabled(tester), isFalse);
      expect(find.text('Pick a day'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('today is marked, and can still be chosen', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester);

      expect(tester.getSemantics(find.text('2')).label, contains('today'));

      await _tapDay(tester, 2);

      expect(find.text('Wed 2 Sep · 20:00'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('every day cell reads as its own date', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester);

      expect(tester.getSemantics(find.text('4')).label, 'Fri 4 Sep');
      handle.dispose();
    });

    testWidgets('the whole cell is the target, not just the disc',
        (tester) async {
      await _pumpPage(tester);

      // The rect of the *cell*, not of the number: `find.text('4')` is about
      // eight points wide and sits inside the disc, so tapping just outside it
      // would still land on the disc and prove nothing.
      final cell = tester.getRect(find.bySemanticsLabel('Fri 4 Sep'));
      // A finger landing in the gutter beside the 36 pt disc must still choose
      // the day.
      await tester.tapAt(Offset(cell.left + 1, cell.center.dy));
      await tester.pumpAndSettle();

      expect(find.text('Fri 4 Sep · 20:00'), findsOneWidget);
    });

    testWidgets('there is no way back past the month you are standing in',
        (tester) async {
      await _pumpPage(tester);

      // Absent, not merely dead: there is no plan to be made in a week that
      // has already happened.
      expect(find.bySemanticsLabel('Previous month'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();

      expect(find.text('October 2026'), findsOneWidget);
      expect(find.bySemanticsLabel('Previous month'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets('a day in another month keeps its month in the summary',
        (tester) async {
      await _pumpPage(tester);

      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      await _tapDay(tester, 10);

      expect(find.text('Sat 10 Oct · 20:00'), findsOneWidget);
    });
  });

  group('PlanDatePage time chips', () {
    testWidgets('all five are offered, one at a time', (tester) async {
      await _pumpPage(tester);

      for (final label in ['12:30', '18:30', '20:00', '21:30', 'Late']) {
        expect(find.text(label), findsOneWidget);
      }

      await _tapDay(tester, 4);
      await _tapSlot(tester, '12:30');
      expect(find.text('Fri 4 Sep · 12:30'), findsOneWidget);

      await _tapSlot(tester, '18:30');
      expect(find.text('Fri 4 Sep · 18:30'), findsOneWidget);
      expect(find.text('Fri 4 Sep · 12:30'), findsNothing);
    });

    testWidgets('tapping the pressed chip does not clear it', (tester) async {
      await _pumpPage(tester);
      await _tapDay(tester, 4);

      await _tapSlot(tester, '20:00');

      expect(find.text('Fri 4 Sep · 20:00'), findsOneWidget);
    });
  });

  group('PlanDatePage locking in', () {
    testWidgets('creates the plan with the day, the time and the switch',
        (tester) async {
      final (repository, created) = await _pumpPage(tester);
      await _tapDay(tester, 4);

      await _lockIn(tester);

      expect(repository.created.single, {
        'restaurantId': 306,
        'date': '2026-09-04',
        'time': '20:00:00',
        'timeLabel': null,
        'withFriends': true,
        'shared': false,
      });
      expect(created.calls, 1);
      expect(created.withFriends, isTrue);
      expect(created.planId, isNotNull);
    });

    testWidgets(
        'Late posts a label rather than a time, and the switch can be '
        'turned off', (tester) async {
      final (repository, created) = await _pumpPage(tester);
      await _tapDay(tester, 12);

      await _tapSlot(tester, 'Late');
      await tester.ensureVisible(find.byType(PrefSwitch));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrefSwitch));
      await tester.pumpAndSettle();

      await _lockIn(tester);

      expect(repository.created.single, {
        'restaurantId': 306,
        'date': '2026-09-12',
        'time': null,
        'timeLabel': 'late',
        'withFriends': false,
        'shared': false,
      });
      expect(created.withFriends, isFalse);
    });

    testWidgets('a refused save says so and leaves the screen usable',
        (tester) async {
      final repository = FakePlansRepository()..failCreate = StateError('down');
      final (_, created) = await _pumpPage(tester, repository: repository);
      await _tapDay(tester, 4);

      await _lockIn(tester);

      expect(created.calls, 0);
      expect(find.text('Could not save that plan.'), findsOneWidget);
      expect(_lockInEnabled(tester), isTrue);
    });
  });

  group('PlanDraft', () {
    test('parses the detail screen\'s payload', () {
      final draft = PlanDraft.fromPayload(<String, dynamic>{
        'restaurantId': 306,
        'title': 'Warung Kak Ros',
        'coverUrl': 'https://example.test/cover.jpg',
        'neighbourhood': 'Kepong',
        'tag': 'Nasi lemak',
      });

      expect(draft?.restaurantId, 306);
      expect(draft?.title, 'Warung Kak Ros');
      expect(draft?.shortName, 'Kak Ros');
    });

    test('takes an id that arrived as text, and survives a thin payload', () {
      expect(
        PlanDraft.fromPayload(<String, dynamic>{'restaurantId': '306'})
            ?.restaurantId,
        306,
      );
      expect(
        PlanDraft.fromPayload(<String, dynamic>{'restaurantId': 306})?.title,
        'A place',
      );
    });

    test('refuses a payload with no restaurant in it', () {
      expect(PlanDraft.fromPayload(null), isNull);
      expect(PlanDraft.fromPayload('nonsense'), isNull);
      expect(PlanDraft.fromPayload(<String, dynamic>{'title': 'x'}), isNull);
    });
  });

  group('PlanDatePage layout', () {
    testWidgets(
        'does not overflow on the narrowest phone at a doubled text '
        'scale', (tester) async {
      await _pumpPage(
        tester,
        viewport: _narrowViewport,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);

      await _tapDay(tester, 4);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and is still usable there', (tester) async {
      final (repository, _) = await _pumpPage(
        tester,
        viewport: _narrowViewport,
        textScaler: const TextScaler.linear(2),
      );

      await _tapDay(tester, 4);
      await _lockIn(tester);

      expect(repository.created, hasLength(1));
    });
  });
}
