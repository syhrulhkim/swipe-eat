import 'package:flutter/material.dart';

import '../../../core/ui/design_tokens.dart';
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
    this.isSaved = false,
    this.isWishlisted = false,
    this.plannedLabel,
  });

  final Restaurant restaurant;

  /// How far away the place is. The Bites grid no longer shows it — the design
  /// puts cuisine and neighbourhood on that line instead — but the cuisine
  /// browse grid still passes one, so the parameter stays.
  final String distanceText;
  final VoidCallback onTap;

  /// Bites the top-right corner out of the tile. Every tile in Bites is saved,
  /// so the whole grid carries it; a mixed grid uses it to tell saved from
  /// unsaved without adding a second badge.
  final bool isSaved;

  /// The place is on the wishlist — the design's `.wish` bookmark, a small
  /// dark circle in the top-right corner.
  ///
  /// It is drawn *over* the bite rather than inside it: the notch's 30 px
  /// radius swallows a 28 px badge at this inset almost whole, which is what
  /// the prototype's mask actually does to its own markup. Painting it above
  /// the clip is the only way both marks survive on one tile.
  final bool isWishlisted;

  /// The day a plan is set for ("Fri 4"), as an ember pill in the top-left.
  /// Always null today — the plans phase fills it in.
  final String? plannedLabel;

  /// "Nasi lemak · Kampung Baru" — the design's tile subtitle. The
  /// neighbourhood is dropped rather than replaced when the row has none: a
  /// dangling separator says the data is missing, and the tile should not.
  String get _subtitle {
    final area = restaurant.neighbourhood;

    return [
      if (restaurant.tag.isNotEmpty) restaurant.tag,
      if (area != null && area.isNotEmpty) area,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl =
        restaurant.imageUrls.isEmpty ? null : restaurant.imageUrls.first;
    final subtitle = _subtitle.isEmpty ? distanceText : _subtitle;
    final planned = plannedLabel;

    return Semantics(
      label: restaurant.name,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        // Two stacks, one inside the other. The inner one is clipped by the
        // bite; the outer one is not, which is where the wishlist bookmark
        // has to live — see [isWishlisted].
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full size, as the prototype specifies for tiles as well as
            // cards. The scale factor that used to sit here existed only to
            // clear the super-like star; the star went with the feature.
            BiteNotch(
              bitten: isSaved,
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
                          subtitle,
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
                  // No clip of its own: this sits inside the tile's own
                  // BiteNotch at the same size, so the notch has already
                  // removed the border wherever it bites. A second identical
                  // clip would cost another path union per tile and, on an
                  // unbitten tile, nest two equal ClipRRects around a 1 px
                  // hairline — which thins it.
                  //
                  // There is no stroke along the notch arc, by design: the
                  // border stops where the clip does, as the prototype's
                  // mask does.
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(kRadiusPanel),
                        border: Border.all(color: kHairline),
                      ),
                    ),
                  ),
                  if (planned != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _PlannedPill(label: planned),
                    ),
                ],
              ),
            ),
            if (isWishlisted)
              const Positioned(top: 8, right: 8, child: _WishBadge()),
          ],
        ),
      ),
    );
  }
}

/// The design's `.tile .wish` — a bookmark saying this place is on the
/// wishlist.
///
/// Decorative, and deliberately not a button: the tile is one tap target, and
/// a second control inside it would compete with opening the restaurant.
/// Removing a place from the wishlist happens on the Wishlist screen, where
/// the whole row is about exactly that.
class _WishBadge extends StatelessWidget {
  const _WishBadge();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: SizedBox(
        width: kWishBadgeSize,
        height: kWishBadgeSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: kFillWishBadge,
            shape: BoxShape.circle,
            border: Border.fromBorderSide(BorderSide(color: kHairline)),
          ),
          child: Icon(
            Icons.bookmark_outline_rounded,
            size: 14,
            color: kTextOnPhoto,
          ),
        ),
      ),
    );
  }
}

/// The design's `.tile .planned` — the day this place is booked for. Ember,
/// because a date the user has set is a thing they chose.
class _PlannedPill extends StatelessWidget {
  const _PlannedPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: kAccentEmber,
          borderRadius: BorderRadius.circular(kRadiusPill),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: kTextFontFamily,
            fontSize: kFontSizeMicro,
            fontWeight: FontWeight.w700,
            color: kOnAccent,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
