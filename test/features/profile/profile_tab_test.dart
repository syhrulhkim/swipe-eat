import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/friends/state/friends_controller.dart';
import 'package:swipe_eat/features/profile/presentation/profile_tab.dart';
import 'package:swipe_eat/features/restaurants/state/likes_controller.dart';
import 'package:swipe_eat/features/onboarding/models/onboarding_draft.dart';

import '../../support/widget_test_support.dart';
import '../auth/fake_auth_repository.dart';
import '../friends/fake_friends_repository.dart';
import '../restaurants/fake_restaurant_repositories.dart';
import 'fake_profile_repository.dart';

const Size _phoneViewport = Size(390, 844);

/// The narrowest phone the design has to survive.
const Size _narrowViewport = Size(320, 640);

const TextScaler _hugeTextScale = TextScaler.linear(2);

AppUser _user({
  String name = 'Hana Abdullah',
  String? avatarUrl,
  String? lastPlaceName = 'Bangsar',
  DateTime? createdAt,
  int? searchRadiusKm = 3,
  bool halalOnly = true,
  bool vegetarian = false,
  int? spiceLevel = 4,
  int? budgetMin = 10,
  int? budgetMax = 40,
}) {
  return AppUser(
    id: '39c39a30-c8fb-4e08-8e13-c90212f68e59',
    name: name,
    email: 'demo@swipeeat.test',
    avatarUrl: avatarUrl,
    onboardedAt: DateTime(2026, 3, 4),
    createdAt: createdAt ?? DateTime(2026, 3, 4),
    lastPlaceName: lastPlaceName,
    searchRadiusKm: searchRadiusKm,
    halalOnly: halalOnly,
    vegetarian: vegetarian,
    spiceLevel: spiceLevel,
    budgetMin: budgetMin,
    budgetMax: budgetMax,
  );
}

