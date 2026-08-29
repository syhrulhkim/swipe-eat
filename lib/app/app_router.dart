import 'package:go_router/go_router.dart';

import '../core/ui/glass_ui.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/restaurants/models/restaurant_detail_data.dart';
import '../features/restaurants/presentation/restaurant_detail_page.dart';
import '../features/settings/presentation/settings_page.dart';

GoRouter createRouter(AuthController authController) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authController,
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
        path: '/restaurant',
        builder: (context, state) {
          final payload = state.extra;
          final data = payload is Map<String, dynamic>
              ? RestaurantDetailData.fromPayload(payload)
              : const RestaurantDetailData(
                  id: 0,
                  title: 'Restaurant',
                  tag: '',
                  details: '',
                  color: kSurfacePanel,
                  rating: 0,
                  latitude: 0,
                  longitude: 0,
                  reviewName: '',
                  reviewText: '',
                  imageUrls: [],
                );

          return RestaurantDetailPage(data: data);
        },
      ),
    ],
  );
}
