import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A lattice of faint dots where a handful light up at a time, plus one
/// featured dot ringed in an accent color.
///
/// Port of Lunar UI's Star Grid. The original is a compound component
/// (`StarGrid.Group` / `StarGrid.Item`) because it lights up real DOM children;
/// there is nothing to lay out here, so the grid is painted and the featured
/// cell is chosen by [featuredAlignment].
///
/// Every [duration] a new set of [activeCount] dots is chosen and the previous
/// set fades out as the new one fades in, so the field shimmers instead of
/// blinking.
class StarGrid extends StatefulWidget {
  const StarGrid({
    super.key,
    this.child,
    this.spacing = 28,
    this.dotRadius = 1.6,
    this.activeCount = 20,
    this.duration = const Duration(milliseconds: 2000),
    this.featureDuration = const Duration(milliseconds: 1000),
    this.color = const Color(0xFFFFFFFF),
    this.restingOpacity = 0.08,
    this.activeOpacity = 0.65,
    this.featureColor = const Color(0xFF22D3EE),
    this.featuredAlignment = const Alignment(0.1, -0.15),
    this.showFeatured = true,
    this.random,
  });

  /// Content drawn on top of the grid.
  final Widget? child;

  /// Distance between dot centres, in logical pixels.
  final double spacing;

  final double dotRadius;

  /// How many dots are lit at once.
  final int activeCount;

  /// How long one lit set lasts before the next is chosen.
  final Duration duration;

  /// Period of the featured dot's pulse.
  final Duration featureDuration;

  final Color color;
  final double restingOpacity;
  final double activeOpacity;

  final Color featureColor;

  /// Which dot gets the ring, expressed as a position in the box; the nearest
  /// lattice point to it wins.
  final Alignment featuredAlignment;

  final bool showFeatured;

  /// Injected so a test can pin the lit set down; production uses a fresh
  /// [math.Random].
  final math.Random? random;

  @override
  State<StarGrid> createState() => _StarGridState();
}

class _StarGridState extends State<StarGrid> with TickerProviderStateMixin {
  late final math.Random _random = widget.random ?? math.Random();

  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final AnimationController _feature = AnimationController(
    vsync: this,
    duration: widget.featureDuration,
  );

  /// Dot counts change with the box size, so the lit sets are picked lazily
  /// once the first layout tells the painter how many dots there are.
  int _dotCount = 0;
  List<int> _previousActive = const <int>[];
  List<int> _currentActive = const <int>[];

  @override
  void initState() {
    super.initState();
    // A repeating controller rather than a Timer: it stops with the widget and
    // it is drivable from a test's pump.
    _cycle
      ..addStatusListener(_onCycleStatus)
      ..forward();
    _feature.repeat(reverse: true);
  }

