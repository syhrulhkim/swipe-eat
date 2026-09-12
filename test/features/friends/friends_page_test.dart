import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/friends/data/friends_repository.dart';
import 'package:swipe_eat/features/friends/presentation/friends_page.dart';
import 'package:swipe_eat/features/friends/presentation/person_row.dart';
import 'package:swipe_eat/features/friends/state/friends_controller.dart';
import 'package:swipe_eat/features/onboarding/presentation/onboarding_steps.dart';
import 'package:swipe_eat/features/dashboard/state/dashboard_tab_request.dart';
import 'package:swipe_eat/features/plans/models/plan.dart';
import 'package:swipe_eat/features/plans/state/plans_controller.dart';

import '../../support/widget_test_support.dart';
import '../plans/fake_plans_repository.dart';
import 'fake_friends_repository.dart';

const Size _phoneViewport = Size(390, 844);
const Size _narrowViewport = Size(320, 568);

/// The day the clock is pinned to, so "Fri 18" is a fact rather than a guess.
final DateTime _today = DateTime(2026, 9, 15, 12);

class _Harness {
  _Harness(this.repository, this.controller, this.tabs, this.shared);

  final FakeFriendsRepository repository;
  final FriendsController controller;
  final DashboardTabRequest tabs;

  /// Every text the invite button handed to the share sheet.
  final List<String> shared;
}

/// The address book the design's "Friends · 38" implies: one person waiting on
/// an answer, one waiting to hear back, and two friends.
FakeFriendsRepository _fullBook() {
  return FakeFriendsRepository(
    friends: [
      testFriend('u1', name: 'Aiman Zulkifli'),
      testFriend('u2', name: 'Mei Kee Tan'),
    ],
    requests: [
      testRequest('u9', name: 'Syafiq Rahman'),
      testRequest('u8', name: 'Nadia Idris', incoming: false),
    ],
  );
}

