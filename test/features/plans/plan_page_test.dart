import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/friends/presentation/person_row.dart';
import 'package:swipe_eat/features/friends/state/friends_controller.dart';
import 'package:swipe_eat/features/plans/models/plan.dart';
import 'package:swipe_eat/features/plans/models/plan_slot.dart';
import 'package:swipe_eat/features/plans/presentation/plan_page.dart';
import 'package:swipe_eat/features/plans/state/plans_controller.dart';
import 'package:swipe_eat/features/restaurants/state/likes_controller.dart'
    show LikesAuthEvents;

import '../../support/widget_test_support.dart';
import '../friends/fake_friends_repository.dart';
import 'fake_plans_repository.dart';

const Size _phoneViewport = Size(390, 844);
const Size _narrowViewport = Size(320, 568);

final DateTime _now = DateTime(2026, 9, 6, 19, 41);

/// Signed in as somebody, without a Supabase singleton to be signed in to.
class _FakeAuthEvents extends LikesAuthEvents {
  _FakeAuthEvents(this.userId);

  final String? userId;

  @override
  Stream<AuthStateStub>? get changes => null;

  @override
  String? get currentUserId => userId;
}

/// [LikesAuthEvents.changes] is typed against Supabase's own `AuthState`; the
/// override above only ever returns null, so the element type never matters.
typedef AuthStateStub = Never;

class _Harness {
  _Harness({
    required this.friendsRepository,
    required this.friends,
    required this.plansRepository,
    required this.plans,
  });

  final FakeFriendsRepository friendsRepository;
  final FriendsController friends;
  final FakePlansRepository plansRepository;
  final PlansController plans;
}

Future<_Harness> _pumpPlan(
  WidgetTester tester, {
  FakeFriendsRepository? friendsRepository,
  List<Plan>? planRows,
  int planId = 77,
  String? me = 'owner',
  Size viewport = _phoneViewport,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  useViewport(tester, viewport);

  final friendsBacking = friendsRepository ?? FakeFriendsRepository();
  final friends = FriendsController(
    repository: friendsBacking,
    followAuthChanges: false,
    authEvents: _FakeAuthEvents(me),
  );
  addTearDown(friends.dispose);

  final plansBacking = FakePlansRepository(
    rows: planRows ?? [testPlan(77, date: DateTime(2026, 9, 4))],
  );
  final plans = PlansController(
    repository: plansBacking,
    clock: () => _now,
    followAuthChanges: false,
  );
  addTearDown(plans.dispose);
  await plans.ensureLoaded();

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: PlanPage(planId: planId, friends: friends, plans: plans),
    ),
  );
  await tester.pumpAndSettle();

  return _Harness(
    friendsRepository: friendsBacking,
    friends: friends,
    plansRepository: plansBacking,
    plans: plans,
  );
}

/// The chip's own text, which carries the count the tally put on it.
Finder _chip(String label) => find.widgetWithText(AppFilterChip, label);

