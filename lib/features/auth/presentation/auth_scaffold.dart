import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';

/// The shell both auth screens sit in: near-black canvas, an eyebrow over a
/// large display title, then the form.
///
/// Sign-in and sign-up used to be forui `FScaffold`/`FCard`, which read
/// forui's own theme rather than the app's — they rendered in a different font
/// on different neutrals than every screen behind them. The card is gone
/// entirely: on a phone a bordered box inside a dark screen only draws a frame
/// around the full width it already had.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppSpacing.cardMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppEyebrow(label: eyebrow),
                  const SizedBox(height: 10),
                  Text(title, style: appTitleStyle(context)),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: kTextOnPhotoMuted,
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