Future<_Harness> _pumpPage(
  WidgetTester tester, {
  FakeFriendsRepository? repository,
  Size viewport = _phoneViewport,
  TextScaler textScaler = TextScaler.noScaling,
  Future<List<String>> Function()? readContacts,
  List<Plan> plans = const [],
}) async {
  useViewport(tester, viewport);
  final backing = repository ?? _fullBook();
  final controller = FriendsController(
    repository: backing,
    followAuthChanges: false,
  );
  addTearDown(controller.dispose);

  final planning = PlansController(
    repository: FakePlansRepository(rows: plans),
    clock: () => _today,
    followAuthChanges: false,
  );
  addTearDown(planning.dispose);

  final tabs = DashboardTabRequest();
  addTearDown(tabs.dispose);
  final shared = <String>[];

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: FriendsPage(
        friends: controller,
        plans: planning,
        readContacts: readContacts,
        tabRequests: tabs,
        onShare: (text) async => shared.add(text),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _Harness(backing, controller, tabs, shared);
}

void main() {
  setUpAll(() => HttpOverrides.global = ImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  group('FriendsPage finds friends from contacts', () {
    testWidgets('the row is there whether or not anybody is', (tester) async {
      await _pumpPage(tester, repository: FakeFriendsRepository());

      // The design puts adding somebody in the bar, not in a row of its own.
      expect(find.bySemanticsLabel('Add friend'), findsOneWidget);
      expect(
        find.textContaining('Add somebody with the button above'),
        findsOneWidget,
      );
    });

    testWidgets('reads, matches, ticks everybody, and sends', (tester) async {
      final book = FakeFriendsRepository(
        matches: [
          testFriend('m1', name: 'Hafiz Omar'),
          testFriend('m2', name: 'Siti Nurul'),
        ],
      );
      final harness = await _pumpPage(
        tester,
        repository: book,
        readContacts: () async => ['+60123456789', '0111234567'],
      );

      await tester.tap(find.bySemanticsLabel('Add friend'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find friends from contacts'));
      await tester.pumpAndSettle();

      expect(find.text('Hafiz Omar'), findsOneWidget);
      // The privacy promise reads exactly as it does in onboarding.
      expect(find.text(OnboardingFriendsStep.privacyLine), findsOneWidget);

      // Both matched, both ticked, and the raw numbers never left.
      expect(harness.repository.sentHashes.single.length, 2);
      expect(find.text('Send 2 requests'), findsOneWidget);

      await tester.tap(find.text('Send 2 requests'));
      await tester.pumpAndSettle();

      expect(
        harness.repository.actions.map((a) => a.$1).toList(),
        ['m1', 'm2'],
      );
      expect(find.text('2 requests sent.'), findsOneWidget);
    });

    testWidgets('a contact taken off the list is not asked', (tester) async {
      final book = FakeFriendsRepository(
        matches: [
          testFriend('m1', name: 'Hafiz Omar'),
          testFriend('m2', name: 'Siti Nurul'),
        ],
      );
      final harness = await _pumpPage(
        tester,
        repository: book,
        readContacts: () async => ['+60123456789'],
      );

      await tester.tap(find.bySemanticsLabel('Add friend'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find friends from contacts'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Siti Nurul'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send 1 request'));
      await tester.pumpAndSettle();

      expect(harness.repository.actions.map((a) => a.$1).toList(), ['m1']);
    });
  });

  group('FriendsPage lists', () {
    testWidgets('titles itself and offers a way back', (tester) async {
      await _pumpPage(tester);

      expect(find.text('Friends · 2'), findsOneWidget);
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
    });

    testWidgets('heads the design\'s sections and folds sent requests into '
        'Everyone', (tester) async {
      await _pumpPage(tester);

      expect(find.text('Requests · 1'), findsOneWidget);
      expect(find.text('Syafiq Rahman'), findsOneWidget);

      // The design has no outgoing section, so a request you sent sits at the
      // foot of Everyone still saying "Asked" and still cancellable.
      expect(find.text('Everyone'), findsOneWidget);
      expect(find.text('Nadia Idris'), findsOneWidget);
      expect(find.text('Asked'), findsOneWidget);

      // The count the You tab's button shows, repeated in the title.
      expect(find.text('Friends · 2'), findsOneWidget);
      expect(find.text('Aiman Zulkifli'), findsOneWidget);
      expect(find.byType(PersonRow), findsNWidgets(4));
    });

    testWidgets('a section with nobody in it is not drawn at all',
        (tester) async {
      await _pumpPage(
        tester,
        repository: FakeFriendsRepository(
          friends: [testFriend('u1', name: 'Aiman Zulkifli')],
        ),
      );

      expect(find.textContaining('Requests · '), findsNothing);
      expect(find.text('Asked'), findsNothing);
      expect(find.text('Everyone'), findsOneWidget);
      expect(find.text('Friends · 1'), findsOneWidget);
    });

    testWidgets('an empty address book says how one fills up', (tester) async {
      await _pumpPage(tester, repository: FakeFriendsRepository());

      expect(find.byType(PersonRow), findsNothing);
      expect(
        find.textContaining('Nobody yet.'),
        findsOneWidget,
      );
    });

    testWidgets('a failed load is retryable', (tester) async {
      final repository = FakeFriendsRepository()
        ..failWith = StateError('offline');
      final harness = await _pumpPage(tester, repository: repository);

      expect(find.text('Could not load your friends.'), findsOneWidget);

      repository.failWith = null;
      repository.setFriends([testFriend('u1', name: 'Aiman Zulkifli')]);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Aiman Zulkifli'), findsOneWidget);
      expect(harness.controller.count, 1);
    });
  });

  group('FriendsPage answering', () {
    testWidgets('Accept moves the person into the friends list',
        (tester) async {
      final harness = await _pumpPage(tester);

      await tester.tap(find.bySemanticsLabel('Accept Syafiq Rahman'));
      await tester.pumpAndSettle();

      expect(harness.repository.actions, [('u9', FriendAction.accept)]);
      expect(find.textContaining('Requests · '), findsNothing);
      expect(find.text('Friends · 3'), findsOneWidget);
    });

    testWidgets('Decline takes the request off the page', (tester) async {
      final harness = await _pumpPage(tester);

      await tester.tap(find.bySemanticsLabel('Decline Syafiq Rahman'));
      await tester.pumpAndSettle();

      expect(harness.repository.actions, [('u9', FriendAction.decline)]);
      expect(find.text('Syafiq Rahman'), findsNothing);
      // Declining is not befriending.
      expect(find.text('Friends · 2'), findsOneWidget);
    });

    testWidgets('cancelling a sent request deletes the same row a decline '
        'would', (tester) async {
      final harness = await _pumpPage(tester);

      await tester.tap(
        find.bySemanticsLabel('Cancel the request to Nadia Idris'),
      );
      await tester.pumpAndSettle();

      expect(harness.repository.actions, [('u8', FriendAction.decline)]);
      expect(find.text('Nadia Idris'), findsNothing);
    });

    testWidgets('a failed answer says so and leaves the row where it was',
        (tester) async {
      final repository = _fullBook()..failActWith = StateError('offline');
      await _pumpPage(tester, repository: repository);

      await tester.tap(find.bySemanticsLabel('Accept Syafiq Rahman'));
      await tester.pumpAndSettle();

      expect(find.text('That did not go through.'), findsOneWidget);
      expect(find.text('Syafiq Rahman'), findsOneWidget);
      expect(find.text('Friends · 2'), findsOneWidget);
    });
  });

  group('FriendsPage removing', () {
    testWidgets('Remove asks first, and "Keep them" keeps them',
        (tester) async {
      final harness = await _pumpPage(tester);

      await tester.tap(find.bySemanticsLabel('Remove Aiman Zulkifli'));
      await tester.pumpAndSettle();

      // A sheet, not a dialog — the same shape cancelling a plan uses.
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Remove Aiman Zulkifli?'), findsOneWidget);

      await tester.tap(find.text('Keep them'));
      await tester.pumpAndSettle();

      expect(harness.repository.actions, isEmpty);
      expect(find.text('Aiman Zulkifli'), findsOneWidget);
    });

    testWidgets('confirming takes them off the list', (tester) async {
      final harness = await _pumpPage(tester);

      await tester.tap(find.bySemanticsLabel('Remove Aiman Zulkifli'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();

      expect(harness.repository.actions, [('u1', FriendAction.remove)]);
      expect(find.text('Aiman Zulkifli'), findsNothing);
      expect(find.text('Friends · 1'), findsOneWidget);
    });
  });

  group('FriendsPage semantics', () {
    testWidgets('every button names the person it acts on', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester);

      // Two people can offer the same word, so the word alone is not a label.
      for (final label in [
        'Accept Syafiq Rahman',
        'Decline Syafiq Rahman',
        'Cancel the request to Nadia Idris',
        'Remove Aiman Zulkifli',
        'Remove Mei Kee Tan',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      handle.dispose();
    });

    testWidgets('a row with buttons on it is not itself a button',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester);

      // `PersonRow` drops its own wrapper when something is in `trailing`; a
      // wrapper there would fuse the name and both buttons into one node with
      // nothing to press.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Accept Syafiq Rahman')),
        matchesSemantics(
          label: 'Accept Syafiq Rahman',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('FriendsPage search, chips and this week', () {
    testWidgets('the search field filters the rows by name', (tester) async {
      await _pumpPage(tester);

      await tester.enterText(find.byType(TextField), 'mei');
      await tester.pumpAndSettle();

      expect(find.text('Mei Kee Tan'), findsOneWidget);
      expect(find.text('Aiman Zulkifli'), findsNothing);
      // Requests are rows too, and the filter is case-insensitive.
      expect(find.text('Syafiq Rahman'), findsNothing);
    });

    testWidgets('a shared plan in the next week gets its own section and the '
        'design\'s subtitle', (tester) async {
      await _pumpPage(
        tester,
        plans: [
          testPlan(
            1,
            date: DateTime(2026, 9, 18),
            members: const [PlanMember(userId: 'u1', status: 'going')],
          ),
        ],
      );

      // The chip says it and so does the heading under it.
      expect(find.text('Eating this week'), findsNWidgets(2));
      expect(
        find.text('Fri 18 · Warung Kak Ros with you'),
        findsOneWidget,
      );
      // The same person is still in Everyone underneath.
      expect(find.text('Aiman Zulkifli'), findsNWidgets(2));
    });

    testWidgets('a plan further out than a week is not this week',
        (tester) async {
      await _pumpPage(
        tester,
        plans: [
          testPlan(
            1,
            date: DateTime(2026, 9, 30),
            members: const [PlanMember(userId: 'u1', status: 'going')],
          ),
        ],
      );

      // The chip is always there; the heading and its rows are not.
      expect(find.text('Eating this week'), findsOneWidget);
      expect(find.textContaining('with you'), findsNothing);
      expect(find.text('Aiman Zulkifli'), findsOneWidget);
    });

    testWidgets('the chips are single-select and narrow the page',
        (tester) async {
      await _pumpPage(
        tester,
        plans: [
          testPlan(
            1,
            date: DateTime(2026, 9, 18),
            members: const [PlanMember(userId: 'u1', status: 'going')],
          ),
        ],
      );

      await tester.tap(find.text('Eating this week').first);
      await tester.pumpAndSettle();

      // Only the one section is left: no requests, no Everyone.
      expect(find.text('Fri 18 · Warung Kak Ros with you'), findsOneWidget);
      expect(find.textContaining('Requests · '), findsNothing);
      expect(find.text('Everyone'), findsNothing);
      expect(find.text('Aiman Zulkifli'), findsOneWidget);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('Requests · 1'), findsOneWidget);
      expect(find.text('Everyone'), findsOneWidget);
    });

    testWidgets('a friend\'s calendar button asks for the Swipe tab',
        (tester) async {
      final harness = await _pumpPage(tester);

      expect(harness.tabs.revision, 0);
      await tester.tap(find.bySemanticsLabel('Plan with Aiman Zulkifli'));
      await tester.pumpAndSettle();

      expect(harness.tabs.index, 0);
      expect(harness.tabs.revision, 1);
    });

    testWidgets('a request row has no calendar button', (tester) async {
      await _pumpPage(tester);

      expect(find.bySemanticsLabel('Plan with Syafiq Rahman'), findsNothing);
      expect(find.bySemanticsLabel('Plan with Nadia Idris'), findsNothing);
    });

    testWidgets('the foot shares an invite', (tester) async {
      final harness = await _pumpPage(tester);

      await tester.tap(find.text('Invite friends with a link'));
      await tester.pumpAndSettle();

      // No link exists yet, so the text carries no URL that would 404.
      expect(harness.shared.single, 'Come and eat with me on Swipe Eat.');
    });
  });

  group('FriendsPage layout', () {
    testWidgets('four rows of people fit the narrowest phone at a doubled '
        'text scale', (tester) async {
      await _pumpPage(
        tester,
        viewport: _narrowViewport,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Requests · 1'), findsOneWidget);
    });

    testWidgets('the confirm sheet survives the same', (tester) async {
      // Two pills side by side, both labelled, both unable to shrink.
      await _pumpPage(
        tester,
        viewport: _narrowViewport,
        textScaler: const TextScaler.linear(2),
      );

      // Everyone is the last section, and the list only builds what is on
      // screen.
      // Two scrollables now — the chip row and the list — so the list is
      // named rather than guessed at.
      await tester.scrollUntilVisible(
        find.text('Aiman Zulkifli'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Remove Aiman Zulkifli'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Keep them'), findsOneWidget);
    });

    testWidgets('the empty state survives the same', (tester) async {
      await _pumpPage(
        tester,
        repository: FakeFriendsRepository(),
        viewport: _narrowViewport,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Nobody yet.'), findsOneWidget);
    });
  });
}