void main() {
  late FakeAuthRepository authRepository;
  late AuthController auth;
  late FakeProfileRepository profile;
  late LikesController likes;
  late FriendsController friends;

  Future<void> pumpTab(
    WidgetTester tester, {
    AppUser? user,
    Size viewport = _phoneViewport,
    int likedCount = 142,
    ProfileStats stats = const ProfileStats(),
    int notificationCount = 0,
    int friendCount = 0,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    authRepository = FakeAuthRepository()
      ..sessionPresent = true
      ..profile = user ?? _user();
    auth = AuthController(authRepository);
    // Captured, not read off the fields: a test that pumps the tab twice
    // reassigns them, and a teardown reading the field would dispose the
    // second controller twice and leak the first.
    final controller = auth;
    final repository = authRepository;
    addTearDown(() async {
      controller.dispose();
      await repository.dispose();
    });
    await auth.bootstrap();
    profile = FakeProfileRepository(auth.user!);

    final restaurants = FakeRestaurantRepository()
      ..likedRows = [
        for (var id = 1; id <= likedCount; id++) testRestaurant(id),
      ];
    final swipes = FakeSwipeRepository();
    wireFakeBackend(restaurants, swipes);
    likes = LikesController(
      restaurants: restaurants,
      swipes: swipes,
      followAuthChanges: false,
    );
    addTearDown(likes.dispose);

    friends = FriendsController(
      repository: FakeFriendsRepository(
        friends: [
          for (var i = 0; i < friendCount; i++) testFriend('u$i'),
        ],
      ),
      followAuthChanges: false,
    );
    addTearDown(friends.dispose);

    useViewport(tester, viewport);
    // Routed rather than bare: the Settings button pushes '/settings', and a
    // bare MaterialApp would throw rather than navigate.
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: Scaffold(
              body: ProfileTab(
                authController: auth,
                likes: likes,
                friends: friends,
                repository: profile,
                stats: stats,
                notificationCount: notificationCount,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) =>
              const Scaffold(body: Text('settings route')),
        ),
        GoRoute(
          path: '/friends',
          builder: (context, state) =>
              const Scaffold(body: Text('friends route')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  group('ProfileTab identity', () {
    testWidgets('titles the screen "You" and names the account below it',
        (tester) async {
      await pumpTab(tester);

      expect(find.text('You'), findsOneWidget);
      expect(find.text('Hana Abdullah'), findsOneWidget);
      expect(find.text('Bangsar · eating out since Mar 2026'), findsOneWidget);
    });

    testWidgets('drops the place when there has never been a fix',
        (tester) async {
      await pumpTab(tester, user: _user(lastPlaceName: null));

      expect(find.text('eating out since Mar 2026'), findsOneWidget);
    });

    testWidgets('hides the notification dot until there is something in it',
        (tester) async {
      await pumpTab(tester);
      expect(find.text('1'), findsNothing);

      await pumpTab(tester, notificationCount: 1);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('the bell says how many are waiting, and how many is none',
        (tester) async {
      // The dot is a colour; a screen reader gets the count in words or it
      // gets nothing at all.
      final handle = tester.ensureSemantics();

      await pumpTab(tester);
      expect(find.bySemanticsLabel('Notifications'), findsOneWidget,
          reason: 'the bell must be its own node, not part of the title');
      expect(find.bySemanticsLabel('You'), findsOneWidget);

      await pumpTab(tester, notificationCount: 3);
      expect(find.bySemanticsLabel('Notifications, 3 waiting'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('falls back to initials when there is no photo',
        (tester) async {
      // A generic person glyph tells you less about whose account this is
      // than two letters do.
      await pumpTab(tester);

      expect(find.text('HA'), findsOneWidget);
    });

    testWidgets('a one-word name gives one initial', (tester) async {
      await pumpTab(tester, user: _user(name: 'Aisyah'));

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('a signed-out tab says so rather than inventing a name',
        (tester) async {
      await pumpTab(tester);
      await auth.logout();
      await tester.pumpAndSettle();

      expect(find.text('Guest'), findsOneWidget);
      expect(find.text('Not signed in'), findsOneWidget);
      expect(find.text('Your taste'), findsNothing,
          reason: 'there are no rules to edit without an account');
    });

    testWidgets('a profile with neither place nor age reads "New here"',
        (tester) async {
      // A cache written before `created_at` was read has no month to name and
      // no fix to place; a bare separator would read as a missing word.
      await pumpTab(
        tester,
        user: const AppUser(
          id: '39c39a30-c8fb-4e08-8e13-c90212f68e59',
          name: 'Hana Abdullah',
          email: 'demo@swipeeat.test',
        ),
      );

      expect(find.text('New here'), findsOneWidget);
    });

    testWidgets('names the month the account was made', (tester) async {
      await pumpTab(
        tester,
        user: _user(lastPlaceName: null, createdAt: DateTime(2025, 12, 31)),
      );

      expect(find.text('eating out since Dec 2025'), findsOneWidget);
    });
  });

  group('ProfileTab stats', () {
    testWidgets('names all three counts', (tester) async {
      await pumpTab(
        tester,
        likedCount: 8,
        stats: const ProfileStats(plansKept: 27, streakWeeks: 6),
      );

      expect(find.text('8'), findsOneWidget);
      expect(find.text('bites'), findsOneWidget);
      expect(find.text('27'), findsOneWidget);
      expect(find.text('plans kept'), findsOneWidget);
      expect(find.text('6 wk'), findsOneWidget);
      expect(find.text('eating-out streak'), findsOneWidget);
    });

    testWidgets('shows zero for the counts nothing feeds yet', (tester) async {
      await pumpTab(tester, likedCount: 3);

      expect(find.text('0'), findsOneWidget);
      expect(find.text('0 wk'), findsOneWidget);
    });
  });

  group('ProfileTab taste list', () {
    testWidgets('reports each preference as it is stored', (tester) async {
      await pumpTab(tester);

      expect(find.text('Halal only'), findsOneWidget);
      expect(find.text('On'), findsOneWidget);
      expect(find.text('RM 10–40'), findsOneWidget);
      expect(find.text('3 km'), findsOneWidget);
    });

    testWidgets('an uncapped budget reads "and up", an unset one "Any"',
        (tester) async {
      await pumpTab(tester, user: _user(budgetMin: 10, budgetMax: null));
      expect(find.text('RM 10+'), findsOneWidget);

      await pumpTab(tester, user: _user(budgetMin: null, budgetMax: null));
      expect(find.text('Any'), findsOneWidget);
    });

    testWidgets('an unset radius reads "Any distance"', (tester) async {
      await pumpTab(tester, user: _user(searchRadiusKm: null));

      expect(find.text('Any distance'), findsOneWidget);
    });

    testWidgets('draws five pips whatever the answer', (tester) async {
      // Five for four levels, exactly as the prototype draws it: "Bring it"
      // still leaves one dark, so the scale never reads as maxed out.
      await pumpTab(tester, user: _user(spiceLevel: 4));
      expect(_pips(tester), 5);

      await pumpTab(tester, user: _user(spiceLevel: null));
      expect(_pips(tester), 5);
    });

    testWidgets('lights one pip per spice level, out of five', (tester) async {
      // "Bring it" is 4 of 5, so the scale never reads as maxed out — which is
      // exactly how the prototype draws it.
      await pumpTab(tester, user: _user(spiceLevel: 4));
      expect(_litPips(tester), 4);

      await pumpTab(tester, user: _user(spiceLevel: 1));
      expect(_litPips(tester), 1);

      await pumpTab(tester, user: _user(spiceLevel: null));
      expect(_litPips(tester), 0);
    });

    testWidgets('the videos-autoplay row is absent', (tester) async {
      // The TikTok player hard-codes autoplay and the app cannot detect Wi-Fi,
      // so the row would be a setting that does nothing.
      await pumpTab(tester);

      expect(find.text('Videos autoplay'), findsNothing);
    });
  });

  group('ProfileTab editing', () {
    testWidgets('a switch in the sheet writes only that preference',
        (tester) async {
      await pumpTab(tester);

      await tester.tap(find.text('Halal only'));
      await tester.pumpAndSettle();

      // The sheet's own copy of the row; the tab's is still behind it.
      await tester.tap(find.text('Only places we know are certified'));
      await tester.pumpAndSettle();

      expect(profile.preferenceCalls, hasLength(1));
      expect(profile.preferenceCalls.single.halalOnly, isFalse);
      expect(profile.preferenceCalls.single.spiceLevel, isNull,
          reason: 'a sheet that edits one thing sends one thing');
      expect(find.text('Off'), findsOneWidget);
    });

    testWidgets('a segment in the sheet writes the level', (tester) async {
      await pumpTab(tester, user: _user(spiceLevel: 1));

      await tester.tap(find.text('Spice'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pedas'));
      await tester.pumpAndSettle();

      expect(profile.preferenceCalls.single.spiceLevel, 3);
      expect(_litPips(tester), 3);
    });

    testWidgets('a failed write puts the old answer back and says so',
        (tester) async {
      await pumpTab(tester);
      profile.fail = true;

      await tester.tap(find.text('Halal only'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Only places we know are certified'));
      await tester.pumpAndSettle();

      expect(find.text('On'), findsOneWidget,
          reason: 'the optimistic value must not survive a failed write');
      expect(find.text('Could not save that preference.'), findsOneWidget);
    });

    testWidgets('dragging the budget to the top stop releases the cap',
        (tester) async {
      // The one path the draft tests cannot reach: the slider's own callback is
      // what turns "RM 100" into "no ceiling", and a stored 100 would filter
      // out every place priced above it rather than none of them.
      await pumpTab(tester);

      await tester.tap(find.text('Budget per person'));
      await tester.pumpAndSettle();
      // Driven through the callback rather than by gesture: landing a range
      // thumb on an exact division is brittle, and the mapping is the subject.
      tester
          .widget<Slider>(find.byType(Slider))
          .onChanged!(100);
      await tester.pumpAndSettle();
      expect(find.text('RM 10+'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(profile.preferenceCalls.single.budgetMin, 10);
      expect(profile.preferenceCalls.single.budgetMax, isNull);
      expect(find.text('RM 10+'), findsOneWidget);
    });

    testWidgets('dismissing the budget sheet without touching it writes nothing',
        (tester) async {
      await pumpTab(tester, user: _user(budgetMin: null, budgetMax: null));

      await tester.tap(find.text('Budget per person'));
      await tester.pumpAndSettle();
      // Tap the barrier.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(profile.preferenceCalls, isEmpty);
      expect(find.text('Any'), findsOneWidget);
    });

    testWidgets('the radius sheet can choose "Any distance"', (tester) async {
      await pumpTab(tester);

      await tester.tap(find.text('Default radius'));
      await tester.pumpAndSettle();
      // Ten stops do not fit a sheet on this viewport; the last one is real,
      // it is just below the fold.
      await tester.ensureVisible(find.text('Any distance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Any distance'));
      await tester.pumpAndSettle();

      expect(profile.radiusCalls, [null]);
      expect(find.text('Any distance'), findsOneWidget);
    });

    testWidgets('every row opens its own control', (tester) async {
      // Four rows, four sheets. A chevron that opens the wrong question is a
      // bug nothing else here would catch.
      await pumpTab(tester);

      for (final (row, marker) in const [
        ('Halal only', 'Only places we know are certified'),
        ('Spice', 'How hot is too hot?'),
        ('Budget per person', 'RM 100+'),
        ('Default radius', '2 km'),
      ]) {
        await tester.tap(find.text(row));
        await tester.pumpAndSettle();

        expect(find.text(marker), findsWidgets, reason: row);

        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('the spice sheet sends the level and nothing else',
        (tester) async {
      await pumpTab(tester, user: _user(spiceLevel: 1));

      await tester.tap(find.text('Spice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bring it'));
      await tester.pumpAndSettle();

      final call = profile.preferenceCalls.single;
      expect(call.spiceLevel, 4);
      expect(call.halalOnly, isNull);
      expect(call.vegetarian, isNull);
      expect(call.budgetMin, isNull);
      expect(call.clearBudget, isFalse,
          reason: 'a sheet that edits one thing sends one thing');
      expect(auth.user?.spiceLevel, 4);
    });

    testWidgets('the budget sheet sends the cap and nothing else',
        (tester) async {
      await pumpTab(tester);

      await tester.tap(find.text('Budget per person'));
      await tester.pumpAndSettle();
      tester
          .widget<Slider>(find.byType(Slider))
          .onChanged!(60);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      final call = profile.preferenceCalls.single;
      expect(call.budgetMin, kBudgetDefaultMin,
          reason: 'the design draws one thumb over a fixed RM 10 floor');
      expect(call.budgetMax, 60);
      expect(call.halalOnly, isNull);
      expect(call.spiceLevel, isNull);
      expect(find.text('RM 10\u201360'), findsOneWidget);
    });

    testWidgets('a dragged budget writes once, not once per division',
        (tester) async {
      // The range reports on every frame of a drag; the sheet keeps the pair
      // locally and writes when it closes, or a single drag would be a dozen
      // round trips.
      await pumpTab(tester);

      await tester.tap(find.text('Budget per person'));
      await tester.pumpAndSettle();
      for (final end in const [20.0, 35.0, 60.0]) {
        tester
          .widget<Slider>(find.byType(Slider))
            .onChanged!(end);
        await tester.pump();
      }
      expect(profile.preferenceCalls, isEmpty,
          reason: 'nothing is written while the finger is still down');

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(profile.preferenceCalls, hasLength(1));
      expect(profile.preferenceCalls.single.budgetMax, 60);
    });

    testWidgets('a sheet dismissed without an answer writes nothing',
        (tester) async {
      await pumpTab(tester);

      for (final row in const ['Halal only', 'Spice', 'Default radius']) {
        await tester.tap(find.text(row));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }

      expect(profile.preferenceCalls, isEmpty);
      expect(profile.radiusCalls, isEmpty);
    });

    testWidgets('a failed radius write reverts and says so', (tester) async {
      await pumpTab(tester);
      profile.fail = true;

      await tester.tap(find.text('Default radius'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Any distance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Any distance'));
      await tester.pumpAndSettle();

      expect(find.text('Could not save that preference.'), findsOneWidget);
      expect(auth.user?.searchRadiusKm, 3);
      expect(find.text('3 km'), findsOneWidget);
    });

    testWidgets('the design\'s other ghost button counts the friends',
        (tester) async {
      await pumpTab(tester, friendCount: 38);

      expect(find.text('Friends · 38'), findsOneWidget);
    });

    testWidgets('a new account gets the button anyway, at zero',
        (tester) async {
      // "Friends · 0" is true, and a button that only appeared once you had
      // friends would be the one nobody could find in order to get any.
      await pumpTab(tester);

      expect(find.text('Friends · 0'), findsOneWidget);
    });

    testWidgets('Friends opens the friends page', (tester) async {
      await pumpTab(tester, friendCount: 2);

      await tester.tap(find.text('Friends · 2'));
      await tester.pumpAndSettle();

      expect(find.text('friends route'), findsOneWidget);
    });

    testWidgets('Settings opens the settings page', (tester) async {
      await pumpTab(tester);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('settings route'), findsOneWidget);
    });
  });

  group('ProfileTab layout', () {
    testWidgets('does not overflow at 320 px', (tester) async {
      await pumpTab(tester, viewport: _narrowViewport);

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at 320 px at double text size',
        (tester) async {
      // The stat labels wrap and the numbers are fitted; the taste rows have
      // a value and a chevron beside a label that can now be twice as wide.
      await pumpTab(
        tester,
        viewport: _narrowViewport,
        textScaler: _hugeTextScale,
        stats: const ProfileStats(plansKept: 27, streakWeeks: 6),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('You'), findsOneWidget);
    });

    testWidgets('both ghost buttons stack rather than squeeze at 320 px at '
        'double text size', (tester) async {
      await pumpTab(
        tester,
        viewport: _narrowViewport,
        textScaler: _hugeTextScale,
        friendCount: 38,
      );

      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(find.text('Settings'), 300);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Friends · 38'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('the budget sheet fits a narrow screen at double text size',
        (tester) async {
      await pumpTab(
        tester,
        viewport: _narrowViewport,
        textScaler: _hugeTextScale,
      );

      await tester.scrollUntilVisible(
        find.text('Budget per person'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Budget per person'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('every preference row clears a 44 pt target', (tester) async {
      await pumpTab(tester);

      for (final label in const [
        'Halal only',
        'Spice',
        'Budget per person',
        'Default radius',
      ]) {
        expect(
          tester
              .getSize(find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byType(InkWell),
                  )
                  .first)
              .height,
          greaterThanOrEqualTo(kUtilityButtonSize),
          reason: label,
        );
      }
    });

    testWidgets('reads each preference row as a labelled, valued button',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTab(tester);

      expect(find.bySemanticsLabel('Halal only'), findsOneWidget);
      expect(find.bySemanticsLabel('Budget per person'), findsOneWidget);
      // The pips carry no text, so the words have to come from the node.
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Spice'))
            .value,
        'Bring it',
      );

      handle.dispose();
    });

    testWidgets('a screen reader can open a preference row, not just read it',
        (tester) async {
      // D83: `excludeSemantics: true` drops the child's tap action, and a row
      // that reads correctly but cannot be activated fails silently. Proven by
      // driving the action, because finding the label does not prove it fires.
      final handle = tester.ensureSemantics();
      await pumpTab(tester);

      tester.semantics.tap(find.semantics.byLabel('Halal only'));
      await tester.pumpAndSettle();

      expect(find.text('Only places we know are certified'),
          findsOneWidget,
          reason: 'the tap action must open the sheet');

      handle.dispose();
    });
  });
}

/// Counts every spice pip on screen, lit or not.
int _pips(WidgetTester tester) => _countPips(tester, litOnly: false);

/// Counts the ember-filled spice pips on screen.
int _litPips(WidgetTester tester) => _countPips(tester, litOnly: true);

int _countPips(WidgetTester tester, {required bool litOnly}) {
  var count = 0;
  for (final container
      in tester.widgetList<Container>(find.byType(Container))) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration &&
        decoration.shape == BoxShape.circle &&
        container.constraints?.maxWidth == kSpicePipSize &&
        (!litOnly || decoration.color == kAccentEmber)) {
      count++;
    }
  }
  return count;
}
