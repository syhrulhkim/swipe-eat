import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/design_tokens.dart';

/// What the circle actually contains, and the one thing to do about it.
///
/// Flush with the bottom nav and rounded only at the top, so it reads as the
/// map resting on the nav rather than as a card floating over both.
class NearbyResultsBar extends StatelessWidget {
  const NearbyResultsBar({
    super.key,
    required this.resultCount,
    required this.openNowCount,
    required this.minPriceFrom,
    required this.onSwipeAll,
  });

  final int resultCount;
  final int openNowCount;

  /// The cheapest RM figure among the results. Null hides the whole block —
  /// most of the catalogue names no price, and "From RM —" says nothing.
  final int? minPriceFrom;

  final VoidCallback onSwipeAll;

  @override
  Widget build(BuildContext context) {
    final price = minPriceFrom;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(kRadiusPanel),
        ),
        border: Border(
          top: BorderSide(color: kHairline),
          left: BorderSide(color: kHairline),
          right: BorderSide(color: kHairline),
        ),
      ),
      // The button is laid out first and at its natural width; the figures
      // take what is left. On a 320 px screen with a three-digit count that
      // is less than they want, and a shortened "Open no…" beats a bar that
      // overflows — the action must never be the thing that gets cut.
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (price != null) ...[
                  Flexible(child: _Figure(label: 'From', value: 'RM $price')),
                  // Flexible, not a plain gap: under real pressure the space
                  // between the two figures has to be able to close before
                  // either figure is allowed to overflow the bar.
                  const Flexible(child: SizedBox(width: 20)),
                ],
                Flexible(
                  child: _Figure(label: 'Open now', value: '$openNowCount'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Flexible with its natural width as the ceiling: at large text the
          // button's label shrinks to fit rather than pushing past the edge.
          Flexible(
            child: _SwipeAllButton(count: resultCount, onTap: onSwipeAll),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: kTextFontFamily,
              fontSize: kFontSizeMicro,
              color: kCreamSecondary,
              height: 1.2,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: kDisplayFontFamily,
              fontSize: kNearbyResultFigureFontSize,
              fontWeight: FontWeight.w700,
              color: kAccentCream,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

/// The bar's one action: take everything in the circle to the deck.
///
/// A flat ember fill rather than the CTA gradient — the gradient belongs to
/// the deck's Ngap button, and a second gradient on the same journey would
/// make neither the primary one.
class _SwipeAllButton extends StatelessWidget {
  const _SwipeAllButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kRadiusPill),
    );
    final live = count > 0;

    return Semantics(
      label: 'Swipe all $count',
      button: true,
      enabled: live,
      excludeSemantics: true,
      onTap: live ? onTap : null,
      child: Opacity(
        opacity: live ? 1 : 0.4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kRadiusPill),
          child: Material(
            color: kAccentEmber,
            shape: shape,
            child: InkWell(
              customBorder: shape,
              onTap: live
                  ? () {
                      HapticFeedback.selectionClick();
                      onTap();
                    }
                  : null,
              child: Container(
                height: kNearbyResultButtonHeight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Swipe all $count',
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: kTextFontFamily,
                      fontSize: kFontSizeBody,
                      fontWeight: FontWeight.w600,
                      color: kOnAccent,
                      height: 1.2,
                    ),
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
