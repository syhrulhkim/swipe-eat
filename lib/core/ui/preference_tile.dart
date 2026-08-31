import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Opaque panel with a tinted hairline border — the card behind every
/// preference tile.
class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.accent,
  });

  final Widget child;

  /// Tints the border. Null falls back to the neutral white hairline used by
  /// non-preference cards.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final border = accent ?? Colors.white;
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusPanel),
      child: Container(
        decoration: BoxDecoration(
          color: kSurfacePanel,
          borderRadius: BorderRadius.circular(kRadiusPanel),
          border: Border.all(
            color: border.withValues(alpha: accent == null ? 0.08 : 0.18),
          ),
        ),
        // The panel paints its own background, so anything interactive inside
        // needs a Material of its own or its ink splash lands behind this box
        // and is never seen.
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

/// One row of the "how you eat" settings — morning mode, spice bias, nearby
/// focus.
///
/// Lives in `core/ui` rather than the dashboard because the onboarding wizard
/// and the Profile tab show the same three tiles and must not drift apart.
/// Passing [onTap] turns the trailing label into a control; leaving it null
/// renders the read-only form.
class PreferenceTile extends StatelessWidget {
  const PreferenceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.tint,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailingLabel;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final interactive = onTap != null;

    return AppPanel(
      accent: tint,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(kRadiusPill),
          ),
          child: Icon(icon, color: tint),
        ),
        title: Text(title, style: appPanelTitleStyle(context)),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.66),
              ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: interactive
                ? tint.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(kRadiusPill),
          ),
          child: Text(
            trailingLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: interactive ? tint : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}
