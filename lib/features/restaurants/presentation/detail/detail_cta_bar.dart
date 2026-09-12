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
              child: _PlanButton(busy: busy, onPressed: onSetDate),
            ),
          ],
        ),
      ),
    );
  }
}

/// The design's two-line primary: what the button does, and the three answers
/// the screen behind it will take.
///
/// Hand-built rather than an [AppPrimaryButton] with a longer label: the
/// shared pill draws one line and ellipsizes, and the second line here is a
/// quieter size and weight than the first.
class _PlanButton extends StatelessWidget {
  const _PlanButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kRadiusPill),
    );

    return Opacity(
      opacity: busy ? 0.45 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: kCtaGradient,
          borderRadius: BorderRadius.circular(kRadiusPill),
        ),
        child: Material(
          color: Colors.transparent,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: busy ? null : onPressed,
            child: Container(
              constraints:
                  const BoxConstraints(minHeight: kPillButtonHeight),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              alignment: Alignment.center,
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kOnAccent,
                      ),
                    )
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Plan a visit',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: kTextFontFamily,
                            fontSize: kFontSizeBody,
                            fontWeight: FontWeight.w600,
                            color: kOnAccent,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'tonight, this weekend, or pick a day',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: kTextFontFamily,
                            fontSize: kFontSizeMicro,
                            fontWeight: FontWeight.w500,
                            color: Color(0xCC140A05),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
