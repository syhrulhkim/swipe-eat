import 'package:flutter/material.dart';

import '../../../core/ui/app_lottie.dart';
import '../../../core/ui/design_tokens.dart';

/// Shown while the persisted session and its profile are being restored.
///
/// Without this hold the router would have to guess: a cold start knows there
/// is a session before it knows whether onboarding is owed, so it would flash
/// the wrong screen for a frame or two on every launch.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The pulse doubles as the wait indicator: the app is about to
            // rank restaurants around wherever the user is standing, and a
            // bare spinner says nothing about that.
            const AppLottie(motion: AppMotion.pin, size: 110),
            const SizedBox(height: 18),
            Text(
              'Swipe Eat',
              style: appTitleStyle(context),
            ),
            const SizedBox(height: 6),
            Text(
              'Finding your table',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: kTextOnPhotoMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
