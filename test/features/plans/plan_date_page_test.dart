import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/location/user_location.dart';
import 'package:swipe_eat/features/friends/presentation/invite_page.dart';
import 'package:swipe_eat/features/friends/state/friends_controller.dart';
import 'package:swipe_eat/features/plans/presentation/plan_date_page.dart';
import 'package:swipe_eat/features/plans/state/plans_controller.dart';
import 'package:swipe_eat/features/restaurants/domain/opening_hours.dart';

import '../../support/widget_test_support.dart';
import '../friends/fake_friends_repository.dart';
import 'fake_plans_repository.dart';

const Size _phoneViewport = Size(390, 844);
const Size _narrowViewport = Size(320, 568);

/// The Wednesday the prototype's sheet is drawn on. The week strip therefore
/// runs Wed 2 September to Tue 8 September.
final DateTime _now = DateTime(2026, 9, 2, 11);

const PlanDraft _draft = PlanDraft(
  restaurantId: 306,
  title: 'Warung Kak Ros',
  coverUrl: 'https://example.test/cover.jpg',
  neighbourhood: 'Kepong',
  tag: 'Nasi lemak',
);

class _Harness {
  _Harness(this.plansRepository, this.friendsRepository);

  final FakePlansRepository plansRepository;
  final FakeFriendsRepository friendsRepository;
}

