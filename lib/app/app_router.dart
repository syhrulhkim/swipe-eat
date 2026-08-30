import 'package:go_router/go_router.dart';

import '../core/observability/crash_reporting.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/dashboard/presentation/cuisine_restaurants_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/restaurants/models/cuisine_count.dart';
import '../features/restaurants/models/restaurant_detail_data.dart';
import '../features/restaurants/presentation/restaurant_detail_route.dart';
import '../features/settings/presentation/settings_page.dart';

GoRouter createRouter(AuthController authController) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authController,
    // Route changes become breadcrumbs on a crash report; empty list when no
    // DSN was built in.
    observers: crashReportingObservers(),
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isOnAuthPage = location == '/login' || location == '/register';
      final isOnOnboarding = location == '/onboarding';

      // Session restore is asynchronous, and so is the profile read that
      // decides whether onboarding is owed. Until both land, hold on the
      // splash instead of guessing — guessing means a visible flash of the
      // wrong screen on every cold start.
      if (!authController.isResolved) {
        return location == '/splash' ? null : '/splash';
      }

      if (!authController.isAuthenticated) {
        return isOnAuthPage ? null : '/login';
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
            authController.isAuthenticated ? '/dashboard' : '/login',
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(authController: authController),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            RegisterPage(authController: authController),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) =>
            OnboardingPage(authController: authController),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) =>
            DashboardPage(authController: authController),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            SettingsPage(authController: authController),
      ),
      GoRoute(
        path: '/explore/cuisine/:id',
        builder: (context, state) {
          final extra = state.extra;

          return CuisineRestaurantsPage(
            cuisineId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            // A tap from the grid carries the cuisine with it; a bare link
            // carries only the id, and the page falls back to a generic
            // title.
            cuisine: extra is CuisineCount ? extra : null,
          );
        },
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
