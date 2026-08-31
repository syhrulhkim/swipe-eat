import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_tokens.dart';

/// Height of every bar button, so a row of them lines up without each call
/// site guessing at padding.
const double kPillButtonHeight = 46;

/// The one primary action on a screen: a cream bar with dark ink.
///
/// Deliberately loud, and deliberately rare — the design leans on exactly one
/// of these per screen (Continue, Get directions, Reload deck). Everything
/// else is an [AppSecondaryButton].
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.busy = false,
  });

  final String label;

  /// Null disables the button, which is how a form reports "not yet valid"
  /// rather than failing on tap.
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Whether the button fills the width it is given. Left false the button is
  /// only as wide as its label, which is what an action row wants.
  final bool expand;

  /// Swaps the label for a spinner and stops taps. The button keeps its width so
  /// the row does not jump while a request is in flight.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return _PillButton(
      label: label,
      icon: icon,
      expand: expand,
      busy: busy,
      onPressed: onPressed,
      background: kAccentCream,
      foreground: kOnAccent,
      border: null,
    );
  }
}

/// A secondary action: dark bar, hairline border, white label.
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.busy = false,
    this.tint,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool busy;

  /// Colours the label and icon. Null leaves them white; pass [kAccentEmber]
  /// for the one secondary action that is also a state change (Retry, Undo).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return _PillButton(
      label: label,
      icon: icon,
      expand: expand,
      busy: busy,
      onPressed: onPressed,
      background: kSurfacePanel,
      foreground: tint ?? kTextOnPhoto,
      border: kHairline,
    );
  }
}

/// Shared body of both buttons. Private: the two public wrappers above are the
/// vocabulary, and a third fill would mean a third meaning nobody defined.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.expand,
    required this.busy,
    required this.onPressed,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final String label;
  final IconData? icon;
  final bool expand;
  final bool busy;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kRadiusPill),
      side: border == null ? BorderSide.none : BorderSide(color: border!),
    );

    final content = busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          );

    return Opacity(
      // Disabled reads as dimmed rather than as a different fill, so the button
      // keeps its identity while it waits for a valid form.
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: background,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                }
              : null,
          child: Container(
            height: kPillButtonHeight,
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }
}

/// The small warm label above a title — "CRISPY", "OPEN NOW", "OFFLINE".
class AppEyebrow extends StatelessWidget {
  const AppEyebrow({super.key, required this.label, this.color = kAccentEmber});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: appEyebrowStyle(context, color: color),
    );
  }
}

/// One column of an [AppStatStrip].
class AppStat {
  const AppStat({required this.label, required this.value});

  /// The quiet line on top ("Distance", "Rating").
  final String label;

  /// The answer under it ("1.2 km", "4.3").
  final String value;
}

/// A row of small label/value columns separated by hairlines — the strip of
/// facts under a title on the detail page.
///
/// Columns share the width evenly, so two stats read as balanced and four
/// still fit on a narrow phone.
class AppStatStrip extends StatelessWidget {
  const AppStatStrip({super.key, required this.stats});

  final List<AppStat> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 30,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: kHairline,
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: kTextOnPhotoMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stats[i].value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: kTextOnPhoto,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
