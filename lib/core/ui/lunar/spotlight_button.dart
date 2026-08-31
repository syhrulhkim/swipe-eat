import 'package:flutter/material.dart';

import '../design_tokens.dart';
import 'spotlight.dart';

/// A button whose outline lights up under the pointer.
///
/// Port of Lunar UI's Spotlight Button. Same shader as [SpotlightCard], but
/// stroked onto the outline instead of filling the shape, which lights an arc
/// of the border rather than the whole edge.
class SpotlightButton extends StatefulWidget {
  const SpotlightButton({
    super.key,
    required this.child,
    this.onPressed,
    this.from = const Color(0xFFFFFFFF),
    this.via,
    this.to = const Color(0x00000000),
    this.size = 120,
    this.background = const Color(0xFF101014),
    this.restingBorderColor = const Color(0x1FFFFFFF),
    this.borderWidth = 1.4,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.borderRadius = const BorderRadius.all(Radius.circular(kRadiusPill)),
    this.textStyle,
  });

  final Widget child;
  final VoidCallback? onPressed;

  final Color from;
  final Color? via;
  final Color to;

  /// Radius of the lit arc. Smaller than the card's because a button is small:
  /// a 300px highlight would light the whole outline at once.
  final double size;

  final Color background;
  final Color restingBorderColor;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final TextStyle? textStyle;

  @override
  State<SpotlightButton> createState() => _SpotlightButtonState();
}

class _SpotlightButtonState extends State<SpotlightButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final enabled = widget.onPressed != null;
    final label = DefaultTextStyle.merge(
      style: widget.textStyle ??
          const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
      child: widget.child,
    );

    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onPressed!.call();
              }
            : null,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1,
            duration: const Duration(milliseconds: 120),
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: SpotlightRegion(
                child: Padding(padding: widget.padding, child: label),
                builder: (context, pointer, child) => DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.background,
                    borderRadius: widget.borderRadius,
                    border: Border.all(
                      color: widget.restingBorderColor,
                      width: widget.borderWidth,
                    ),
                  ),
                  child: CustomPaint(
                    key: const ValueKey('spotlight-button-highlight'),
                    foregroundPainter: SpotlightPainter(
                      pointer: pointer,
                      borderRadius: widget.borderRadius,
                      from: widget.from,
                      via: widget.via,
                      to: widget.to,
                      radius: widget.size,
                      style: PaintingStyle.stroke,
                      strokeWidth: widget.borderWidth,
                      textDirection: textDirection,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
