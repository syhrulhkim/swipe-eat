import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/design_tokens.dart';
import '../domain/nearby_format.dart';

/// How far out the map is looking, and the two taps that change it.
///
/// Minus is a dark disc and plus is an ember one, because only one of the two
/// grows the answer — the app's rule is that orange marks what acts, and the
/// asymmetry is the control telling you which way is "more".
class NearbyRadiusStepper extends StatelessWidget {
  const NearbyRadiusStepper({
    super.key,
    required this.radiusKm,
    required this.canNarrow,
    required this.canWiden,
    required this.onNarrow,
    required this.onWiden,
  });

  final double radiusKm;
  final bool canNarrow;
  final bool canWiden;
  final VoidCallback onNarrow;
  final VoidCallback onWiden;

  @override
  Widget build(BuildContext context) {
    final distance = formatNearbyDistance(radiusKm);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove_rounded,
          semanticLabel: 'Smaller radius',
          enabled: canNarrow,
          onTap: onNarrow,
        ),
        const SizedBox(width: 12),
        Semantics(
          label: 'Radius ${distance.label} away from you',
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Away from you',
                style: TextStyle(
                  fontFamily: kTextFontFamily,
                  fontSize: kFontSizeMicro,
                  color: kCreamSecondary,
                  height: 1.2,
                ),
              ),
              Text.rich(
                TextSpan(
                  text: distance.value,
                  children: [
                    TextSpan(
                      text: ' ${distance.unit}',
                      style: const TextStyle(
                        fontSize: kNearbyRadiusUnitFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontFamily: kDisplayFontFamily,
                  fontSize: kNearbyRadiusValueFontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: kAccentCream,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _StepButton(
          icon: Icons.add_rounded,
          semanticLabel: 'Larger radius',
          enabled: canWiden,
          ember: true,
          onTap: onWiden,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.semanticLabel,
    required this.enabled,
    required this.onTap,
    this.ember = false,
  });

  final IconData icon;
  final String semanticLabel;
  final bool enabled;
  final bool ember;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kRadiusPill),
    );

    // One node with the tap on it (D83): the InkWell's own node is excluded,
    // so the label and the action must both live here.
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kRadiusPill),
          child: Material(
            color: ember ? kAccentEmber : kSurfaceDark,
            shape: ember
                ? shape
                : shape.copyWith(side: const BorderSide(color: kHairline)),
            child: InkWell(
              customBorder: shape,
              onTap: enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      onTap();
                    }
                  : null,
              child: SizedBox(
                width: kUtilityButtonSize,
                height: kUtilityButtonSize,
                child: Icon(
                  icon,
                  size: 22,
                  color: ember ? kOnAccent : kAccentCream,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
