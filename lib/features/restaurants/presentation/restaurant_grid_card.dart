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
    this.isSaved = false,
  });

  final Restaurant restaurant;
  final String distanceText;
  final VoidCallback onTap;

  /// Sits in a top corner over the photo — the Liked grid puts the super-like
  /// star and its two row actions here. Null for plain tiles.
  ///
  /// Which corner depends on [isSaved]: the bite owns the top right, and these
  /// are buttons, so on a bitten tile they move left rather than being cut in
  /// half by the notch.
  final Widget? badge;

  /// Bites the top-right corner out of the tile. Every tile in Bites is saved,
  /// so the whole grid carries it; a mixed grid uses it to tell saved from
  /// unsaved without adding a second badge.
  final bool isSaved;

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
        child: BiteNotch(
          bitten: isSaved,
          borderRadius: BorderRadius.circular(kRadiusPanel),
          radius: kBiteNotchRadius * kBiteNotchTileScale,
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
              const PhotoTileScrim(),
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
              // No clip of its own: this sits inside the tile's own BiteNotch
              // at the same size, so the notch has already removed the border
              // wherever it bites. A second identical clip would cost another
              // path union per tile and, on an unbitten tile, nest two equal
              // ClipRRects around a 1 px hairline — which thins it.
              //
              // There is no stroke along the notch arc, by design: the border
              // stops where the clip does, as the prototype's mask does.
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(kRadiusPanel),
                    border: Border.all(color: kHairline),
                  ),
                ),
              ),
              if (badge != null)
                Positioned(
                  top: 8,
                  left: isSaved ? 8 : null,
                  right: isSaved ? null : 8,
                  child: badge!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
