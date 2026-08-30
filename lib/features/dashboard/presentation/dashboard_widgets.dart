import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';

/// The frame every non-deck tab sits in: the same eyebrow-over-title header
/// the deck and the detail page use, then the tab's content.
class DashboardTabShell extends StatelessWidget {
  const DashboardTabShell({
    super.key,
    required this.title,
    required this.child,
    this.eyebrow,
  });

  final String title;

  /// The warm line above the title. Optional only so a tab can opt out; every
  /// tab that has something to say about itself should say it here.
  final String? eyebrow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final eyebrowLabel = eyebrow;

    return DecoratedBox(
      decoration: const BoxDecoration(color: kBackgroundDark),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                18,
                AppSpacing.screenPadding,
                12,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrowLabel != null) ...[
                      AppEyebrow(label: eyebrowLabel),
                      const SizedBox(height: 8),
                    ],
                    Text(title, style: appTitleStyle(context)),
                  ],
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// A plain panel: the flat cousin of [AppPanel], for content that sits on
/// the dark background rather than over a photo.
class SimpleCard extends StatelessWidget {
  const SimpleCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusPanel),
      child: Container(
        decoration: BoxDecoration(
          color: kSurfacePanel,
          borderRadius: BorderRadius.circular(kRadiusPanel),
          border: Border.all(color: kHairline),
        ),
        child: child,
      ),
    );
  }
}

/// What a tab shows instead of content: an explanation, and a way out of it
/// when there is one.
///
/// A card rather than the full-screen [AppEmptyState] because this one sits in
/// a tab that still has a header and, often, content above it.
class EmptyTabMessage extends StatelessWidget {
  const EmptyTabMessage({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;

  /// Names the state ("NOTHING NEARBY", "OFFLINE") above the sentence that
  /// explains it.
  final String? eyebrow;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final eyebrowLabel = eyebrow;

    return SimpleCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrowLabel != null) ...[
              AppEyebrow(label: eyebrowLabel),
              const SizedBox(height: 6),
            ],
            Text(title, style: appPanelTitleStyle(context)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: kTextOnPhotoMuted,
                    height: 1.35,
                  ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: AppSecondaryButton(
                  label: actionLabel!,
                  onPressed: onAction,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
