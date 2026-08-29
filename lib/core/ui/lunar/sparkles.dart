import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A drifting field of twinkling dots.
///
/// Port of Lunar UI's Sparkles, which is a thin wrapper over tsParticles. The
/// particle engine has no Flutter equivalent worth pulling in for a few hundred
/// dots, so this reimplements the behaviour its config describes: dots of
/// random size between [minSize] and [size], drifting in random directions
/// between [minSpeed] and [speed], fading between [minOpacity] and [opacity].
///
/// Every particle's position is a pure function of elapsed time, so the widget
/// never mutates state per frame — one ticker repaints one canvas.
class Sparkles extends StatefulWidget {
  const Sparkles({
    super.key,
    this.child,
    this.color = const Color(0xFFFFFFFF),
    this.background = const Color(0x00000000),
    this.density = 200,
    this.size = 1.4,
    this.minSize,
    this.speed = 1,
    this.minSpeed,
    this.opacity = 1,
    this.minOpacity,
    this.opacitySpeed = 3,
    this.random,
  });

  /// Content drawn on top of the sparkles.
  final Widget? child;

  final Color color;
  final Color background;

  /// Number of particles, the original's `density` prop.
  final int density;

  /// Largest particle radius in logical pixels.
  final double size;

  /// Smallest particle radius. The original defaults it to `size / 2.5`.
  final double? minSize;

  /// Fastest drift, in logical pixels per second.
  final double speed;

  /// Slowest drift. The original defaults it to `speed / 10`.
  final double? minSpeed;

  final double opacity;

  /// Dimmest a particle gets. The original defaults it to `opacity / 10`.
  final double? minOpacity;

  /// How fast particles fade in and out.
  final double opacitySpeed;

  /// Injected so a test can pin the layout down; production uses a fresh
  /// [math.Random].
  final math.Random? random;

  @override
  State<Sparkles> createState() => _SparklesState();
}

class _SparklesState extends State<Sparkles>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _elapsedSeconds = ValueNotifier<double>(0);
  late List<_Sparkle> _sparkles;

  @override
  void initState() {
    super.initState();
    _sparkles = _buildSparkles();
    _ticker = createTicker((elapsed) {
      _elapsedSeconds.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    })..start();
  }

  @override
  void didUpdateWidget(Sparkles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.density != widget.density ||
        oldWidget.size != widget.size ||
        oldWidget.minSize != widget.minSize ||
        oldWidget.speed != widget.speed ||
        oldWidget.minSpeed != widget.minSpeed) {
      _sparkles = _buildSparkles();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsedSeconds.dispose();
    super.dispose();
  }

  List<_Sparkle> _buildSparkles() {
    final random = widget.random ?? math.Random();
    final minSize = widget.minSize ?? widget.size / 2.5;
    final minSpeed = widget.minSpeed ?? widget.speed / 10;

    return List<_Sparkle>.generate(math.max(widget.density, 0), (_) {
      final heading = random.nextDouble() * 2 * math.pi;
      final speed = minSpeed + random.nextDouble() * (widget.speed - minSpeed);
      return _Sparkle(
        // Fractions of the box, so a resize redistributes instead of clumping
        // everything into the old bounds.
        origin: Offset(random.nextDouble(), random.nextDouble()),
        radius: minSize + random.nextDouble() * (widget.size - minSize),
        velocity: Offset(math.cos(heading), math.sin(heading)) * speed,
        phase: random.nextDouble() * 2 * math.pi,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final minOpacity = widget.minOpacity ?? widget.opacity / 10;

    return ColoredBox(
      color: widget.background,
      child: CustomPaint(
        painter: _SparklesPainter(
          sparkles: _sparkles,
          time: _elapsedSeconds,
          color: widget.color,
          maxOpacity: widget.opacity,
          minOpacity: minOpacity,
          opacitySpeed: widget.opacitySpeed,
        ),
        child: widget.child,
      ),
    );
  }
}

@immutable
class _Sparkle {
  const _Sparkle({
    required this.origin,
    required this.radius,
    required this.velocity,
    required this.phase,
  });

  /// Starting position as a fraction of the box, 0..1 on each axis.
  final Offset origin;
  final double radius;

  /// Logical pixels per second.
  final Offset velocity;

  /// Offset into the fade cycle, so the field does not blink in unison.
  final double phase;
}

class _SparklesPainter extends CustomPainter {
  _SparklesPainter({
    required this.sparkles,
    required this.time,
    required this.color,
    required this.maxOpacity,
    required this.minOpacity,
    required this.opacitySpeed,
  }) : super(repaint: time);

  final List<_Sparkle> sparkles;
  final ValueListenable<double> time;
  final Color color;
  final double maxOpacity;
  final double minOpacity;
  final double opacitySpeed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final seconds = time.value;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final sparkle in sparkles) {
      // Drifting off one edge reappears on the other, which keeps the field
      // evenly populated forever instead of slowly emptying out.
      final x = _wrap(sparkle.origin.dx * size.width + sparkle.velocity.dx * seconds, size.width);
      final y = _wrap(sparkle.origin.dy * size.height + sparkle.velocity.dy * seconds, size.height);

      final wave = 0.5 + 0.5 * math.sin(sparkle.phase + seconds * opacitySpeed);
      final alpha = (minOpacity + (maxOpacity - minOpacity) * wave).clamp(0.0, 1.0);

      paint.color = color.withValues(alpha: color.a * alpha);
      canvas.drawCircle(Offset(x, y), sparkle.radius, paint);
    }
  }

  double _wrap(double value, double extent) {
    final wrapped = value % extent;
    return wrapped < 0 ? wrapped + extent : wrapped;
  }

  @override
  bool shouldRepaint(_SparklesPainter oldDelegate) {
    return oldDelegate.sparkles != sparkles ||
        oldDelegate.color != color ||
        oldDelegate.maxOpacity != maxOpacity ||
        oldDelegate.minOpacity != minOpacity ||
        oldDelegate.opacitySpeed != opacitySpeed;
  }
}
