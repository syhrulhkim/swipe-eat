import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_eat/core/ui/radius_options.dart';
import 'package:swipe_eat/features/profile/presentation/preference_controls.dart';
import 'package:swipe_eat/features/onboarding/models/onboarding_draft.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/settings/presentation/settings_page.dart';

import '../auth/fake_auth_repository.dart';
import '../profile/fake_profile_repository.dart';

AppUser _user({
  int? searchRadiusKm,
  bool halalOnly = false,
  bool vegetarian = false,
  int? spiceLevel,
  int? budgetMin,
  int? budgetMax,
}) =>
    AppUser(
      id: '39c39a30-c8fb-4e08-8e13-c90212f68e59',
      name: 'Demo User',
      email: 'demo@swipeeat.test',
      onboardedAt: DateTime(2026, 8, 23),
      searchRadiusKm: searchRadiusKm,
      halalOnly: halalOnly,
      vegetarian: vegetarian,
      spiceLevel: spiceLevel,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
    );

/// The page carries two sliders — the radius above and the budget below — so
/// each finder names the row it belongs to rather than trusting the order.
Finder get _radiusSlider => find.byWidgetPredicate(
      (widget) => widget is Slider && widget.max == kRadiusStops.length - 1,
      description: 'the radius Slider',
    );
Finder get _budgetSlider => find.descendant(
      of: find.byType(PrefBudgetRow),
      matching: find.byType(Slider),
    );

