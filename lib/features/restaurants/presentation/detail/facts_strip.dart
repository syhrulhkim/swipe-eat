import 'package:flutter/material.dart';

import '../../../../core/ui/app_spacing.dart';
import '../../../../core/ui/design_tokens.dart';

/// One tile of the design's `.facts` grid: a big number and what it counts.
class DetailFact {
  const DetailFact({required this.value, required this.caption});

  final String value;
  final String caption;
}

/// The three-up fact strip under the hero — but only for the facts we can
/// actually answer.
///
/// The design shows price, rating and a typical wait. We have a lowest dish
/// price and a ngap count, and no wait data at all, so the strip carries what
/// it knows and the remaining tiles widen to fill the row. A tile reading "—"
/// would be a question with no answer printed where an answer goes (D111).
class FactsStrip extends StatelessWidget {
  const FactsStrip({super.key, required this.facts});

  final List<DetailFact> facts;

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty) {
      return const SizedBox.shrink();
    }

    // The tiles are a grid in the design, so they share a height even when one
    // caption wraps to two lines and its neighbour does not. Inside a scroll
    // view the row has no height to stretch to, so it measures one.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < facts.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(child: _FactTile(fact: facts[i])),
          ],
        ],
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.fact});

  final DetailFact fact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${fact.value} ${fact.caption}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: kSurfaceDark,
          borderRadius: BorderRadius.circular(kRadiusPanel),
          border: Border.all(color: kHairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // `.fact b{white-space:nowrap}` — the value must not break across
            // lines, so at a large text scale it shrinks instead. A third of a
            // 320 pt row is not wide enough for "From RM 19" at 2x otherwise.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                fact.value,
                maxLines: 1,
                softWrap: false,
                style: appFactValueStyle(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              fact.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: appFactCaptionStyle(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// "1204" → "1,204". The one place the app groups a count, so the ngap figure
/// reads the way the design writes it without pulling in `intl`.
String formatThousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
