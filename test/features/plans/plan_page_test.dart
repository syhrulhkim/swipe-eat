import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/friends/presentation/person_row.dart';
import 'package:swipe_eat/features/friends/state/friends_controller.dart';
import 'package:swipe_eat/features/plans/models/friend_plan.dart';
import 'package:swipe_eat/features/plans/models/plan.dart';
import 'package:swipe_eat/features/plans/models/plan_slot.dart';
import 'package:swipe_eat/features/plans/presentation/plan_page.dart';
import 'package:swipe_eat/features/plans/state/plans_controller.dart';
import 'package:swipe_eat/features/profile/presentation/preference_controls.dart';
import 'package:swipe_eat/features/restaurants/state/likes_controller.dart'
    show LikesAuthEvents;

import '../../support/widget_test_support.dart';
import '../friends/fake_friends_repository.dart';
import 'fake_plans_repository.dart';

const Size _phoneViewport = Size(390, 844);
const Size _narrowViewport = Size(320, 568);

final DateTime _now = DateTime(2026, 9, 6, 19, 41);

/// Signed in as somebody, without a Supabase singleton to be signed in to —
/// the same seam [LikesController]'s own tests use. Nothing here follows auth
/// changes, so the stream is never opened.
class _FakeAuthEvents extends LikesAuthEvents {
  _FakeAuthEvents(this.userId);

  final String? userId;

  @override
  Stream<AuthState>? get changes => null;

  @override
  String? get currentUserId => userId;
}

class _Harness {
  _Harness({
    required this.friendsRepository,
    required this.friends,
    required this.plansRepository,
    required this.plans,
    required this.pushed,
  });

  final FakeFriendsRepository friendsRepository;
  final FriendsController friends;
  final FakePlansRepository plansRepository;
  final PlansController plans;

  /// Where the screen sent the user. The plan page pushes two routes — the
  /// restaurant behind the plan, and the invite list.
  final List<String> pushed;
}

