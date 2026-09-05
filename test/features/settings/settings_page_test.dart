import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_eat/core/ui/radius_options.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/settings/presentation/settings_page.dart';

import '../auth/fake_auth_repository.dart';
import '../profile/fake_profile_repository.dart';

AppUser _user({int? searchRadiusKm}) => AppUser(
      id: '39c39a30-c8fb-4e08-8e13-c90212f68e59',
      name: 'Demo User',
      email: 'demo@swipeeat.test',
      onboardedAt: DateTime(2026, 8, 23),
      searchRadiusKm: searchRadiusKm,
    );

void main() {
  late FakeAuthRepository authRepository;
  late AuthController auth;
  late FakeProfileRepository profile;

  Future<void> pumpSettings(WidgetTester tester,
      {int? searchRadiusKm}) async {
    // The auth controller caches the profile on the device; without a fake
    // store behind it every resolve logs a missing-plugin failure.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    authRepository = FakeAuthRepository()
      ..sessionPresent = true
      ..profile = _user(searchRadiusKm: searchRadiusKm);
    auth = AuthController(authRepository);
    addTearDown(() async {
      auth.dispose();
      await authRepository.dispose();
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
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(value);
    await tester.pump();
    tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(value);
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
        tester.widget<Slider>(find.byType(Slider)).value,
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
  });
}
