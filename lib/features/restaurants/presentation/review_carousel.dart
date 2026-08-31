import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/ui/design_tokens.dart';
import '../models/restaurant_card.dart';

/// The review snippets on an expanded card, one page each.
class ReviewCarousel extends StatefulWidget {
  const ReviewCarousel({
    super.key,
    required this.reviews,
    required this.onInteractionChanged,
  });

  final List<ReviewSnippet> reviews;

  /// Raised while a finger is on the carousel, so the deck can stop treating
  /// the drag as a swipe of the whole card.
  final ValueChanged<bool> onInteractionChanged;

  @override
  State<ReviewCarousel> createState() => _ReviewCarouselState();
}

class _ReviewCarouselState extends State<ReviewCarousel> {
  late final PageController _pageController = PageController();
  int _pageIndex = 0;

  /// Measures the tallest review so every page gets the same height: a
  /// PageView cannot size itself to its children, and a per-page height would
  /// make the panel jump as the user swipes.
  double _reviewCardHeight(BuildContext context, double maxWidth) {
    final baseTextStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.90),
          height: 1.35,
        );
    final titleStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.75),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.10,
        );
    final contentWidth = math.max(120.0, maxWidth - 12 - 12 - 30 - 10);

    double textHeightFor(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: baseTextStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: contentWidth);
      return painter.height;
    }

    final titlePainter = TextPainter(
      text: TextSpan(text: 'Top review', style: titleStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: contentWidth);

    final reviewHeight = widget.reviews.fold<double>(
      0,
      (currentMax, review) => math.max(currentMax, textHeightFor(review.text)),
    );
    final textColumnHeight = titlePainter.height + 3 + reviewHeight;
    final contentHeight = math.max(30.0, textColumnHeight);

    return 12 + contentHeight + 10 + 4;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reviews.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = _reviewCardHeight(context, constraints.maxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => widget.onInteractionChanged(true),
              onPointerUp: (_) => widget.onInteractionChanged(false),
              onPointerCancel: (_) => widget.onInteractionChanged(false),
              child: SizedBox(
                height: height,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.reviews.length,
                  onPageChanged: (index) {
                    setState(() {
                      _pageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _ReviewCard(snippet: widget.reviews[index]),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Swipe for more reviews',
                  style: appEyebrowStyle(context).copyWith(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                ProgressDots(
                  count: widget.reviews.length,
                  activeIndex: _pageIndex,
                  style: ProgressDotsStyle.review,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.snippet});

  final ReviewSnippet snippet;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(kRadiusPanel),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(kRadiusPill),
            ),
            child: const Icon(
              Icons.rate_review_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Top review',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.10,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  snippet.text,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.90),
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