Future<_Harness> _pumpPage(
  WidgetTester tester, {
  FakePlansRepository? repository,
  FakeFriendsRepository? friendsRepository,
  PlanDraft draft = _draft,
  Size viewport = _phoneViewport,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  useViewport(tester, viewport);
  resetUserPositionCache();

  final backing = repository ?? FakePlansRepository();
  final plans = PlansController(
    repository: backing,
    clock: () => _now,
    followAuthChanges: false,
  );
  addTearDown(plans.dispose);
  await plans.ensureLoaded();

  final friendsBacking = friendsRepository ?? FakeFriendsRepository();
  final friends = FriendsController(
    repository: friendsBacking,
    followAuthChanges: false,
  );
  addTearDown(friends.dispose);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: PlanDatePage(
        draft: draft,
        controller: plans,
        friends: friends,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _Harness(backing, friendsBacking);
}

/// Taps a cell in the week strip. The three-letter weekday is unique across
/// seven consecutive days, and the summary line below spells its own day
/// inside one longer string, so the short name only ever finds the strip.
Future<void> _tapWeekday(WidgetTester tester, String weekday) async {
  await tester.tap(find.text(weekday));
  await tester.pumpAndSettle();
}

Future<void> _tapChip(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => HttpOverrides.global = ImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  group('PlanDatePage copy', () {
    testWidgets('asks the question, names the place and counts the step',
        (tester) async {
      await _pumpPage(tester);

      expect(find.text('When are we going?'), findsOneWidget);
      expect(find.text('Step 1 of 2'), findsOneWidget);
      // Twice by design: the peek header names the place, and the summary
      // card names it again under the answer. With no location fix the
      // summary drops its "· 1.2 km from you" tail and the two read alike.
      expect(find.text('Warung Kak Ros'), findsNWidgets(2));
      expect(find.text('Kepong'), findsOneWidget);
      expect(find.text('Tonight'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Pick another date ›'), findsOneWidget);
      expect(find.text("Who's coming"), findsOneWidget);
      expect(find.text('Just me'), findsOneWidget);
      expect(find.text('Next · invite friends'), findsOneWidget);
    });

    testWidgets('the switches the flow depends on are both here',
        (tester) async {
      await _pumpPage(tester);

      expect(find.text('Let friends vote on the time'), findsOneWidget);
      // D153's sharing switch survived the redesign.
      expect(find.text('Share with friends'), findsOneWidget);
      expect(
        find.text('They can see it on their calendar and ask to join'),
        findsOneWidget,
      );
    });

    testWidgets('the time heading names the closing hour when we know it',
        (tester) async {
      await _pumpPage(
        tester,
        draft: PlanDraft(
          restaurantId: 306,
          title: 'Warung Kak Ros',
          hours: OpeningHours.fromJson(const {
            'opens_at': '18:00',
            'closes_at': '02:00',
          }),
        ),
      );

      expect(find.text('Time · they close at 2 am'), findsOneWidget);
    });

    testWidgets('and says only "Time" when the hours are unknown',
        (tester) async {
      await _pumpPage(tester);

      expect(find.text('Time'), findsOneWidget);
      expect(find.textContaining('they close at'), findsNothing);
    });
  });

  group('PlanDatePage week strip and quick chips', () {
    testWidgets('opens on the last day of the strip, under "This week"',
        (tester) async {
      await _pumpPage(tester);

      expect(find.text('Tue 8 · 8:00 pm · just you'), findsOneWidget);
    });

    testWidgets('Tonight takes the first day, Tomorrow the second',
        (tester) async {
      await _pumpPage(tester);

      await _tapChip(tester, 'Tonight');
      expect(find.text('Wed 2 · 8:00 pm · just you'), findsOneWidget);

      await _tapChip(tester, 'Tomorrow');
      expect(find.text('Thu 3 · 8:00 pm · just you'), findsOneWidget);

      await _tapChip(tester, 'This week');
      expect(find.text('Tue 8 · 8:00 pm · just you'), findsOneWidget);
    });

    testWidgets('a day off the strip presses "This week" — unless it is today',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester);

      await _tapWeekday(tester, 'Fri');
      expect(find.text('Fri 4 · 8:00 pm · just you'), findsOneWidget);
      expect(tester.getSemantics(find.text('This week')).label, 'This week');

      // The mockup's own exception: today is "Tonight", not "This week".
      await _tapWeekday(tester, 'Wed');
      expect(find.text('Wed 2 · 8:00 pm · just you'), findsOneWidget);
      expect(tester.getSemantics(find.text('Tonight')).label, 'Tonight');
      handle.dispose();
    });

    testWidgets('a day you already have a plan on says so', (tester) async {
      final handle = tester.ensureSemantics();
      // Friday the 4th is spoken for.
      await _pumpPage(
        tester,
        repository:
            FakePlansRepository(rows: [testPlan(77, date: DateTime(2026, 9, 4))]),
      );

      expect(
        tester.getSemantics(find.text('Fri')).label,
        contains('you have a plan'),
      );
      expect(
        tester.getSemantics(find.text('Sat')).label,
        isNot(contains('you have a plan')),
      );
      handle.dispose();
    });

    testWidgets('today is marked as today', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester);

      expect(tester.getSemantics(find.text('Wed')).label, contains('today'));
      handle.dispose();
    });

    testWidgets('the full calendar is one tap away and answers back',
        (tester) async {
      await _pumpPage(tester);

      await tester.tap(find.text('Pick another date ›'));
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);

      // The 20th is outside the seven days on offer.
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      expect(find.text('Sun 20 · 8:00 pm · just you'), findsOneWidget);
    });
  });

  group('PlanDatePage time chips', () {
    testWidgets('the design\'s four are offered, one at a time', (tester) async {
      await _pumpPage(tester);

      for (final label in ['6:30', '8:00', '9:30', 'Late']) {
        expect(find.text(label), findsOneWidget);
      }

      await _tapChip(tester, 'Late');
      expect(find.text('Tue 8 · late · just you'), findsOneWidget);

      await _tapChip(tester, '6:30');
      expect(find.text('Tue 8 · 6:30 pm · just you'), findsOneWidget);
    });

    testWidgets('tapping the pressed chip does not clear it', (tester) async {
      await _pumpPage(tester);

      await _tapChip(tester, '8:00');

      expect(find.text('Tue 8 · 8:00 pm · just you'), findsOneWidget);
    });
  });

  group('PlanDatePage who is coming', () {
    testWidgets('starts with the friends who already ngap\'d the place',
        (tester) async {
      await _pumpPage(
        tester,
        friendsRepository: FakeFriendsRepository(
          friends: [
            testFriend('u1', name: 'Aiman Zulkifli'),
            testFriend('u2', name: 'Mei Kee Tan'),
          ],
          liked: [
            testFriend('u1', name: 'Aiman Zulkifli'),
            testFriend('u2', name: 'Mei Kee Tan'),
          ],
        ),
      );

      // "Mei", not the prototype's "Mei Kee": firstName() takes the first
      // word of a name, which is the convention every other screen uses.
      expect(find.text('Aiman, Mei'), findsOneWidget);
      expect(find.text("Aiman and Mei ngap'd this"), findsOneWidget);
      expect(find.text('Tue 8 · 8:00 pm · 2 friends'), findsOneWidget);
    });

    testWidgets('"Just me" flips the label and empties the tail',
        (tester) async {
      await _pumpPage(
        tester,
        friendsRepository: FakeFriendsRepository(
          friends: [testFriend('u1', name: 'Aiman Zulkifli')],
          liked: [testFriend('u1', name: 'Aiman Zulkifli')],
        ),
      );
      expect(find.text('Tue 8 · 8:00 pm · 1 friend'), findsOneWidget);

      // The row sits below the fold on this viewport, so it has to be
      // scrolled to before it can be tapped.
      await tester.ensureVisible(find.text('Just me'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Just me'));
      await tester.pumpAndSettle();

      expect(find.text('Add friends back'), findsOneWidget);
      expect(find.text('Just me'), findsNothing);
      expect(find.text('Tue 8 · 8:00 pm · just you'), findsOneWidget);

      await tester.ensureVisible(find.text('Add friends back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add friends back'));
      await tester.pumpAndSettle();

      expect(find.text('Tue 8 · 8:00 pm · 1 friend'), findsOneWidget);
    });
  });

  group('PlanDatePage saves nothing', () {
    testWidgets('"Next" opens step two and writes no plan', (tester) async {
      final harness = await _pumpPage(tester);

      await tester.tap(find.text('Next · invite friends'));
      await tester.pumpAndSettle();

      // The whole point of the redesign: step one is a question, not a save.
      expect(harness.plansRepository.created, isEmpty);
      expect(find.byType(InvitePage), findsOneWidget);
      expect(find.text("Who's hungry?"), findsOneWidget);
      expect(find.text('Step 2 of 2'), findsOneWidget);
      // Step two's peek reads back what step one collected.
      expect(find.text('Tue 8 · 8:00 pm'), findsOneWidget);
    });

    testWidgets('the "+" beside the faces opens the same step',
        (tester) async {
      final harness = await _pumpPage(tester);

      await tester.tap(find.bySemanticsLabel('Add friends'));
      await tester.pumpAndSettle();

      expect(harness.plansRepository.created, isEmpty);
      expect(find.byType(InvitePage), findsOneWidget);
    });

    testWidgets('coming back from step two keeps what was ticked there',
        (tester) async {
      await _pumpPage(
        tester,
        friendsRepository: FakeFriendsRepository(
          friends: [
            testFriend('u1', name: 'Aiman Zulkifli'),
            testFriend('u2', name: 'Mei Kee Tan'),
          ],
        ),
      );
      expect(find.text('Tue 8 · 8:00 pm · just you'), findsOneWidget);

      await tester.tap(find.text('Next · invite friends'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aiman Zulkifli'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Tue 8 · 8:00 pm · 1 friend'), findsOneWidget);
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
        'latitude': 3.17,
        'longitude': 101.7,
        'hours': <String, dynamic>{'opens_at': '18:00', 'closes_at': '02:00'},
      });

      expect(draft?.restaurantId, 306);
      expect(draft?.title, 'Warung Kak Ros');
      expect(draft?.shortName, 'Kak Ros');
      expect(draft?.latitude, 3.17);
      expect(draft?.hours.closesAtMinutes, 120);
    });

    test('takes an id that arrived as text, and survives a thin payload', () {
      expect(
        PlanDraft.fromPayload(<String, dynamic>{'restaurantId': '306'})
            ?.restaurantId,
        306,
      );
      final thin = PlanDraft.fromPayload(<String, dynamic>{'restaurantId': 306});
      expect(thin?.title, 'A place');
      // No coordinates and no hours: both are dropped, never guessed.
      expect(thin?.hours.isKnown, isFalse);
      expect(thin?.distanceFrom(null), isNull);
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

      await _tapWeekday(tester, 'Fri');
      expect(tester.takeException(), isNull);
    });

    testWidgets('and is still usable there', (tester) async {
      final harness = await _pumpPage(
        tester,
        viewport: _narrowViewport,
        textScaler: const TextScaler.linear(2),
      );

      await tester.tap(find.text('Next · invite friends'));
      await tester.pumpAndSettle();

      expect(harness.plansRepository.created, isEmpty);
      expect(find.byType(InvitePage), findsOneWidget);
    });
  });
}
