import 'package:flutter/material.dart';

import '../../../../core/ui/app_buttons.dart';
import '../../../../core/ui/app_spacing.dart';
import '../../../../core/ui/design_tokens.dart';

/// The design's `.cta`: a ghost square for directions and the one gradient
/// button on the screen.
///
/// Pinned under the scroll view rather than inside it — this is the whole
/// reason the screen exists, and a CTA you have to scroll to is a CTA that
/// gets missed.
class DetailCtaBar extends StatelessWidget {
  const DetailCtaBar({
    super.key,
    required this.onSetDate,
    required this.onDirections,
    this.busy = false,
  });

  final VoidCallback onSetDate;

  /// Null when the restaurant has no coordinates: a route to the 0,0 sentinel
  /// is not a route. The button is hidden rather than disabled, because a dead
  /// control still asks to be pressed.
  final VoidCallback? onDirections;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final onDirections = this.onDirections;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, 22),
        child: Row(
          children: [
            if (onDirections != null) ...[
              // `.btn-ghost` at the bar's own height, so the square and the
              // gradient line up without either guessing at the other.
              AppIconButton(
                icon: Icons.near_me_rounded,
                size: kPillButtonHeight,
                iconSize: 20,
                onPhoto: false,
                semanticLabel: 'Directions',
                onTap: onDirections,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: AppPrimaryButton(
                label: 'Set a date',
                expand: true,
                busy: busy,
                onPressed: onSetDate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
