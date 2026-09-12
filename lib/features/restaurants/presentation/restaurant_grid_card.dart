import 'package:flutter/material.dart';

import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/tiktok_thumbnail_placeholder.dart';
import '../models/restaurant.dart';

/// One restaurant as a tile in the Bites grid: the photo on top, and the name
/// and cuisine on their own dark strip underneath it rather than laid over
/// the picture.
class RestaurantGridCard extends StatelessWidget {
  const RestaurantGridCard({
    super.key,
    required this.restaurant,
    required this.distanceText,
    required this.onTap,
    this.isSaved = false,
    this.plannedLabel,
  });

  final Restaurant restaurant;

  /// Only the fallback for a row with neither cuisine nor neighbourhood; the
  /// Bites grid passes an empty string. The parameter outlives the cuisine
  /// browse grid that used to fill it (D102).
  final String distanceText;
  final VoidCallback onTap;

  /// Draws the ember check in the photo's top-right corner. Every tile in
  /// Bites is saved, so the whole grid carries it; a mixed grid would use it
  /// to tell saved from unsaved.
  final bool isSaved;

  /// The day a plan is set for ("Fri 4"), as an ember pill in the top-left.
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
        // Opaque so a tap on the check or the day pill — the marks that look
        // most like controls — lands on the tile rather than falling through.
        behavior: HitTestBehavior.opaque,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: kSurfaceDark,
            borderRadius: BorderRadius.circular(kRadiusPanel),
          ),
          // The outline is painted over the photo, not under it: a border in
          // the background decoration insets the square-cornered photo one
          // pixel inside a rounded stroke, and the photo then overpaints the
          // stroke at every corner.
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadiusPanel),
            border: Border.all(color: kHairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The photo takes whatever the caption leaves, so a large text
              // scale grows the strip and shrinks the picture instead of
              // overflowing the tile.
              Expanded(
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
                        // A two-column tile: half the screen is an upper
                        // bound, and over is safe where under would blur.
                        cacheWidth: cachePx(
                          context,
                          MediaQuery.sizeOf(context).width / 2,
                        ),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return TikTokThumbnailPlaceholder(
                            creatorHandle:
                                tiktokCreatorHandle(restaurant.videoUrl),
                          );
                        },
                      ),
                    if (isSaved)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: _SavedCheck(),
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
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // One line, not two: the strip is sized to its text, so a
                    // second line of name would come straight out of the photo.
                    Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appPanelTitleStyle(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: kCreamMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ember check in the photo's corner: "this is in your bites".
///
/// A mark, not a button — the tile is one tap target, and a second control
/// inside it would compete with opening the restaurant. It is the wishlist
/// row's tick at the same size and glyph, so "done" and "saved" read as the
/// same family of mark.
class _SavedCheck extends StatelessWidget {
  const _SavedCheck();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: SizedBox(
        width: kCheckCircleSize,
        height: kCheckCircleSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: kAccentEmber,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, size: 14, color: kTextOnPhoto),
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
