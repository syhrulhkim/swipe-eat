import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:swipe_eat/core/location/user_location.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/onboarding/presentation/onboarding_page.dart';

import '../auth/fake_auth_repository.dart';
import 'fake_onboarding_repository.dart';

Position _position({double latitude = 1.9, double longitude = 103.1}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2026, 8, 23, 12),
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  late FakeAuthRepository authRepository;
  late AuthController auth;
  late FakeOnboardingRepository onboarding;

  setUp(() async {
    // The auth controller caches the profile on the device; without a fake
    // store behind it every resolve logs a missing-plugin failure.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    authRepository = FakeAuthRepository()
      ..sessionPresent = true
      ..profile = const AppUser(
        id: '39c39a30-c8fb-4e08-8e13-c90212f68e59',
        name: 'User',
        email: 'demo@swipeeat.test',
      );
    auth = AuthController(authRepository);
    await auth.bootstrap();
    onboarding = FakeOnboardingRepository();
  });

  tearDown(() async {
    auth.dispose();
    await authRepository.dispose();
  });

  Future<void> pumpWizard(
    WidgetTester tester, {
    Future<Position> Function()? resolvePosition,
    Future<String?> Function(Position)? resolvePlace,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingPage(
          authController: auth,
          repository: onboarding,
          resolvePosition: resolvePosition ?? () async => _position(),
          resolvePlace: resolvePlace ?? (_) async => 'Peserai, Batu Pahat',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The primary button carries the step's action label, so finding it by text
  /// also asserts which step we are on.
  Finder primaryButton(String label) => find.widgetWithText(FilledButton, label);

  bool isEnabled(WidgetTester tester, Finder finder) =>
      tester.widget<FilledButton>(finder).onPressed != null;

  Future<void> completeNameStep(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'Aisyah');
    await tester.pump();
    await tester.tap(primaryButton('Continue'));
    await tester.pumpAndSettle();
  }

  Future<void> completeTasteStep(WidgetTester tester) async {
    await tester.tap(find.text('🍛  Malay'));
    await tester.pump();
    await tester.tap(primaryButton('Continue'));
    await tester.pumpAndSettle();
  }

  group('onboarding wizard', () {
    testWidgets('cannot leave step one without a name', (tester) async {
      await pumpWizard(tester);

      expect(find.text('What should we call you?'), findsOneWidget);
      expect(isEnabled(tester, primaryButton('Continue')), isFalse);

      await tester.enterText(find.byType(TextField), 'Aisyah');
      await tester.pump();

      expect(isEnabled(tester, primaryButton('Continue')), isTrue);
    });

    testWidgets('does not prefill the handle_new_user placeholder name',
        (tester) async {
      // Every profile is seeded with 'User'; treating that as an answer would
      // let people through step one without ever naming themselves.
      await pumpWizard(tester);

      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
          isEmpty);
      expect(isEnabled(tester, primaryButton('Continue')), isFalse);
    });

    testWidgets('prefills the name an OAuth sign-in already knows',
        (tester) async {
      auth.applyUser(const AppUser(
        id: '39c39a30-c8fb-4e08-8e13-c90212f68e59',
        name: 'Aisyah',
        email: 'demo@swipeeat.test',
      ));

      await pumpWizard(tester);

      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
          'Aisyah');
      expect(isEnabled(tester, primaryButton('Continue')), isTrue);
    });

    testWidgets('cannot leave the taste step without a cuisine',
        (tester) async {
      await pumpWizard(tester);
      await completeNameStep(tester);

      expect(find.text('What do you like to eat?'), findsOneWidget);
      expect(isEnabled(tester, primaryButton('Continue')), isFalse);

      await tester.tap(find.text('🍛  Malay'));
      await tester.pump();

      expect(isEnabled(tester, primaryButton('Continue')), isTrue);
    });

    testWidgets('the habits step edits the tiles and the radius',
        (tester) async {
      await pumpWizard(tester);
      await completeNameStep(tester);
      await completeTasteStep(tester);

      expect(find.text('How do you eat?'), findsOneWidget);
      expect(find.text('No limit'), findsWidgets);

      await tester.tap(find.text('On').first); // morning mode
      await tester.pump();
      await tester.tap(find.text('High')); // spice bias -> low
      await tester.pump();

      expect(find.text('Off'), findsOneWidget);
      expect(find.text('Mild'), findsOneWidget);
    });

    testWidgets('a granted location is written with its place name',
        (tester) async {
      await pumpWizard(tester);
      await completeNameStep(tester);
      await completeTasteStep(tester);
      await tester.tap(primaryButton('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Where are you eating?'), findsOneWidget);

      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();
      expect(find.text('Peserai, Batu Pahat'), findsOneWidget);

      await tester.tap(primaryButton('Finish'));
      await tester.pumpAndSettle();

      expect(onboarding.sentParams, isNotNull);
      expect(onboarding.sentParams!['p_location_source'], 'gps');
      expect(onboarding.sentParams!['p_latitude'], 1.9);
      expect(onboarding.sentParams!['p_place_name'], 'Peserai, Batu Pahat');
      expect(onboarding.sentParams!['p_name'], 'Aisyah');
      expect(onboarding.sentParams!['p_cuisine_ids'], [1]);
      expect(auth.needsOnboarding, isFalse);
    });

    testWidgets('a fallback fix counts as no location, not a real one',
        (tester) async {
      // The fallback is a hardcoded Batu Pahat coordinate. Storing it would
      // tell the ranking the user is somewhere they have never been.
      await pumpWizard(tester, resolvePosition: () async => fallbackUserPosition());
      await completeNameStep(tester);
      await completeTasteStep(tester);
      await tester.tap(primaryButton('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Location is off'), findsOneWidget);
      // Wait the snack bar out — it sits over the primary button.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(primaryButton('Finish'));
      await tester.pumpAndSettle();

      expect(onboarding.sentParams!['p_location_source'], 'denied');
      expect(onboarding.sentParams!['p_latitude'], isNull);
    });

    testWidgets('"Not now" records denied and finishes the wizard',
        (tester) async {
      await pumpWizard(tester);
      await completeNameStep(tester);
      await completeTasteStep(tester);
      await tester.tap(primaryButton('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(onboarding.completeCalls, 1);
      expect(onboarding.sentParams!['p_location_source'], 'denied');
      expect(auth.needsOnboarding, isFalse);
    });

    testWidgets('a failed write keeps the user in the wizard', (tester) async {
      onboarding.failComplete = true;
      await pumpWizard(tester);
      await completeNameStep(tester);
      await completeTasteStep(tester);
      await tester.tap(primaryButton('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text('Could not save your setup. Please try again.'),
          findsOneWidget);
      expect(auth.needsOnboarding, isTrue,
          reason: 'the gate must not open on a failed write');
      expect(find.text('Where are you eating?'), findsOneWidget);
    });

    testWidgets('going back keeps the answers already given', (tester) async {
      await pumpWizard(tester);
      await completeNameStep(tester);
      await completeTasteStep(tester);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('What do you like to eat?'), findsOneWidget);
      expect(isEnabled(tester, primaryButton('Continue')), isTrue,
          reason: 'the cuisine picked before Back is still selected');
    });

    testWidgets('an unreachable catalog offers a retry', (tester) async {
      onboarding.failCatalog = true;
      await pumpWizard(tester);

      expect(find.textContaining('Could not load the taste list'),
          findsOneWidget);

      onboarding.failCatalog = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('What should we call you?'), findsOneWidget);
    });
  });
}
