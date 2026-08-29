import 'package:flutter/material.dart';

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
            Text(
              'Swipe Eat',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: kTextOnPhoto,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: kTextOnPhotoSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
