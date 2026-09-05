import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/profile/presentation/profile_tab.dart';
import 'package:swipe_eat/features/restaurants/state/likes_controller.dart';

import '../../support/widget_test_support.dart';
import '../auth/fake_auth_repository.dart';
import '../restaurants/fake_restaurant_repositories.dart';
import 'fake_profile_repository.dart';

const Size _phoneViewport = Size(390, 844);

/// The narrowest phone the design has to survive.
const Size _narrowViewport = Size(320, 640);

AppUser _user({
  String name = 'Hana Abdullah',
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

  Future<void> pumpTab(
    WidgetTester tester, {
    AppUser? user,
    Size viewport = _phoneViewport,
    int likedCount = 142,
    ProfileStats stats = const ProfileStats(),
    int notificationCount = 0,
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

    useViewport(tester, viewport);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileTab(
            authController: auth,
            likes: likes,
            repository: profile,
            stats: stats,
            notificationCount: notificationCount,
          ),
        ),
      ),
    );
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
      await tester.tap(find.text('Hides places without halal certification'));
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
      await tester.tap(find.text('Hides places without halal certification'));
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
          .widget<RangeSlider>(find.byType(RangeSlider))
          .onChanged!(const RangeValues(10, 100));
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
  });

  group('ProfileTab layout', () {
    testWidgets('does not overflow at 320 px', (tester) async {
      await pumpTab(tester, viewport: _narrowViewport);

      expect(tester.takeException(), isNull);
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

      expect(find.text('Hides places without halal certification'),
          findsOneWidget,
          reason: 'the tap action must open the sheet');

      handle.dispose();
    });
  });
}

/// Counts the ember-filled spice pips on screen.
int _litPips(WidgetTester tester) {
  var lit = 0;
  for (final container
      in tester.widgetList<Container>(find.byType(Container))) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration &&
        decoration.shape == BoxShape.circle &&
        decoration.color == kAccentEmber &&
        container.constraints?.maxWidth == kSpicePipSize) {
      lit++;
    }
  }
  return lit;
}
