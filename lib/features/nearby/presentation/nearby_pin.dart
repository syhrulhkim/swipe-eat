import 'package:flutter/material.dart';

import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/tiktok_thumbnail_placeholder.dart';
import '../domain/nearby_format.dart';
import '../models/nearby_place.dart';

/// One restaurant on the map: a circular blob carrying its cover photo, an
/// ember distance badge, and the name, cuisine and open line stacked under it.
///
/// The blob is bitten when the user has already saved the place — the app's
/// one decorative device, and the only marker a saved restaurant ever gets.
class NearbyPin extends StatelessWidget {
  const NearbyPin({
    super.key,
    required this.place,
    required this.saved,
    required this.prominent,
    required this.now,
    required this.onTap,
  });

  final NearbyPlace place;

  /// Already bitten: the user has this one in their likes.
  final bool saved;

  /// One of the two closest results — drawn larger, with an ember ring.
  final bool prominent;

  /// The clock the open line is read against, so the pin is a pure function of
  /// its inputs and a test can move time without waiting.
  final DateTime now;

  final VoidCallback onTap;

  /// The box the marker occupies. Taller than the content so a pin can never
  /// clip its own third line; the slack sits under the text, where markers
  /// only ever overlap each other.
  static double heightFor({required bool prominent}) =>
      prominent ? 170 : 150;

  /// Puts the blob's centre — not the box's — on the coordinate, so a pin
  /// points at its restaurant rather than hovering above it.
  static Alignment alignmentFor({required bool prominent}) {
    final blob = prominent ? kNearbyPinBigSize : kNearbyPinSize;
    return Alignment(0, 1 - blob / heightFor(prominent: prominent));
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = place.restaurant;
    final openLine = nearbyOpenLine(restaurant.hours, now);
    final distance = formatNearbyDistance(place.distanceKm);

    return Semantics(
      label: [
        restaurant.name,
        if (restaurant.tag.isNotEmpty) restaurant.tag,
        distance.label,
        if (openLine != null) openLine.text,
        if (saved) 'Saved',
      ].join(', '),
      button: true,
      // The stack below carries its own text nodes, which would be announced
      // twice on top of the label above. Excluding them drops the tap action
      // too, so it is re-declared here — see D83.
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Align(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Blob(
                place: place,
                saved: saved,
                prominent: prominent,
                distance: distance.label,
              ),
              const SizedBox(height: 6),
              Text(
                restaurant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: kTextFontFamily,
                  fontSize: kFontSizeSmall,
                  fontWeight: FontWeight.w600,
                  color: kAccentCream,
                  height: 1.15,
                ),
              ),
              if (restaurant.tag.isNotEmpty)
                Text(
                  restaurant.tag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kFontSizeMicro,
                    fontWeight: FontWeight.w400,
                    color: kCreamSecondary,
                    height: 1.15,
                  ),
                ),
              if (openLine != null)
                Text(
                  openLine.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kNearbyDistanceFontSize,
                    fontWeight: FontWeight.w600,
                    color: openLine.tone == NearbyOpenTone.fresh
                        ? kFresh
                        : kCreamMuted,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.place,
    required this.saved,
    required this.prominent,
    required this.distance,
  });

  final NearbyPlace place;
  final bool saved;
  final bool prominent;
  final String distance;

  @override
  Widget build(BuildContext context) {
    final size = prominent ? kNearbyPinBigSize : kNearbyPinSize;
    final coverUrl = place.coverUrl;

    return Stack(
      // The badge overhangs the blob's corner by design.
      clipBehavior: Clip.none,
      children: [
        BiteNotch(
          bitten: saved,
          borderRadius: BorderRadius.circular(kRadiusPill),
          radius: kNearbyPinBiteRadius,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: kSurfaceDark,
              borderRadius: BorderRadius.circular(kRadiusPill),
              border: Border.all(
                color: prominent ? kAccentEmber : kHairline,
                width: 2,
              ),
            ),
            child: coverUrl == null
                ? TikTokThumbnailPlaceholder(
                    creatorHandle:
                        tiktokCreatorHandle(place.restaurant.videoUrl),
                  )
                : Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        TikTokThumbnailPlaceholder(
                      creatorHandle:
                          tiktokCreatorHandle(place.restaurant.videoUrl),
                    ),
                  ),
          ),
        ),
        Positioned(
          top: -8,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: kAccentEmber,
              borderRadius: BorderRadius.circular(kRadiusPill),
            ),
            child: Text(
              distance,
              style: const TextStyle(
                fontFamily: kTextFontFamily,
                fontSize: kNearbyDistanceFontSize,
                fontWeight: FontWeight.w700,
                color: kOnAccent,
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The "you are here" dot: an ember disc ringed in the background colour, with
/// a soft lava halo. Ringed rather than outlined, so it reads as a hole
/// punched through the map instead of a sticker laid on it.
class NearbyMeDot extends StatelessWidget {
  const NearbyMeDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'You are here',
      child: Center(
        child: Container(
          width: kNearbyMeDotSize,
          height: kNearbyMeDotSize,
          decoration: BoxDecoration(
            color: kAccentEmber,
            shape: BoxShape.circle,
            border: Border.all(
              color: kBackgroundDark,
              width: kNearbyMeDotBorder,
            ),
            boxShadow: const [
              BoxShadow(
                color: kNearbyMeHalo,
                spreadRadius: kNearbyMeHaloSpread,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
