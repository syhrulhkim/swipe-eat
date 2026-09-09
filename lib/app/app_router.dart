import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/observability/crash_reporting.dart';
import '../core/ui/design_tokens.dart';
import '../core/ui/page_transitions.dart';
import '../features/auth/presentation/phone_sign_in_page.dart';
import '../features/auth/presentation/sign_up_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/auth/presentation/welcome_page.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/dashboard/state/dashboard_tab_request.dart';
import '../features/friends/presentation/friends_page.dart';
import '../features/friends/presentation/invite_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/plans/presentation/plan_date_page.dart';
import '../features/plans/presentation/plan_page.dart';
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
      // Pushed from the You tab's other ghost button. Nothing is passed: the
      // page reads the one shared friends cache the whole app reads.
      GoRoute(
        path: '/friends',
        builder: (context, state) => const FriendsPage(),
      ),
      // Pushed from the Bites tab's "Wishlist →" chip, so it keeps the
      // platform transition and the iOS swipe-back gesture.
      GoRoute(
        path: '/wishlist',
        builder: (context, state) => const WishlistPage(),
      ),
      // Pushed from a restaurant's "Set a date". The payload is parsed the
      // same defensive way `/restaurant/:id` parses its own: a link, or a
      // caller that has less than the tap had, gets a screen rather than a
      // crash.
      GoRoute(
        path: '/plans/new',
        builder: (context, state) {
          final draft = PlanDraft.fromPayload(state.extra);
          if (draft == null) {
            return const _PlanDraftMissingPage();
          }

          return PlanDatePage(
            draft: draft,
            onCreated: (context, planId, withFriends) {
              // The plan is saved by the time this runs, so the calendar is
              // where the screen belongs whatever happens next. Going there
              // first also means the invite screen has somewhere to pop back
              // to — Skip and Send both land on the plan they just made.
              context.go('/dashboard');
              DashboardTabRequest.instance.show(3);
              if (withFriends) {
                context.push('/plans/$planId/invite');
              }
            },
          );
        },
      ),
      // Pushed from a card on the Calendar. The id is parsed the same
      // defensive way `/restaurant/:id` parses its own.
      GoRoute(
        path: '/plans/:id',
        builder: (context, state) {
          final planId = int.tryParse(state.pathParameters['id'] ?? '');
          if (planId == null) {
            return const _PlanDraftMissingPage();
          }
          return PlanPage(planId: planId);
        },
      ),
      // Pushed from `/plans/new` when "Bring friends" was left on, and
      // reachable on its own from a plan. The id is parsed the same defensive
      // way `/restaurant/:id` parses its own.
      GoRoute(
        path: '/plans/:id/invite',
        builder: (context, state) {
          final planId = int.tryParse(state.pathParameters['id'] ?? '');
          if (planId == null) {
            return const _PlanDraftMissingPage();
          }
          return InvitePage(planId: planId);
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

/// What `/plans/new` shows when it was opened without a restaurant. Reachable
/// only from a hand-written link or a restored route; the app's own push
/// always carries the payload.
class _PlanDraftMissingPage extends StatelessWidget {
  const _PlanDraftMissingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Pick a place first, then a day.',
            textAlign: TextAlign.center,
            style: appPanelTitleStyle(context),
          ),
        ),
      ),
    );
  }
}
