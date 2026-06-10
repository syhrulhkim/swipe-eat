import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/dashboard/presentation/dashboard_page.dart';

GoRouter createRouter(AuthController authController) {
  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: authController,
    redirect: (context, state) {
      final isOnAuthPage =
          state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (state.matchedLocation == '/') {
        return authController.isAuthenticated ? '/dashboard' : '/login';
      }

      if (!authController.isAuthenticated && !isOnAuthPage) {
        return '/login';
      }

      if (authController.isAuthenticated && isOnAuthPage) {
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
        path: '/login',
        builder: (context, state) => LoginPage(authController: authController),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            RegisterPage(authController: authController),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) =>
            DashboardPage(authController: authController),
      ),
    ],
  );
}