void main() {
  late FakeAuthRepository authRepository;
  late AuthController auth;
  late FakeProfileRepository profile;

  Future<void> pumpSettings(
    WidgetTester tester, {
    int? searchRadiusKm,
    AppUser? user,
  }) async {
    // The auth controller caches the profile on the device; without a fake
    // store behind it every resolve logs a missing-plugin failure.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    authRepository = FakeAuthRepository()
      ..sessionPresent = true
      ..profile = user ?? _user(searchRadiusKm: searchRadiusKm);
    auth = AuthController(authRepository);
    // Captured, not read off the fields: a test that pumps the page twice
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

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(authController: auth, repository: profile),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drives the slider through its callbacks: gesture-dragging a Material
  /// slider to an exact division is brittle, and the wiring under test is
  /// what happens on change/end, not the gesture math.
  Future<void> moveSliderTo(WidgetTester tester, double value) async {
    final slider = tester.widget<Slider>(_radiusSlider);
    slider.onChanged!(value);
    await tester.pump();
    tester.widget<Slider>(_radiusSlider).onChangeEnd!(value);
    await tester.pumpAndSettle();
  }

  group('SettingsPage search radius', () {
    testWidgets('shows the stored radius', (tester) async {
      await pumpSettings(tester, searchRadiusKm: 10);

      expect(find.text('10 km'), findsOneWidget);
    });

    testWidgets('a missing radius reads as Any distance', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Any distance'), findsOneWidget);
    });

    testWidgets('a stored radius that is not a slider stop still renders',
        (tester) async {
      // The stops can be re-cut (or a row can be written by another client),
      // leaving a stored value the slider has no position for. The label
      // still reports the truth; the thumb parks on the last stop. Without
      // that guard the slider is built with value -1 against 9 divisions,
      // which trips an assertion and takes the whole Settings page down.
      await pumpSettings(tester, searchRadiusKm: 7);

      expect(find.text('7 km'), findsOneWidget);
      expect(
        tester.widget<Slider>(_radiusSlider).value,
        (kRadiusStops.length - 1).toDouble(),
      );
    });

    testWidgets('releasing the slider writes the new radius', (tester) async {
      await pumpSettings(tester);

      // Index 3 of the stops is 10 km.
      await moveSliderTo(tester, 3);

      expect(profile.radiusCalls, [10]);
      expect(auth.user?.searchRadiusKm, 10,
          reason: 'the returned profile row must be applied to the session');
      expect(find.text('10 km'), findsOneWidget);
    });

    testWidgets('sliding back to the end clears the radius', (tester) async {
      await pumpSettings(tester, searchRadiusKm: 10);

      // The last stop is null — "Any distance".
      await moveSliderTo(tester, 9);

      expect(profile.radiusCalls, [null]);
      expect(auth.user?.searchRadiusKm, isNull);
      expect(find.text('Any distance'), findsOneWidget);
    });

    testWidgets('releasing on the unchanged value writes nothing',
        (tester) async {
      await pumpSettings(tester, searchRadiusKm: 10);

      await moveSliderTo(tester, 3);

      expect(profile.radiusCalls, isEmpty);
    });

    testWidgets('a failed write snaps back and explains itself',
        (tester) async {
      await pumpSettings(tester, searchRadiusKm: 10);
      profile.fail = true;

      await moveSliderTo(tester, 5); // 20 km

      expect(find.text('Could not save your search radius.'), findsOneWidget);
      expect(find.text('10 km'), findsOneWidget,
          reason: 'the label must not keep a value the backend refused');
      expect(auth.user?.searchRadiusKm, 10);
    });
  });

  group('SettingsPage rules', () {
    testWidgets('asks the same four questions the first run does',
        (tester) async {
      await pumpSettings(tester);

      expect(find.text('Halal only'), findsOneWidget);
      expect(find.text('Vegetarian options'), findsOneWidget);
      expect(find.text('Spice'), findsOneWidget);
      expect(find.text('Budget per person'), findsOneWidget);
      for (final label in const ['Mild', 'Medium', 'Pedas', 'Bring it']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('the spice segment writes the 1-4 level', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Bring it'));
      await tester.pumpAndSettle();

      expect(profile.preferenceCalls.single.spiceLevel, 4);
      expect(auth.user?.spiceLevel, 4);
    });

    testWidgets('a switch writes only itself', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Halal only'));
      await tester.pumpAndSettle();

      expect(profile.preferenceCalls.single.halalOnly, isTrue);
      expect(profile.preferenceCalls.single.vegetarian, isNull);
      expect(auth.user?.halalOnly, isTrue);
    });

    testWidgets('a failed write puts the old answer back', (tester) async {
      await pumpSettings(tester);
      profile.fail = true;

      await tester.tap(find.text('Vegetarian options'));
      await tester.pumpAndSettle();

      expect(find.text('Could not save that preference.'), findsOneWidget);
      expect(auth.user?.vegetarian, isFalse);
    });

    testWidgets('the vegetarian switch writes only itself', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Vegetarian options'));
      await tester.pumpAndSettle();

      final call = profile.preferenceCalls.single;
      expect(call.vegetarian, isTrue);
      expect(call.halalOnly, isNull);
      expect(call.spiceLevel, isNull);
      expect(call.budgetMin, isNull);
      expect(auth.user?.vegetarian, isTrue);
    });

    testWidgets('a switch already on is turned off, not merely re-sent',
        (tester) async {
      await pumpSettings(tester, user: _user(halalOnly: true));

      await tester.tap(find.text('Halal only'));
      await tester.pumpAndSettle();

      expect(profile.preferenceCalls.single.halalOnly, isFalse);
      expect(auth.user?.halalOnly, isFalse);
    });

    for (final (label, level) in const [
      ('Mild', 1),
      ('Medium', 2),
      ('Pedas', 3),
      ('Bring it', 4),
    ]) {
      testWidgets('"$label" writes spice level $level', (tester) async {
        await pumpSettings(tester);

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(profile.preferenceCalls.single.spiceLevel, level);
        expect(auth.user?.spiceLevel, level);
      });
    }

    testWidgets('the stored answers are what the controls show',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSettings(
        tester,
        user: _user(
          halalOnly: true,
          spiceLevel: 3,
          budgetMin: 15,
          budgetMax: 60,
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Halal only')),
        isSemantics(hasToggledState: true, isToggled: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Vegetarian options')),
        isSemantics(hasToggledState: true, isToggled: false),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Pedas')),
        isSemantics(hasSelectedState: true, isSelected: true),
      );
      expect(find.text('RM 15\u201360'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('an unset budget reads the same here as it does on the tab',
        (tester) async {
      // The three screens share one spelling of a budget so they cannot
      // disagree about what is stored. A profile that never answered must not
      // be shown a floor it never chose.
      await pumpSettings(tester);

      expect(find.text('RM 10+'), findsNothing,
          reason: 'nobody set a floor of RM 10 with no ceiling');
      expect(find.text('RM 10\u201340'), findsOneWidget,
          reason: 'the control opens where the first run opens it');
    });

    testWidgets('the budget writes once per drag, not once per division',
        (tester) async {
      // The radius above it writes on release for exactly this reason: a
      // range reports on every frame, and ten writes racing each other can
      // leave the session holding whichever one happened to land last.
      await pumpSettings(tester);

      final slider = tester.widget<Slider>(_budgetSlider);
      for (final end in const [20.0, 35.0, 60.0]) {
        slider.onChanged!(end);
        await tester.pump();
      }

      expect(profile.preferenceCalls, isEmpty,
          reason: 'nothing is written while the finger is still down');
      expect(find.text('RM 10\u201360'), findsOneWidget,
          reason: 'the read-out still tracks the finger');

      tester.widget<Slider>(_budgetSlider).onChangeEnd!(60);
      await tester.pumpAndSettle();

      expect(profile.preferenceCalls, hasLength(1));
      expect(profile.preferenceCalls.single.budgetMin, kBudgetDefaultMin);
      expect(profile.preferenceCalls.single.budgetMax, 60);
      expect(auth.user?.budgetMin, kBudgetDefaultMin,
          reason: 'the design draws one thumb; the floor is fixed at RM 10');
      expect(auth.user?.budgetMax, 60);
    });

    testWidgets('releasing the cap mid-drag reads "and up" under the finger',
        (tester) async {
      // A released ceiling is a null, and null is also "no drag value yet",
      // so a careless fallback puts the stored cap back while the thumb is
      // still held at the top stop.
      await pumpSettings(tester, user: _user(budgetMin: 10, budgetMax: 40));

      tester.widget<Slider>(_budgetSlider).onChanged!(100);
      await tester.pump();

      expect(find.text('RM 10+'), findsOneWidget);
      expect(
        tester.widget<Slider>(_budgetSlider).value,
        kBudgetCeiling.toDouble(),
        reason: 'the thumb must stay where the finger put it',
      );
      expect(profile.preferenceCalls, isEmpty);
    });

    testWidgets('the top stop releases the cap here too', (tester) async {
      await pumpSettings(tester, user: _user(budgetMin: 10, budgetMax: 40));

      tester.widget<Slider>(_budgetSlider).onChanged!(100);
      await tester.pump();
      tester.widget<Slider>(_budgetSlider).onChangeEnd!(100);
      await tester.pumpAndSettle();

      expect(profile.preferenceCalls.single.budgetMin, 10);
      expect(profile.preferenceCalls.single.budgetMax, isNull);
      expect(auth.user?.budgetMax, isNull);
      expect(find.text('RM 10+'), findsOneWidget);
    });

    testWidgets('a failed budget write puts the old range back',
        (tester) async {
      await pumpSettings(tester, user: _user(budgetMin: 10, budgetMax: 60));
      profile.fail = true;

      tester.widget<Slider>(_budgetSlider).onChanged!(80);
      await tester.pump();
      tester.widget<Slider>(_budgetSlider).onChangeEnd!(80);
      await tester.pumpAndSettle();

      expect(find.text('Could not save that preference.'), findsOneWidget);
      expect(auth.user?.budgetMin, 10);
      expect(find.text('RM 10\u201360'), findsOneWidget,
          reason: 'the read-out must not keep a range the backend refused');
    });

    testWidgets('nothing to edit when nobody is signed in', (tester) async {
      await pumpSettings(tester);
      await auth.logout();
      await tester.pumpAndSettle();

      expect(find.text('Halal only'), findsNothing);
      expect(find.text('Budget per person'), findsNothing);
      expect(find.text('Sign out'), findsOneWidget,
          reason: 'the rest of the page is still there');
    });
  });
}
