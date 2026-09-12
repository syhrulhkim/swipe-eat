import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Which of the two dot rows to draw: the review pager's, or the thinner
/// animated one over a card's photos.
enum ProgressDotsStyle { review, photo }

/// Row of dots marking position in a small pager.
class ProgressDots extends StatelessWidget {
  const ProgressDots({
    super.key,
    required this.count,
    required this.activeIndex,
    this.style = ProgressDotsStyle.review,
  });

  final int count;
  final int activeIndex;
  final ProgressDotsStyle style;

  @override
  Widget build(BuildContext context) {
    final isPhoto = style == ProgressDotsStyle.photo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final isActive = index == activeIndex;
        final decoration = BoxDecoration(
          color: Colors.white.withValues(
            alpha: isActive ? 0.95 : (isPhoto ? 0.35 : 0.30),
          ),
          borderRadius: BorderRadius.circular(kRadiusPill),
        );
        final margin = EdgeInsets.only(
          right: index == count - 1 ? 0 : (isPhoto ? 5 : 4),
        );

        if (!isPhoto) {
          return Container(
            width: isActive ? 14 : 5,
            height: 5,
            margin: margin,
            decoration: decoration,
          );
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: isActive ? 18 : 6,
          height: 3,
          margin: margin,
          decoration: decoration,
        );
      }),
    );
  }
}
