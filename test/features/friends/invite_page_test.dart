import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/app_buttons.dart';
import 'package:swipe_eat/features/friends/presentation/invite_page.dart';
import 'package:swipe_eat/features/friends/presentation/person_row.dart';
import 'package:swipe_eat/features/friends/state/friends_controller.dart';
import 'package:swipe_eat/features/plans/models/plan.dart';
import 'package:swipe_eat/features/plans/state/plans_controller.dart';

import '../../support/widget_test_support.dart';
import '../plans/fake_plans_repository.dart';
import 'fake_friends_repository.dart';

const Size _phoneViewport = Size(390, 844);
const Size _narrowViewport = Size(320, 568);

/// The Sunday the prototype's invite screen is drawn on.
final DateTime _now = DateTime(2026, 9, 6, 19, 41);

/// The plan the design's topbar reads back: "Fri 4 Sep · 20:00".
Plan _theDinner() => testPlan(
      77,
      date: DateTime(2026, 9, 4),
      name: 'Warung Kak Ros',
      withFriends: true,
    );

class _Harness {
  _Harness({
    required this.friendsRepository,
    required this.friends,
    required this.plansRepository,
    required this.plans,
    required this.navigator,
  });

  final FakeFriendsRepository friendsRepository;
  final FriendsController friends;
  final FakePlansRepository plansRepository;
  final PlansController plans;
  final GlobalKey<NavigatorState> navigator;

  /// The screen pops itself on both Skip and Send. With the calendar stub
  /// underneath it, "did it leave" is just "is the stub showing".
  bool get stillOpen => find.byType(InvitePage).evaluate().isNotEmpty;
}

Future<_Harness> _pumpInvite(
  WidgetTester tester, {
  FakeFriendsRepository? friendsRepository,
  List<Plan>? planRows,
  int planId = 77,
  Size viewport = _phoneViewport,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  useViewport(tester, viewport);

  final friendsBacking = friendsRepository ??
      FakeFriendsRepository(
        friends: [
          testFriend('u1', name: 'Aiman Zulkifli'),
          testFriend('u2', name: 'Mei Kee Tan'),
          testFriend('u3', name: 'Syafiq Rahman'),
        ],
      );
  final friends = FriendsController(
    repository: friendsBacking,
    followAuthChanges: false,
  );
  addTearDown(friends.dispose);

  final plansBacking = FakePlansRepository(rows: planRows ?? [_theDinner()]);
  final plans = PlansController(
    repository: plansBacking,
    clock: () => _now,
    followAuthChanges: false,
  );
  addTearDown(plans.dispose);
  await plans.ensureLoaded();

  final navigator = GlobalKey<NavigatorState>();

  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      // Stands in for the calendar the router lands on before pushing this
      // screen, so Skip and Send have somewhere real to pop back to.
      home: const Scaffold(body: Center(child: Text('Calendar'))),
    ),
  );
  await tester.pumpAndSettle();

  unawaited(navigator.currentState!.push(
    MaterialPageRoute<void>(
      builder: (context) => InvitePage(
        planId: planId,
        friends: friends,
        plans: plans,
      ),
    ),
  ));
  await tester.pumpAndSettle();

  return _Harness(
    friendsRepository: friendsBacking,
    friends: friends,
    plansRepository: plansBacking,
    plans: plans,
    navigator: navigator,
  );
}

