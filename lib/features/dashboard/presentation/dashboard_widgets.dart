import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';

/// The frame every non-deck tab sits in: a title, then the tab's content.
class DashboardTabShell extends StatelessWidget {
  const DashboardTabShell({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                        ),
                  ),
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
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// What a tab shows instead of content: an explanation, and a way out of it
/// when there is one.
class EmptyTabMessage extends StatelessWidget {
  const EmptyTabMessage({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SimpleCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: appPanelTitleStyle(context)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.66),
                    height: 1.35,
                  ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              FButton(
                variant: FButtonVariant.outline,
                onPress: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