  void _onCycleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    _rollActive();
    _cycle.forward(from: 0);
  }

  @override
  void dispose() {
    _cycle.dispose();
    _feature.dispose();
    super.dispose();
  }

  void _rollActive() {
    if (_dotCount <= 0) {
      return;
    }
    _previousActive = _currentActive;
    final wanted = math.min(widget.activeCount, _dotCount);
    final picked = <int>{};
    // Sampling with a set rather than shuffling the whole lattice: the grid can
    // be a few thousand dots and only twenty are needed.
    while (picked.length < wanted) {
      picked.add(_random.nextInt(_dotCount));
    }
    _currentActive = picked.toList(growable: false);
  }

  void _syncDotCount(int count) {
    if (count == _dotCount) {
      return;
    }
    _dotCount = count;
    _previousActive = const <int>[];
    _currentActive = const <int>[];
    _rollActive();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;
        final height = constraints.hasBoundedHeight ? constraints.maxHeight : 0.0;
        final columns = width > 0 ? (width / widget.spacing).floor() + 1 : 0;
        final rows = height > 0 ? (height / widget.spacing).floor() + 1 : 0;
        _syncDotCount(columns * rows);

        return AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[_cycle, _feature]),
          child: widget.child,
          builder: (context, child) => CustomPaint(
            painter: _StarGridPainter(
              columns: columns,
              rows: rows,
              spacing: widget.spacing,
              dotRadius: widget.dotRadius,
              previousActive: _previousActive,
              currentActive: _currentActive,
              progress: Curves.easeInOut.transform(_cycle.value),
              featurePulse: Curves.easeInOut.transform(_feature.value),
              color: widget.color,
              restingOpacity: widget.restingOpacity,
              activeOpacity: widget.activeOpacity,
              featureColor: widget.featureColor,
              featuredAlignment: widget.featuredAlignment,
              showFeatured: widget.showFeatured,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _StarGridPainter extends CustomPainter {
  const _StarGridPainter({
    required this.columns,
    required this.rows,
    required this.spacing,
    required this.dotRadius,
    required this.previousActive,
    required this.currentActive,
    required this.progress,
    required this.featurePulse,
    required this.color,
    required this.restingOpacity,
    required this.activeOpacity,
    required this.featureColor,
    required this.featuredAlignment,
    required this.showFeatured,
  });

  final int columns;
  final int rows;
  final double spacing;
  final double dotRadius;
  final List<int> previousActive;
  final List<int> currentActive;
  final double progress;
  final double featurePulse;
  final Color color;
  final double restingOpacity;
  final double activeOpacity;
  final Color featureColor;
  final Alignment featuredAlignment;
  final bool showFeatured;

  @override
  void paint(Canvas canvas, Size size) {
    if (columns <= 0 || rows <= 0) {
      return;
    }

    // Centre the lattice: the box is rarely an exact multiple of the spacing,
    // and a leftover gap on one side only reads as a mistake.
    final originX = (size.width - (columns - 1) * spacing) / 2;
    final originY = (size.height - (rows - 1) * spacing) / 2;

    final featuredIndex = showFeatured
        ? _nearestIndex(size, originX, originY)
        : -1;

    final fadingOut = previousActive.toSet();
    final fadingIn = currentActive.toSet();
    final paint = Paint()..style = PaintingStyle.fill;

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final index = row * columns + column;
        final center = Offset(
          originX + column * spacing,
          originY + row * spacing,
        );

        var lit = 0.0;
        if (fadingOut.contains(index)) {
          lit += 1 - progress;
        }
        if (fadingIn.contains(index)) {
          lit += progress;
        }
        final alpha = restingOpacity +
            (activeOpacity - restingOpacity) * lit.clamp(0.0, 1.0);

        if (index == featuredIndex) {
          _paintFeatured(canvas, center, paint);
          continue;
        }

        paint.color = color.withValues(alpha: color.a * alpha);
        canvas.drawCircle(center, dotRadius, paint);
      }
    }
  }

  void _paintFeatured(Canvas canvas, Offset center, Paint paint) {
    paint
      ..style = PaintingStyle.fill
      ..color = featureColor;
    canvas.drawCircle(center, dotRadius * 1.3, paint);

    final ringRadius = dotRadius * 3 + dotRadius * 3 * featurePulse;
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = featureColor.withValues(alpha: 0.7 * (1 - featurePulse)),
    );

    // Restore the fill mode for the plain dots that follow.
    paint.style = PaintingStyle.fill;
  }

  int _nearestIndex(Size size, double originX, double originY) {
    final target = featuredAlignment.alongSize(size);
    final column = ((target.dx - originX) / spacing).round().clamp(0, columns - 1);
    final row = ((target.dy - originY) / spacing).round().clamp(0, rows - 1);
    return row * columns + column;
  }

  @override
  bool shouldRepaint(_StarGridPainter oldDelegate) {
    return oldDelegate.columns != columns ||
        oldDelegate.rows != rows ||
        oldDelegate.spacing != spacing ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.progress != progress ||
        oldDelegate.featurePulse != featurePulse ||
        oldDelegate.previousActive != previousActive ||
        oldDelegate.currentActive != currentActive ||
        oldDelegate.color != color ||
        oldDelegate.restingOpacity != restingOpacity ||
        oldDelegate.activeOpacity != activeOpacity ||
        oldDelegate.featureColor != featureColor ||
        oldDelegate.featuredAlignment != featuredAlignment ||
        oldDelegate.showFeatured != showFeatured;
  }
}
