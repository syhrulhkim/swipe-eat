import 'package:go_router/go_router.dart';

import '../core/observability/crash_reporting.dart';
import '../core/ui/page_transitions.dart';
import '../features/auth/presentation/phone_sign_in_page.dart';
import '../features/auth/presentation/sign_up_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/auth/presentation/welcome_page.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/restaurants/models/restaurant_detail_data.dart';
import '../features/restaurants/presentation/restaurant_detail_route.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/wishlist/presentation/wishlist_page.dart';

GoRouter createRouter(AuthController authController) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authController,
    // Route changes become breadcrumbs on a crash report; empty list when no
    // DSN was built in.
    observers: crashReportingObservers(),
    redirect: (context, state) {
      final location = state.matchedLocation;
      // The welcome screen and everything the sign-up screen leads to. A
      // signed-out user is allowed to sit on any of them; every other route
      // funnels back to the welcome screen.
      final isOnAuthPage =
          location == '/welcome' || location.startsWith('/signup');
      final isOnOnboarding = location == '/onboarding';

      // Session restore is asynchronous, and so is the profile read that
      // decides whether onboarding is owed. Until both land, hold on the
      // splash instead of guessing — guessing means a visible flash of the
      // wrong screen on every cold start.
      if (!authController.isResolved) {
        return location == '/splash' ? null : '/splash';
      }

      if (!authController.isAuthenticated) {
        return isOnAuthPage ? null : '/welcome';
      }

      // `onboarded_at` lives in the database, so the wizard is owed per
      // account, not per install — and it is owed before anything else the
      // app can show, because the deck has no taste signal without it.
      if (authController.needsOnboarding) {
        return isOnOnboarding ? null : '/onboarding';
      }

      if (isOnAuthPage ||
          isOnOnboarding ||
          location == '/splash' ||
          location == '/') {
        return '/dashboard';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        redirect: (context, state) =>
            authController.isAuthenticated ? '/dashboard' : '/welcome',
      ),
      // The email pages these two used to serve are gone; the paths stay so an
      // old link, a shortcut or a saved deep link lands on the way in rather
      // than on a 404.
      GoRoute(path: '/login', redirect: (context, state) => '/welcome'),
      GoRoute(path: '/register', redirect: (context, state) => '/welcome'),
      // The five screens below are reached by replacement, not by a push: the
      // redirect above decides which one is owed and swaps it in. They
      // crossfade into each other. The pushed routes further down keep the
      // platform transition, and with it the iOS swipe-back gesture.
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => fadeThroughPage<void>(
          context,
          key: state.pageKey,
          child: const SplashPage(),
        ),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) => fadeThroughPage<void>(
          context,
          key: state.pageKey,
          child: const WelcomePage(),
        ),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) => fadeThroughPage<void>(
          context,
          key: state.pageKey,
          child: SignUpPage(authController: authController),
        ),
      ),
      // Pushed from the sign-up screen, so it keeps the platform transition
      // and the iOS swipe-back gesture.
      GoRoute(
        path: '/signup/phone',
        builder: (context, state) =>
            PhoneSignInPage(authController: authController),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => fadeThroughPage<void>(
          context,
          key: state.pageKey,
          child: OnboardingPage(authController: authController),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) => fadeThroughPage<void>(
          context,
          key: state.pageKey,
          child: DashboardPage(authController: authController),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            SettingsPage(authController: authController),
      ),
      // Pushed from the Bites tab's "Wishlist →" chip, so it keeps the
      // platform transition and the iOS swipe-back gesture.
      GoRoute(
        path: '/wishlist',
        builder: (context, state) => const WishlistPage(),
      ),
      GoRoute(
        path: '/restaurant/:id',
        builder: (context, state) {
          final payload = state.extra;

          return RestaurantDetailRoute(
            restaurantId: int.tryParse(state.pathParameters['id'] ?? ''),
            // A tap from a card carries the whole restaurant with it, so the
            // page opens with no fetch. A link carries only the id.
            initialData: payload is Map<String, dynamic>
                ? RestaurantDetailData.fromPayload(payload)
                : null,
          );
        },
      ),
    ],
  );
}
