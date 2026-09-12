import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'design_tokens.dart';

/// The three motion marks the app owns, all hand-authored and bundled.
///
/// Deliberately abstract: a spinner, a heart and a location pulse. Anything
/// illustrative would date faster than the rest of the design and cost far
/// more bytes than the few KB these take.
enum AppMotion {
  /// Ember arc chasing its own tail — the busy state.
  spinner('assets/lottie/spinner.json', Icons.hourglass_empty_rounded),

  /// A heart breathing in and out — the Likes tab with nothing in it.
  heart('assets/lottie/heart_pop.json', Icons.favorite_rounded),

  /// A cream dot under two expanding rings — anything about location.
  pin('assets/lottie/pin_pulse.json', Icons.my_location_rounded);

  const AppMotion(this.asset, this.fallbackIcon);

  final String asset;

  /// Drawn instead of the animation if the file is missing or unreadable. A
  /// blank hole where the art was is worse than a plain icon.
  final IconData fallbackIcon;
}

/// One of the [AppMotion] loops at a fixed square size.
class AppLottie extends StatelessWidget {
  const AppLottie({
    super.key,
    required this.motion,
    this.size = 96,
    this.repeat = true,
  });

  final AppMotion motion;
  final double size;

  /// False plays the loop once and holds the last frame — for a mark that
  /// should land rather than keep moving.
  final bool repeat;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        motion.asset,
        repeat: repeat,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Lottie ${motion.asset} failed: $error');
          return Icon(
            motion.fallbackIcon,
            size: size * 0.5,
            color: kTextOnPhotoMuted,
          );
        },
      ),
    );
  }
}
