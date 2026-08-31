import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// How long a screen takes to arrive. Deliberately the same order as the
/// bottom bar's own 220 ms `easeOutCubic`, so a screen change reads as the
/// same piece of motion as a tap, not as an effect of its own.
const Duration kScreenFadeDuration = Duration(milliseconds: 240);

/// The app's one screen-change curve.
const Curve kScreenFadeCurve = Curves.easeOutCubic;

/// Zero when the platform is set to reduce motion, so the crossfade becomes an
/// instant cut rather than a slower one.
Duration _duration(BuildContext context) {
  final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return disabled ? Duration.zero : kScreenFadeDuration;
}

/// A go_router page that crossfades in over whatever it replaces.
///
/// For the screens the redirect swaps between — splash, login, register,
/// onboarding, dashboard. A platform push animation is wrong for those: they
/// are not pushed, they replace each other, and sliding the splash away
/// sideways reads as the user having navigated when they did not.
///
/// Pushed screens (a restaurant, a cuisine list, settings) deliberately keep
/// the platform default, which on iOS is what carries the interactive
/// swipe-back gesture.
CustomTransitionPage<T> fadeThroughPage<T>(
  BuildContext context, {
  required LocalKey key,
  required Widget child,
}) {
  final duration = _duration(context);

  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: kScreenFadeCurve),
        child: child,
      );
    },
  );
}

/// The imperative form of [fadeThroughPage], for a `Navigator.push` that opens
/// a screen edge to edge — the fullscreen video player. Slide-from-the-right
/// suits a page you can go back through; a takeover suits a fade.
Route<T> fadeThroughRoute<T>(BuildContext context, WidgetBuilder builder) {
  final duration = _duration(context);

  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: kScreenFadeCurve),
        child: child,
      );
    },
  );
}
