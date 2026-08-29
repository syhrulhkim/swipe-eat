import 'package:flutter/material.dart';

import 'app_buttons.dart';
import 'app_spacing.dart';
import 'design_tokens.dart';

/// The shape every "nothing here" screen takes: an optional piece of art, an
/// eyebrow, a display-face line, one sentence of explanation, and at most one
/// action.
///
/// Centralised because the deck, the Likes tab and the Quiz tab all need one,
/// and three hand-rolled versions drift into three different silences.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.art,
  });

  final String eyebrow;
  final String title;
  final String message;

  /// The one way out of the state. Both must be set for a button to appear —
  /// a label with nothing behind it is worse than no button.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Sits above the text. Left null the state is type-only.
  final Widget? art;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final action = onAction;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.cardMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (art != null) ...[
                art!,
                const SizedBox(height: AppSpacing.md),
              ],
              AppEyebrow(label: eyebrow),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: appTitleStyle(context),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: kTextOnPhotoMuted,
                      height: 1.35,
                    ),
              ),
              if (label != null && action != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppPrimaryButton(label: label, onPressed: action),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