void main() {
  setUpAll(() => HttpOverrides.global = ImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  group('the plan it opens on', () {
    testWidgets('reads back the place, the date and the question',
        (tester) async {
      await _pumpPlan(tester);

      expect(find.text('Warung Kak Ros'), findsOneWidget);
      expect(find.text('Fri 4 Sep · 20:00'), findsOneWidget);
      expect(find.text('When are we going?'), findsOneWidget);
      expect(find.text('Nasi lemak · Kepong'), findsOneWidget);
    });

    testWidgets('draws all five chips, empty, before anybody votes',
        (tester) async {
      await _pumpPlan(tester);

      for (final slot in PlanSlot.all) {
        expect(_chip(slot.label), findsOneWidget);
      }
      expect(find.text('Nobody has picked a time yet.'), findsOneWidget);
    });

    testWidgets('a plan that is not on the calendar says so rather than spins',
        (tester) async {
      await _pumpPlan(tester, planId: 999);

      expect(
        find.text('That plan is not on your calendar.'),
        findsOneWidget,
      );
      expect(find.text('Your plan'), findsOneWidget);
    });

    testWidgets('the place is a way through to its own screen', (tester) async {
      await _pumpPlan(tester);

      final handle = tester.ensureSemantics();
      final node = tester.getSemantics(
        find.bySemanticsLabel('Open Warung Kak Ros'),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });
  });

  group('the tally', () {
    testWidgets('puts each vote on its own chip and names the leader',
        (tester) async {
      await _pumpPlan(
        tester,
        friendsRepository: FakeFriendsRepository(
          votes: [
            testPlanVote(PlanSlot.dinner, 'a'),
            testPlanVote(PlanSlot.dinner, 'b'),
            testPlanVote(PlanSlot.supper, 'c'),
          ],
          planPeople: [
            testPlanPerson(77, 'a'),
            testPlanPerson(77, 'b'),
            testPlanPerson(77, 'c'),
          ],
        ),
      );

      expect(_chip('20:00 · 2'), findsOneWidget);
      expect(_chip('Late · 1'), findsOneWidget);
      expect(_chip('12:30'), findsOneWidget);
      expect(find.text('20:00 has the most votes.'), findsOneWidget);
      // Three guests and the owner were asked; three of them answered.
      expect(find.text('1 person still to vote'), findsOneWidget);
    });

    testWidgets('a chip reads out its count instead of its shorthand',
        (tester) async {
      await _pumpPlan(
        tester,
        friendsRepository: FakeFriendsRepository(
          votes: [testPlanVote(PlanSlot.dinner, 'a')],
        ),
      );

      expect(find.bySemanticsLabel('20:00, 1 vote'), findsOneWidget);
      expect(find.bySemanticsLabel('Late, no votes yet'), findsOneWidget);
    });

    testWidgets('tapping a chip votes for it and re-reads the tally',
        (tester) async {
      final harness = await _pumpPlan(tester);

      await tester.tap(_chip('18:30'));
      await tester.pumpAndSettle();

      expect(harness.friendsRepository.castVotes, [(77, '18:30:00', null)]);
      // The write is followed by a read rather than a local patch, so a vote
      // somebody else cast in the meantime arrives with mine.
      expect(harness.friendsRepository.calls.last, 'votes');
    });

    testWidgets('"Late" votes with the label, not with a midnight',
        (tester) async {
      final harness = await _pumpPlan(tester);

      await tester.tap(_chip('Late'));
      await tester.pumpAndSettle();

      expect(harness.friendsRepository.castVotes, [(77, null, 'late')]);
    });

    testWidgets('my own vote is the chip held down', (tester) async {
      await _pumpPlan(
        tester,
        me: 'me',
        friendsRepository: FakeFriendsRepository(
          votes: [
            testPlanVote(PlanSlot.supper, 'me'),
            testPlanVote(PlanSlot.dinner, 'other'),
          ],
        ),
      );

      final mine = tester.widget<AppFilterChip>(_chip('Late · 1'));
      final theirs = tester.widget<AppFilterChip>(_chip('20:00 · 1'));
      expect(mine.selected, isTrue);
      expect(theirs.selected, isFalse);
    });
  });

  group('settling it', () {
    testWidgets('the owner is offered the winning time when it is not the set one',
        (tester) async {
      final harness = await _pumpPlan(
        tester,
        friendsRepository: FakeFriendsRepository(
          votes: [
            testPlanVote(PlanSlot.early, 'a'),
            testPlanVote(PlanSlot.early, 'b'),
            testPlanVote(PlanSlot.dinner, 'c'),
          ],
        ),
      );

      await tester.tap(find.text('Move it to 18:30'));
      await tester.pumpAndSettle();

      expect(harness.plansRepository.retimed, [
        {'planId': 77, 'time': '18:30:00', 'timeLabel': null},
      ]);
    });

    testWidgets('nothing to settle when the plan is already at the leader',
        (tester) async {
      await _pumpPlan(
        tester,
        friendsRepository: FakeFriendsRepository(
          votes: [testPlanVote(PlanSlot.dinner, 'a')],
        ),
      );

      expect(find.textContaining('Move it to'), findsNothing);
    });

    testWidgets('nothing to settle on a tie', (tester) async {
      await _pumpPlan(
        tester,
        friendsRepository: FakeFriendsRepository(
          votes: [
            testPlanVote(PlanSlot.noon, 'a'),
            testPlanVote(PlanSlot.early, 'b'),
          ],
        ),
      );

      expect(find.textContaining('Move it to'), findsNothing);
    });

    testWidgets('a guest is asked to answer instead of to settle',
        (tester) async {
      final harness = await _pumpPlan(
        tester,
        me: 'guest',
        planRows: [
          testPlan(
            77,
            date: DateTime(2026, 9, 4),
            members: const [PlanMember(userId: 'guest', status: 'invited')],
          ),
        ],
        friendsRepository: FakeFriendsRepository(
          votes: [
            testPlanVote(PlanSlot.early, 'a'),
            testPlanVote(PlanSlot.early, 'b'),
          ],
        ),
      );

      expect(find.textContaining('Move it to'), findsNothing);

      await tester.tap(find.text('Going'));
      await tester.pumpAndSettle();

      expect(harness.friendsRepository.calls, contains('answerInvite'));
    });
  });

  group('the roster', () {
    testWidgets('says what each guest answered', (tester) async {
      await _pumpPlan(
        tester,
        friendsRepository: FakeFriendsRepository(
          planPeople: [
            testPlanPerson(77, 'a', name: 'Aiman Zulkifli', status: 'going'),
            testPlanPerson(77, 'b', name: 'Mei Kee Tan', status: 'declined'),
            testPlanPerson(77, 'c', name: 'Syafiq Rahman'),
          ],
        ),
      );

      expect(find.byType(PersonRow), findsNWidgets(3));
      expect(find.text('Going'), findsOneWidget);
      expect(find.text("Can't"), findsOneWidget);
      expect(find.text('Asked'), findsOneWidget);
    });

    testWidgets('a plan with nobody on it says so', (tester) async {
      await _pumpPlan(tester);

      expect(find.text('Just you so far.'), findsOneWidget);
      expect(find.byType(PersonRow), findsNothing);
    });
  });

  testWidgets('the whole screen survives a narrow phone at double text size',
      (tester) async {
    await _pumpPlan(
      tester,
      viewport: _narrowViewport,
      textScaler: const TextScaler.linear(2),
      friendsRepository: FakeFriendsRepository(
        votes: [testPlanVote(PlanSlot.dinner, 'a')],
        planPeople: [testPlanPerson(77, 'a', name: 'Aiman Zulkifli')],
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
