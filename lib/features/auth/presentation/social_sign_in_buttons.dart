import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../state/auth_controller.dart';

/// Google and Apple sign-in, shared by the login and register pages.
///
/// Each button renders only when its provider is actually usable: Google
/// needs client ids supplied at build time (`--dart-define`), Apple needs an
/// Apple platform. When neither qualifies the whole block — divider included —
/// collapses, so an unconfigured build shows a clean email-only form rather
/// than buttons that fail on tap.
class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({
    super.key,
    required this.authController,
    required this.onError,
  });

  final AuthController authController;
  final void Function(String message) onError;

  @override
  Widget build(BuildContext context) {
    final showGoogle = authController.supportsGoogleSignIn;
    final showApple = authController.supportsAppleSignIn;
    if (!showGoogle && !showApple) {
      return const SizedBox.shrink();
    }

    final busy = authController.isBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                'or',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (showGoogle)
          AppSecondaryButton(
            label: 'Continue with Google',
            expand: true,
            onPressed: busy ? null : () => _run(authController.signInWithGoogle),
          ),
        if (showGoogle && showApple) const SizedBox(height: AppSpacing.sm),
        if (showApple)
          AppSecondaryButton(
            label: 'Continue with Apple',
            expand: true,
            onPressed: busy ? null : () => _run(authController.signInWithApple),
          ),
      ],
    );
  }

  Future<void> _run(Future<bool> Function() action) async {
    final ok = await action();
    if (!ok) {
      onError(authController.errorMessage ?? 'Sign-in failed.');
    }
    // On success the router redirect takes over.
  }
}
