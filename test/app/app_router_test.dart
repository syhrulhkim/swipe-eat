import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:swipe_eat/app/app_router.dart';
import 'package:swipe_eat/features/auth/presentation/login_page.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/auth/presentation/splash_page.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/onboarding/presentation/onboarding_page.dart';

import '../features/auth/fake_auth_repository.dart';

void main() {
  group('router auth gate', () {
    late FakeAuthRepository repository;
    late AuthController controller;

    setUp(() {
    // The auth controller caches the profile on the device; without a fake
    // store behind it every resolve logs a missing-plugin failure.
    SharedPreferences.setMockInitialValues(<String, Object>{});
      repository = FakeAuthRepository();
      controller = AuthController(repository);
    });

    tearDown(() async {
      controller.dispose();
      await repository.dispose();
    });

    /// Mirrors `SwipeEatApp`'s builder: the pages mix Material fields into
    /// forui scaffolds, so both ancestors have to be present or the login
    /// page cannot build.
    Future<GoRouter> pumpApp(WidgetTester tester, {String? deepLink}) async {
      final router = createRouter(controller);
      if (deepLink != null) {
        router.go(deepLink);
      }

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          supportedLocales: FLocalizations.supportedLocales,
          localizationsDelegates: FLocalizations.localizationsDelegates,
          builder: (_, child) => Material(
            type: MaterialType.transparency,
            child: FTheme(
              data: FThemes.neutral.dark.touch,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      );
      return router;
    }

    testWidgets('holds on the splash while the session is unresolved',
        (tester) async {
      await pumpApp(tester);
      await tester.pump();

      expect(find.byType(SplashPage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing,
          reason: 'showing login before resolving would flash on every launch');
    });

    testWidgets('lands on login once resolved without a session',
        (tester) async {
      await pumpApp(tester);
      await controller.bootstrap();
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(SplashPage), findsNothing);
    });

    testWidgets('an unauthenticated deep link is sent to login',
        (tester) async {
      await controller.bootstrap();
      await pumpApp(tester, deepLink: '/settings');
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('a signed-in account that owes onboarding lands on the wizard',
        (tester) async {
      repository
        ..sessionPresent = true
        ..profile = _user();
      await controller.bootstrap();

      // `onboarded_at` is null, so the deck has no taste signal yet: every
      // route funnels through the wizard until it is set.
      await pumpApp(tester, deepLink: '/dashboard');
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingPage), findsOneWidget);
    });

    testWidgets('completing onboarding releases the gate', (tester) async {
      repository
        ..sessionPresent = true
        ..profile = _user();
      await controller.bootstrap();
      final router = await pumpApp(tester);
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsOneWidget);

      controller.markOnboarded(DateTime(2026, 8, 23));
      // Not pumpAndSettle: the dashboard behind the gate spins forever here,
      // because its repositories have no initialised Supabase to answer them.
      // Two timed pumps carry the page transition to completion instead.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(OnboardingPage), findsNothing);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/dashboard');
    });

    testWidgets('the wizard is not reachable without a session',
        (tester) async {
      await controller.bootstrap();
      await pumpApp(tester, deepLink: '/onboarding');
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(OnboardingPage), findsNothing);
    });
  });
}

AppUser _user({DateTime? onboardedAt}) => AppUser(
      id: '39c39a30-c8fb-4e08-8e13-c90212f68e59',
      name: 'Demo User',
      email: 'demo@swipeeat.test',
      onboardedAt: onboardedAt,
    );