Future<_Harness> _pumpPlan(
  WidgetTester tester, {
  FakeFriendsRepository? friendsRepository,
  List<Plan>? planRows,
  int planId = 77,
  String? me = 'owner',
  List<FriendPlan> friendPlans = const [],
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
    friendPlans: friendPlans,
  );
  final plans = PlansController(
    repository: plansBacking,
    clock: () => _now,
    followAuthChanges: false,
  );
  addTearDown(plans.dispose);
  await plans.ensureLoaded();

  final pushed = <String>[];
  // A router rather than a bare `home:`, because two of the screen's controls
  // are pushes and a test that cannot follow them cannot check them.
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            PlanPage(planId: planId, friends: friends, plans: plans),
      ),
      GoRoute(
        path: '/plans/:id/invite',
        builder: (context, state) {
          pushed.add('/plans/${state.pathParameters['id']}/invite');
          return const Scaffold(body: Text('invite'));
        },
      ),
      GoRoute(
        path: '/restaurant/:id',
        builder: (context, state) {
          pushed.add('/restaurant/${state.pathParameters['id']}');
          return const Scaffold(body: Text('detail'));
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
    friendsRepository: friendsBacking,
    friends: friends,
    plansRepository: plansBacking,
    plans: plans,
    pushed: pushed,
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
      // And the screen has moved on: the plan reads back at its new time and
      // there is nothing left to settle.
      expect(find.text('Fri 4 Sep · 18:30'), findsOneWidget);
      expect(find.textContaining('Move it to'), findsNothing);
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

  group('sharing it', () {
    testWidgets('the owner gets a switch that starts off', (tester) async {
      await _pumpPlan(tester);

      expect(find.text('Share with friends'), findsOneWidget);
      final control = tester.widget<PrefSwitch>(
        find.descendant(
          of: find.widgetWithText(PrefSwitchRow, 'Share with friends'),
          matching: find.byType(PrefSwitch),
        ),
      );
      expect(control.value, isFalse);
    });

    testWidgets('flipping it writes the plan and reads the row back',
        (tester) async {
      final harness = await _pumpPlan(tester);

      await tester.tap(find.text('Share with friends'));
      await tester.pumpAndSettle();

      expect(harness.plansRepository.sharedSet.single, (77, true));
      expect(harness.plans.planById(77)!.sharedWithFriends, isTrue);
    });

    testWidgets('a guest is not offered the switch at all', (tester) async {
      await _pumpPlan(
        tester,
        me: 'guest',
        planRows: [
          testPlan(
            77,
            date: DateTime(2026, 9, 4),
            members: const [PlanMember(userId: 'guest', status: 'invited')],
          ),
        ],
      );

      expect(find.text('Share with friends'), findsNothing);
      expect(find.text('Invite friends'), findsNothing);
    });

    testWidgets('Invite friends opens the invite list for this plan',
        (tester) async {
      final harness = await _pumpPlan(tester);

      await tester.ensureVisible(find.text('Invite friends'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invite friends'));
      await tester.pumpAndSettle();

      expect(harness.pushed, ['/plans/77/invite']);
    });
  });

  group('requests to join', () {
    testWidgets('somebody who asked is listed apart from the guests',
        (tester) async {
      await _pumpPlan(
        tester,
        friendsRepository: FakeFriendsRepository(
          planPeople: [
            testPlanPerson(77, 'a', name: 'Aiman Zulkifli', status: 'going'),
            testPlanPerson(77, 'z', name: 'Zara Khan', status: 'requested'),
          ],
        ),
      );

      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Asked to join'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      // Counted as a guest she would be counted as somebody owing a vote:
      // the owner plus Aiman is two, not three.
      expect(find.text('2 people still to vote'), findsOneWidget);
    });

    testWidgets('Accept answers that one person', (tester) async {
      final harness = await _pumpPlan(
        tester,
        friendsRepository: FakeFriendsRepository(
          planPeople: [
            testPlanPerson(77, 'z', name: 'Zara Khan', status: 'requested'),
          ],
        ),
      );

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(harness.friendsRepository.joinAnswers.single, (77, 'z', true));
    });

    testWidgets('Decline says no to the same person', (tester) async {
      final harness = await _pumpPlan(
        tester,
        friendsRepository: FakeFriendsRepository(
          planPeople: [
            testPlanPerson(77, 'z', name: 'Zara Khan', status: 'requested'),
          ],
        ),
      );

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();

      expect(harness.friendsRepository.joinAnswers.single, (77, 'z', false));
    });

    testWidgets('a plan I only asked to join says who I am waiting on',
        (tester) async {
      // A request is not a membership, so the plan itself is invisible to me
      // (D153) — the only row I can see is the one the Calendar's Friends
      // section reads, and it carries the owner's name.
      final harness = await _pumpPlan(
        tester,
        me: 'asker',
        planRows: const [],
        friendPlans: [
          testFriendPlan(
            77,
            date: DateTime(2026, 9, 4),
            ownerName: 'Aisyah Rahman',
            asked: true,
          ),
        ],
      );

      expect(find.text('Waiting on Aisyah.'), findsOneWidget);
      expect(find.text('That plan is not on your calendar.'), findsNothing);
      // A push can land on a plan the calendar has never read, so it re-reads
      // once — and only once, however many times the screen rebuilds.
      expect(harness.plansRepository.listedFrom, hasLength(2));
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

    testWidgets('somebody who said no is not still to vote', (tester) async {
      await _pumpPlan(
        tester,
        friendsRepository: FakeFriendsRepository(
          votes: [testPlanVote(PlanSlot.dinner, 'a')],
          planPeople: [
            testPlanPerson(77, 'a', status: 'going'),
            testPlanPerson(77, 'b', status: 'declined'),
          ],
        ),
      );

      // Two guests, one of whom is not coming. The owner and the one who is
      // coming are the two being waited on, and one of them has voted.
      expect(find.text('1 person still to vote'), findsOneWidget);
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
