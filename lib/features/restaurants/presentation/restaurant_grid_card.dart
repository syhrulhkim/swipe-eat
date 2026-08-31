import 'package:flutter/material.dart';

import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/rating_label.dart';
import '../../../core/ui/tiktok_thumbnail_placeholder.dart';
import '../models/restaurant.dart';

/// One restaurant as a photo tile in a two-column browse grid — the cuisine
/// list and the Liked grid share this card so the two surfaces read as one.
class RestaurantGridCard extends StatelessWidget {
  const RestaurantGridCard({
    super.key,
    required this.restaurant,
    required this.distanceText,
    required this.onTap,
    this.badge,
  });

  final Restaurant restaurant;
  final String distanceText;
  final VoidCallback onTap;

  /// Sits in the top-right corner over the photo — the Liked grid puts the
  /// super-like star here. Null for plain tiles.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final photoUrl =
        restaurant.imageUrls.isEmpty ? null : restaurant.imageUrls.first;
    final rating = ratingLabel(restaurant.rating);

    return Semantics(
      label: restaurant.name,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kRadiusPanel),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photoUrl == null)
                TikTokThumbnailPlaceholder(
                  creatorHandle: tiktokCreatorHandle(restaurant.videoUrl),
                )
              else
                Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return TikTokThumbnailPlaceholder(
                      creatorHandle: tiktokCreatorHandle(restaurant.videoUrl),
                    );
                  },
                ),
              const _CardScrim(),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: appPanelTitleStyle(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rating == '–'
                          ? distanceText
                          : '$distanceText  ·  ★ $rating',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: kTextOnPhotoMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              // IgnorePointer, or this full-card overlay swallows every tap
              // meant for the badge buttons underneath it.
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(kRadiusPanel),
                    border: Border.all(color: kHairline),
                  ),
                ),
              ),
              if (badge != null)
                Positioned(top: 8, right: 8, child: badge!),
            ],
          ),
        ),
      ),
    );
  }
}

/// The wash that keeps the name and rating legible over a photo.
///
/// Sized to the tile rather than in pixels. [PhotoBottomScrim] is 620 px tall
/// for a full-bleed photo screen; on a grid tile a few hundred pixels high that
/// is the near-opaque end of the gradient covering the entire card, which
/// turned every tile black. This one keeps its ramp in the bottom half of
/// whatever it is given.
class _CardScrim extends StatelessWidget {
  const _CardScrim();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.78),
                Colors.black.withValues(alpha: 0.42),
                Colors.black.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.28, 0.58],
            ),
          ),
        ),
      ),
    );
  }
}
