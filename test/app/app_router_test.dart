import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:swipe_eat/app/app_router.dart';
import 'package:swipe_eat/features/auth/presentation/welcome_page.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/auth/presentation/splash_page.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/friends/presentation/friends_page.dart';
import 'package:swipe_eat/features/friends/presentation/invite_page.dart';
import 'package:swipe_eat/features/friends/state/friends_controller.dart';
import 'package:swipe_eat/features/onboarding/presentation/onboarding_page.dart';
import 'package:swipe_eat/features/plans/presentation/plan_date_page.dart';
import 'package:swipe_eat/features/plans/presentation/plan_page.dart';
import 'package:swipe_eat/features/plans/state/plans_controller.dart';

import '../features/auth/fake_auth_repository.dart';
import '../features/friends/fake_friends_repository.dart';
import '../features/plans/fake_plans_repository.dart';

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
    Future<GoRouter> pumpApp(
      WidgetTester tester, {
      String? deepLink,
      Object? extra,
    }) async {
      final router = createRouter(controller);
      if (deepLink != null) {
        router.go(deepLink, extra: extra);
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
      expect(find.byType(WelcomePage), findsNothing,
          reason: 'showing the welcome screen before resolving would flash '
              'on every launch');
    });

    testWidgets('lands on the welcome screen once resolved without a session',
        (tester) async {
      await pumpApp(tester);
      await controller.bootstrap();
      await tester.pumpAndSettle();

      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.byType(SplashPage), findsNothing);
    });

    testWidgets('an unauthenticated deep link is sent to the welcome screen',
        (tester) async {
      await controller.bootstrap();
      await pumpApp(tester, deepLink: '/settings');
      await tester.pumpAndSettle();

      expect(find.byType(WelcomePage), findsOneWidget);
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

      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.byType(OnboardingPage), findsNothing);
    });
  });

  group('the invite route', () {
    late FakeAuthRepository repository;
    late AuthController controller;
    late FakePlansRepository plansRepository;
    late FakeFriendsRepository friendsRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      repository = FakeAuthRepository()
        ..sessionPresent = true
        ..profile = _user(onboardedAt: DateTime(2026, 8, 23));
      controller = AuthController(repository);
      await controller.bootstrap();

      // One plan on the calendar, so `/plans/:id` has something to draw and
      // is not tested against its own empty state.
      plansRepository = FakePlansRepository(
        rows: [testPlan(77, date: DateTime(2026, 9, 4))],
      );
      PlansController.debugSetInstance(
        PlansController(
          repository: plansRepository,
          clock: () => DateTime(2026, 9, 6, 19, 41),
          followAuthChanges: false,
        ),
      );
      friendsRepository = FakeFriendsRepository(
        friends: [testFriend('u1', name: 'Aiman Zulkifli')],
      );
      FriendsController.debugSetInstance(
        FriendsController(
          repository: friendsRepository,
          followAuthChanges: false,
        ),
      );
    });

    tearDown(() async {
      controller.dispose();
      await repository.dispose();
    });

    Future<GoRouter> pumpApp(
      WidgetTester tester, {
      String? deepLink,
      Object? extra,
    }) async {
      final router = createRouter(controller);
      if (deepLink != null) {
        router.go(deepLink, extra: extra);
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

    testWidgets('a plan id opens the invite screen', (tester) async {
      await pumpApp(tester, deepLink: '/plans/77/invite');
      await tester.pumpAndSettle();

      expect(find.byType(InvitePage), findsOneWidget);
      expect(find.text("Who's hungry?"), findsOneWidget);
    });

    testWidgets('an id that is not a number gets a screen, not a crash',
        (tester) async {
      await pumpApp(tester, deepLink: '/plans/not-a-plan/invite');
      await tester.pumpAndSettle();

      expect(find.byType(InvitePage), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a plan id on its own opens the plan', (tester) async {
      await pumpApp(tester, deepLink: '/plans/77');
      await tester.pumpAndSettle();

      expect(find.byType(PlanPage), findsOneWidget);
      expect(find.text('When are we going?'), findsOneWidget);
    });

    testWidgets('"new" is still the pick-a-date screen, not a plan id',
        (tester) async {
      // `/plans/new` is declared above `/plans/:id`, and go_router takes the
      // first match — so the order in the route table is load-bearing.
      await pumpApp(tester, deepLink: '/plans/new');
      await tester.pumpAndSettle();

      expect(find.byType(PlanPage), findsNothing);
    });

    testWidgets('a plan id that is not a number gets a screen, not a crash',
        (tester) async {
      await pumpApp(tester, deepLink: '/plans/not-a-plan');
      await tester.pumpAndSettle();

      expect(find.byType(PlanPage), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('locking in with friends on lands on the invite screen',
        (tester) async {
      // The whole chain the router owns: the plan is created, the screen goes
      // to the calendar, and the invite screen is pushed on top of it — in
      // that order, so Skip pops back onto the plan that was just made rather
      // than onto the date picker.
      final router = await pumpApp(
        tester,
        deepLink: '/plans/new',
        extra: const {
          'restaurantId': 306,
          'title': 'Warung Kak Ros',
          'neighbourhood': 'Kepong',
          'tag': 'Nasi lemak',
        },
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlanDatePage), findsOneWidget);

      // "Bring friends" starts on, so a day is the only thing missing.
      await tester.tap(find.text('12'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lock it in'));
      // Not pumpAndSettle: the dashboard underneath spins forever without an
      // initialised Supabase behind its repositories.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(plansRepository.created, hasLength(1));
      expect(find.byType(InvitePage), findsOneWidget);

      // And Skip puts the user behind it, not back on the date picker. This
      // is the assertion the whole ordering exists for: `go` to the calendar
      // first, `push` the invite screen second.
      await tester.tap(find.text('Skip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(InvitePage), findsNothing);
      expect(find.byType(PlanDatePage), findsNothing);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/dashboard');
    });

    testWidgets('the You tab\'s other ghost button has a page behind it',
        (tester) async {
      await pumpApp(tester, deepLink: '/friends');
      await tester.pumpAndSettle();

      expect(find.byType(FriendsPage), findsOneWidget);
      expect(find.text('Aiman Zulkifli'), findsOneWidget);
    });
  });

  group('a tapped notification', () {
    late FakeAuthRepository repository;
    late AuthController controller;
    late ValueNotifier<String?> pushRoute;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      repository = FakeAuthRepository()
        ..sessionPresent = true
        ..profile = _user(onboardedAt: DateTime(2026, 8, 23));
      controller = AuthController(repository);
      pushRoute = ValueNotifier<String?>(null);

      PlansController.debugSetInstance(
        PlansController(
          repository: FakePlansRepository(
            rows: [testPlan(77, date: DateTime(2026, 9, 4))],
          ),
          clock: () => DateTime(2026, 9, 6, 19, 41),
          followAuthChanges: false,
        ),
      );
      FriendsController.debugSetInstance(
        FriendsController(
          repository: FakeFriendsRepository(),
          followAuthChanges: false,
        ),
      );
    });

    tearDown(() async {
      pushRoute.dispose();
      controller.dispose();
      await repository.dispose();
    });

    Future<GoRouter> pumpApp(WidgetTester tester) async {
      final router = createRouter(controller, pushRoute: pushRoute);
      addTearDown(router.dispose);
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

    testWidgets('opens the plan it names, and is spent doing it',
        (tester) async {
      await controller.bootstrap();
      final router = await pumpApp(tester);
      // Never settled: the dashboard this lands on spins a looping mark, so
      // the frames are pumped by hand — the same rule the invite chain above
      // follows.
      await _settleRoute(tester);

      pushRoute.value = '/plans/77';
      await _settleRoute(tester);

      expect(find.byType(PlanPage), findsOneWidget);
      // Consumed, or the next refresh would drag the user back here from
      // wherever they had walked to.
      expect(pushRoute.value, isNull);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/plans/77');
    });

    testWidgets('waits on the splash until the session has resolved',
        (tester) async {
      // A cold start is the common case: the notification is tapped, the app
      // launches, and the route arrives before anybody is signed in. Honoured
      // there it would open a plan screen nothing could read.
      pushRoute.value = '/plans/77';
      await pumpApp(tester);
      await tester.pump();

      expect(find.byType(SplashPage), findsOneWidget);
      expect(pushRoute.value, '/plans/77');

      await controller.bootstrap();
      await _settleRoute(tester);

      expect(find.byType(PlanPage), findsOneWidget);
      expect(pushRoute.value, isNull);
    });

    testWidgets('leaves a Back that goes to the calendar, not nowhere',
        (tester) async {
      // The redirect *replaces* the stack rather than pushing onto it, so a
      // plan opened from a notification has nothing behind it and a plain pop
      // would strand the user on it.
      await controller.bootstrap();
      final router = await pumpApp(tester);
      await _settleRoute(tester);

      pushRoute.value = '/plans/77';
      await _settleRoute(tester);
      expect(find.byType(PlanPage), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      await _settleRoute(tester);

      expect(router.routerDelegate.currentConfiguration.uri.path, '/dashboard');
    });

    testWidgets('a build with no push at all routes exactly as before',
        (tester) async {
      // `createRouter` is called without the notifier on any build made
      // without the Firebase defines, and that path must stay the one the
      // rest of this file tests.
      await controller.bootstrap();
      final router = createRouter(controller);
      addTearDown(router.dispose);
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
      await _settleRoute(tester);

      expect(router.routerDelegate.currentConfiguration.uri.path, '/dashboard');
    });
  });
}

/// Two frames and the crossfade, instead of `pumpAndSettle`: every route these
/// tests land on can have a looping mark on it, and a settle would wait for a
/// loop that never ends.
Future<void> _settleRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

AppUser _user({DateTime? onboardedAt}) => AppUser(
      id: '39c39a30-c8fb-4e08-8e13-c90212f68e59',
      name: 'Demo User',
      email: 'demo@swipeeat.test',
      onboardedAt: onboardedAt,
    );