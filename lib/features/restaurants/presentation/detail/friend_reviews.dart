import 'package:flutter/material.dart';

import '../../../../core/ui/app_spacing.dart';
import '../../../../core/ui/design_tokens.dart';
import '../../models/restaurant.dart';

/// "What your friends said" — the stars and lines left by the people whose
/// reviews this user is allowed to read (D147).
///
/// Draws nothing when there are none, which is almost every restaurant. A
/// heading over an empty space would say "your friends have nothing to say
/// about this place", which is not what silence means.
///
/// The list is not filtered here: the `reviews` read policy already returned
/// only the caller's own row and their accepted friends'.
class FriendReviews extends StatelessWidget {
  const FriendReviews({super.key, this.reviews = const []});

  final List<RestaurantReview> reviews;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text('What your friends said', style: appSectionTitleStyle(context)),
        for (final review in reviews) ...[
          const SizedBox(height: AppSpacing.xs),
          _ReviewLine(review: review),
        ],
      ],
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.review});

  final RestaurantReview review;

  @override
  Widget build(BuildContext context) {
    final rating = review.rating ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Semantics(
              label: '$rating out of 5',
              child: Row(
                children: [
                  for (var star = 1; star <= 5; star++)
                    Icon(
                      rating >= star
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: kFontSizeBody,
                      color: rating >= star ? kAccentEmber : kTextOnPhotoMuted,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                review.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: kTextFontFamily,
                  fontSize: kFontSizeSmall,
                  color: kTextOnPhotoSecondary,
                ),
              ),
            ),
          ],
        ),
        if (review.text.trim().isNotEmpty)
          Text(
            review.text,
            style: const TextStyle(
              fontFamily: kTextFontFamily,
              fontSize: kFontSizeSmall,
              color: kTextOnPhotoSecondary,
              height: 1.3,
            ),
          ),
      ],
    );
  }
}
