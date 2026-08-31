import 'package:flutter/material.dart';

import '../design_tokens.dart';
import 'spotlight.dart';

/// How the highlight sits relative to the card's content.
enum SpotlightCardMode {
  /// The gradient fills the card and the content covers all but a hairline of
  /// it, so the pointer appears to light up the border. This is the `before`
  /// mode of the original.
  border,

  /// The gradient is painted over the content, washing it with color. This is
  /// the original's `after` mode.
  overlay,
}

/// A card whose border lights up where the pointer is.
///
/// Port of Lunar UI's Spotlight Card. The trick is the same one the original
/// uses: a rounded rectangle filled with a pointer-centred radial gradient,
/// then an opaque surface inset by [borderWidth] on top of it, which leaves
/// only a lit ring showing. No path arithmetic and no shader per corner.
class SpotlightCard extends StatelessWidget {
  const SpotlightCard({
    super.key,
    required this.child,
    this.from = kSpotlightFrom,
    this.via = kSpotlightVia,
    this.to = const Color(0x00000000),
    this.size = 300,
    this.mode = SpotlightCardMode.border,
    this.surfaceColor = const Color(0xFF18181B),
    this.restingBorderColor = const Color(0x1AFFFFFF),
    this.borderRadius = const BorderRadius.all(Radius.circular(kRadiusPanel)),
    this.borderWidth = 1,
    this.padding = const EdgeInsets.all(24),
    this.overlayOpacity = 0.18,
    this.onTap,
  });

  final Widget child;

  /// Innermost color of the highlight, right under the pointer.
  final Color from;

  /// Optional middle color; the original's demo runs teal into blue.
  final Color? via;

  /// Outermost color, transparent by default so the highlight has no edge.
  final Color to;

  /// Radius of the highlight in logical pixels, the original's `size` prop.
  final double size;

  final SpotlightCardMode mode;

  /// Fill behind the content. It has to be opaque in [SpotlightCardMode.border]
  /// or the gradient shows through the whole card instead of just the ring.
  final Color surfaceColor;

  /// Border color where the pointer is not, so the card still reads as a card
  /// when nothing is touching it.
  final Color restingBorderColor;

  final BorderRadiusGeometry borderRadius;
  final double borderWidth;
  final EdgeInsetsGeometry padding;

  /// How strongly the highlight tints the content in
  /// [SpotlightCardMode.overlay]. At 1 the gradient would bleach the text.
  final double overlayOpacity;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final innerRadius = _deflate(borderRadius.resolve(textDirection));

    final content = Padding(padding: padding, child: child);

    Widget card = SpotlightRegion(
      child: content,
      builder: (context, pointer, child) {
        final spotlight = CustomPaint(
          key: const ValueKey('spotlight-card-highlight'),
          painter: SpotlightPainter(
            pointer: pointer,
            borderRadius: mode == SpotlightCardMode.border
                ? borderRadius
                : innerRadius,
            from: from,
            via: via,
            to: to,
            radius: size,
            textDirection: textDirection,
          ),
        );

        return Stack(
          fit: StackFit.passthrough,
          children: [
            // Resting outline, drawn under everything so the highlight wins
            // wherever the pointer is.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: restingBorderColor,
                  borderRadius: borderRadius,
                ),
              ),
            ),
            if (mode == SpotlightCardMode.border) Positioned.fill(child: spotlight),
            Padding(
              padding: EdgeInsets.all(borderWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: innerRadius,
                ),
                child: child,
              ),
            ),
            if (mode == SpotlightCardMode.overlay)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(borderWidth),
                  child: IgnorePointer(
                    child: Opacity(opacity: overlayOpacity, child: spotlight),
                  ),
                ),
              ),
          ],
        );
      },
    );

    if (onTap != null) {
      card = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: card,
      );
    }

    return ClipRRect(borderRadius: borderRadius, child: card);
  }

  /// Corner radius of the inner surface. Insetting a rounded rect by the border
  /// width also shrinks its corners, and reusing the outer radius would leave a
  /// sliver of gradient poking out at each corner.
  BorderRadius _deflate(BorderRadius radius) {
    Radius shrink(Radius corner) => Radius.elliptical(
          (corner.x - borderWidth).clamp(0.0, double.infinity),
          (corner.y - borderWidth).clamp(0.0, double.infinity),
        );

    return BorderRadius.only(
      topLeft: shrink(radius.topLeft),
      topRight: shrink(radius.topRight),
      bottomLeft: shrink(radius.bottomLeft),
      bottomRight: shrink(radius.bottomRight),
    );
  }
}
