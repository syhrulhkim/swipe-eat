import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Where a spotlight is currently pointing, and how visible it is.
///
/// [strength] is the fade factor: 0 when the pointer has left, 1 when it is
/// over the surface. Painters multiply their colors by it so the highlight
/// fades in and out instead of popping.
@immutable
class SpotlightPointer {
  const SpotlightPointer({required this.position, required this.strength});

  final Offset position;
  final double strength;

  bool get isVisible => strength > 0;

  @override
  bool operator ==(Object other) =>
      other is SpotlightPointer &&
      other.position == position &&
      other.strength == strength;

  @override
  int get hashCode => Object.hash(position, strength);
}

typedef SpotlightWidgetBuilder = Widget Function(
  BuildContext context,
  SpotlightPointer pointer,
  Widget? child,
);

/// Tracks the pointer over its subtree and rebuilds [builder] as it moves.
///
/// The web originals are hover-only. A phone has no hover, so a touch that
/// presses and drags drives the same highlight and releases it on lift —
/// otherwise these components would be inert on the platform this app ships
/// on.
class SpotlightRegion extends StatefulWidget {
  const SpotlightRegion({
    super.key,
    required this.builder,
    this.child,
    this.fadeDuration = const Duration(milliseconds: 250),
  });

  final SpotlightWidgetBuilder builder;

  /// Subtree that does not depend on the pointer, built once and handed back
  /// to [builder] on every move.
  final Widget? child;

  final Duration fadeDuration;

  @override
  State<SpotlightRegion> createState() => _SpotlightRegionState();
}

class _SpotlightRegionState extends State<SpotlightRegion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: widget.fadeDuration,
  );

  Offset _position = Offset.zero;

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _show(Offset position) {
    _position = position;
    if (!_fade.isAnimating && _fade.value == 1) {
      // Already lit: the AnimatedBuilder still has to hear about the move.
      setState(() {});
    } else {
      _fade.forward();
      setState(() {});
    }
  }

  void _hide() {
    _fade.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) => _show(event.localPosition),
      onExit: (_) => _hide(),
      child: Listener(
        onPointerDown: (event) => _show(event.localPosition),
        onPointerMove: (event) => _show(event.localPosition),
        onPointerUp: (_) => _hide(),
        onPointerCancel: (_) => _hide(),
        child: AnimatedBuilder(
          animation: _fade,
          child: widget.child,
          builder: (context, child) => widget.builder(
            context,
            SpotlightPointer(position: _position, strength: _fade.value),
            child,
          ),
        ),
      ),
    );
  }
}

/// Paints the radial highlight itself: a circle of [radius] centred on the
/// pointer, running [from] through [via] out to [to].
///
/// Filling a rounded rectangle with this and covering all but a hairline of it
/// is what makes the card's border glow; stroking with it lights an arc of a
/// button's outline.
class SpotlightPainter extends CustomPainter {
  const SpotlightPainter({
    required this.pointer,
    required this.borderRadius,
    required this.from,
    required this.radius,
    this.via,
    this.to = const Color(0x00000000),
    this.style = PaintingStyle.fill,
    this.strokeWidth = 1,
    this.textDirection = TextDirection.ltr,
  });

  final SpotlightPointer pointer;
  final BorderRadiusGeometry borderRadius;
  final Color from;
  final Color? via;
  final Color to;

  /// Radius of the highlight in logical pixels, matching the original's
  /// `size` prop.
  final double radius;

  final PaintingStyle style;
  final double strokeWidth;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (!pointer.isVisible) {
      return;
    }

    final strength = pointer.strength.clamp(0.0, 1.0);
    final colors = <Color>[
      from.withValues(alpha: from.a * strength),
      if (via != null) via!.withValues(alpha: via!.a * strength),
      to.withValues(alpha: to.a * strength),
    ];
    final stops = colors.length == 3
        ? const <double>[0, 0.5, 1]
        : const <double>[0, 1];

    final paint = Paint()
      ..style = style
      ..strokeWidth = strokeWidth
      ..shader = ui.Gradient.radial(pointer.position, radius, colors, stops);

    final rect = Offset.zero & size;
    final rrect = borderRadius.resolve(textDirection).toRRect(rect);
    if (style == PaintingStyle.stroke) {
      // Stroking a rounded rect centres the line on the path, so half of it
      // would fall outside the widget and be clipped away.
      canvas.drawRRect(rrect.deflate(strokeWidth / 2), paint);
    } else {
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(SpotlightPainter oldDelegate) {
    return oldDelegate.pointer != pointer ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.from != from ||
        oldDelegate.via != via ||
        oldDelegate.to != to ||
        oldDelegate.radius != radius ||
        oldDelegate.style != style ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Default highlight colors of the reference design: teal into blue.
const Color kSpotlightFrom = Color(0xFF1CD1C6);
const Color kSpotlightVia = Color(0xFF407CFF);

/// Pointer kinds that can drive a spotlight, used by the widget tests.
const Set<PointerDeviceKind> kSpotlightPointerKinds = <PointerDeviceKind>{
  PointerDeviceKind.mouse,
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
};