void main() {
  setUpAll(() => HttpOverrides.global = ImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  group('the screen the design draws', () {
    testWidgets('asks who is hungry, over the plan it is for', (tester) async {
      await _pumpInvite(tester);

      expect(find.text("Who's hungry?"), findsOneWidget);
      expect(find.text('Fri 4 Sep · 20:00'), findsOneWidget);
      expect(find.text('Search friends'), findsOneWidget);
      expect(find.text('Send invites'), findsOneWidget);
    });

    testWidgets('a plan it cannot find still opens', (tester) async {
      // Reachable from a hand-typed link or a restored route. The guest list
      // is the point of the screen and it does not need the date to draw.
      await _pumpInvite(tester, planId: 999);

      expect(find.text('Your plan'), findsOneWidget);
      expect(find.byType(PersonRow), findsNWidgets(3));
    });

    testWidgets('lists every friend under one honest heading', (tester) async {
      // Nobody has eaten with anybody on this account, so "Ate with recently"
      // would be a claim about people the screen has no evidence for.
      await _pumpInvite(tester);

      expect(find.text('Ate with recently'), findsNothing);
      expect(find.text('Your friends'), findsOneWidget);
      expect(find.byType(PersonRow), findsNWidgets(3));
    });

    testWidgets('puts the people you ate with at the top, under the design\'s '
        'own heading', (tester) async {
      await _pumpInvite(
        tester,
        planRows: [
          _theDinner(),
          testPlan(
            12,
            // Earlier this month: the calendar loads from the first of the
            // current month, so that is as far back as "Ate with recently"
            // can see.
            date: DateTime(2026, 9, 2),
            name: 'Chili Pan Mee 88',
            members: const [PlanMember(userId: 'u3', status: 'going')],
          ),
        ],
      );

      expect(find.text('Ate with recently'), findsOneWidget);
      expect(find.text('Your friends'), findsOneWidget);

      final rows = tester
          .widgetList<PersonRow>(find.byType(PersonRow))
          .map((row) => row.profile.name)
          .toList();
      expect(rows.first, 'Syafiq Rahman');
    });

    testWidgets('nobody to invite says where friends come from',
        (tester) async {
      await _pumpInvite(tester, friendsRepository: FakeFriendsRepository());

      expect(find.byType(PersonRow), findsNothing);
      expect(find.textContaining('Add friends from the You tab'), findsOneWidget);
    });
  });

  group('picking people', () {
    testWidgets('the count follows the ticks', (tester) async {
      await _pumpInvite(tester);

      expect(find.text('0'), findsOneWidget);

      await tester.tap(find.text('Aiman Zulkifli'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mei Kee Tan'));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('a second tap takes somebody off again', (tester) async {
      await _pumpInvite(tester);

      await tester.tap(find.text('Aiman Zulkifli'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aiman Zulkifli'));
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('the count is a sentence to a screen reader, not a digit',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpInvite(tester);

      await tester.tap(find.text('Aiman Zulkifli'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('1 person selected'), findsOneWidget);

      await tester.tap(find.text('Mei Kee Tan'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('2 people selected'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('each row says who it is and whether it is picked',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpInvite(tester);

      await tester.tap(find.text('Aiman Zulkifli'));
      await tester.pumpAndSettle();

      final node = tester.getSemantics(
        find.ancestor(
          of: find.text('Aiman Zulkifli'),
          matching: find.byType(PersonRow),
        ),
      );
      expect(
        node,
        matchesSemantics(
          label: 'Aiman Zulkifli',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('searching', () {
    testWidgets('narrows to the half of a name you can spell', (tester) async {
      await _pumpInvite(tester);

      await tester.enterText(find.byType(TextField), 'zul');
      await tester.pumpAndSettle();

      expect(find.byType(PersonRow), findsOneWidget);
      expect(find.text('Aiman Zulkifli'), findsOneWidget);
    });

    testWidgets('drops the headings while it is filtering', (tester) async {
      await _pumpInvite(tester);

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();

      expect(find.text('Your friends'), findsNothing);
      expect(find.text('Ate with recently'), findsNothing);
    });

    testWidgets('a name nobody has says so', (tester) async {
      await _pumpInvite(tester);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();

      expect(find.text('Nobody by that name.'), findsOneWidget);
    });

    testWidgets('somebody picked stays picked when the search hides them',
        (tester) async {
      // The set is the answer, not the list on screen: filtering is a way of
      // finding people, not a way of un-inviting them.
      await _pumpInvite(tester);

      await tester.tap(find.text('Mei Kee Tan'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zul');
      await tester.pumpAndSettle();

      expect(find.text('Mei Kee Tan'), findsNothing);
      expect(find.text('1'), findsOneWidget);
    });
  });

  group('sending', () {
    testWidgets('Send is not offered until somebody is picked', (tester) async {
      await _pumpInvite(tester);

      expect(
        tester
            .widget<AppPrimaryButton>(
                find.widgetWithText(AppPrimaryButton, 'Send invites'))
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('Aiman Zulkifli'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<AppPrimaryButton>(
                find.widgetWithText(AppPrimaryButton, 'Send invites'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('sends exactly the people who were ticked, to this plan',
        (tester) async {
      final harness = await _pumpInvite(tester);

      await tester.tap(find.text('Aiman Zulkifli'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Syafiq Rahman'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send invites'));
      await tester.pumpAndSettle();

      expect(harness.friendsRepository.invites, hasLength(1));
      final (planId, ids) = harness.friendsRepository.invites.single;
      expect(planId, 77);
      expect(ids, containsAll(['u1', 'u3']));
      expect(ids, hasLength(2));
    });

    testWidgets('re-reads the plans so the calendar behind it is right',
        (tester) async {
      // The calendar counts a plan's guests off the plans list, so a screen
      // that invited three people and did not re-read would pop back onto a
      // card that still says "Just you".
      final harness = await _pumpInvite(tester);
      final before = harness.plansRepository.listedFrom.length;

      await tester.tap(find.text('Aiman Zulkifli'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send invites'));
      await tester.pumpAndSettle();

      expect(harness.plansRepository.listedFrom.length, greaterThan(before));
    });

    testWidgets('Skip sends nothing at all', (tester) async {
      final harness = await _pumpInvite(tester);

      await tester.tap(find.text('Aiman Zulkifli'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(harness.friendsRepository.invites, isEmpty);
    });

    testWidgets('a failed send says so and leaves the ticks alone',
        (tester) async {
      // The plan is already saved. Losing the guest list to a dropped
      // connection is annoying; losing it silently is worse.
      final repository = FakeFriendsRepository(
        friends: [testFriend('u1', name: 'Aiman Zulkifli')],
      )..failInviteWith = Exception('offline');
      final harness = await _pumpInvite(tester, friendsRepository: repository);

      await tester.tap(find.text('Aiman Zulkifli'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send invites'));
      await tester.pumpAndSettle();

      expect(find.text('Could not send those invites.'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(harness.stillOpen, isTrue);
    });
  });

  group('narrow and large', () {
    testWidgets('the screen survives 320 pt at double text', (tester) async {
      await _pumpInvite(
        tester,
        viewport: _narrowViewport,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      expect(find.text("Who's hungry?"), findsOneWidget);
      expect(find.text('Send invites'), findsOneWidget);
    });

    testWidgets('and so does its empty state', (tester) async {
      await _pumpInvite(
        tester,
        friendsRepository: FakeFriendsRepository(),
        viewport: _narrowViewport,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
