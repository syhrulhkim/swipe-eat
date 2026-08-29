import 'package:flutter/material.dart';

import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/rating_label.dart';
import '../../../core/ui/tiktok_thumbnail_placeholder.dart';
import '../../restaurants/models/restaurant.dart';

/// Like tab from the reference design: the most recent liked restaurant
/// full-bleed, a frosted top strip of the other liked spots to switch
/// between, big centred name with muted rating, location line, chips, and a
/// row of frosted action circles.
class LikesTabView extends StatefulWidget {
  const LikesTabView({
    super.key,
    required this.liked,
    required this.distanceLabel,
    required this.onOpenRestaurant,
    required this.onUnlike,
  });

  /// Liked restaurants, newest first.
  final List<Restaurant> liked;
  final String Function(Restaurant restaurant) distanceLabel;
  final void Function(Restaurant restaurant) onOpenRestaurant;
  final void Function(Restaurant restaurant) onUnlike;

  @override
  State<LikesTabView> createState() => _LikesTabViewState();
}

class _LikesTabViewState extends State<LikesTabView> {
  /// The selected restaurant is tracked by id, not index: unliking an entry
  /// above the selection shifts every index below it, which would silently
  /// swap the hero to a different restaurant. Null means "the newest".
  int? _selectedId;

  @override
  Widget build(BuildContext context) {
    if (widget.liked.isEmpty) {
      return const _EmptyLikes();
    }

    final selectedId = _selectedId;
    var selectedIndex = selectedId == null
        ? -1
        : widget.liked.indexWhere((r) => r.id == selectedId);
    if (selectedIndex < 0) {
      // Never selected, or the selection was just unliked: fall back to newest.
      selectedIndex = 0;
    }
    final restaurant = widget.liked[selectedIndex];
    final rating = ratingLabel(restaurant.rating);
    final heroUrl =
        restaurant.imageUrls.isEmpty ? null : restaurant.imageUrls.first;

    return Stack(
      fit: StackFit.expand,
      children: [
        heroUrl == null
            ? TikTokThumbnailPlaceholder(
                creatorHandle: tiktokCreatorHandle(restaurant.videoUrl),
              )
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: SizedBox.expand(
                  key: ValueKey('${restaurant.id}-$heroUrl'),
                  child: Image.network(
                    heroUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return TikTokThumbnailPlaceholder(
                        creatorHandle: tiktokCreatorHandle(restaurant.videoUrl),
                      );
                    },
                  ),
                ),
              ),
        const PhotoWash(),
        const PhotoTopScrim(),
        const PhotoBottomScrim(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              children: [
                if (widget.liked.length > 1)
                  _LikedThumbnailStrip(
                    liked: widget.liked,
                    activeIndex: selectedIndex,
                    onSelected: (index) {
                      setState(() {
                        _selectedId = widget.liked[index].id;
                      });
                    },
                  ),
                const Spacer(),
                Text.rich(
                  TextSpan(
                    text: restaurant.name,
                    style: appTitleStyle(context),
                    children: [
                      if (rating != '–')
                        TextSpan(
                          text: '  $rating',
                          style: appTitleMutedStyle(context),
                        ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.place_rounded,
                      color: kTextOnPhotoSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        widget.distanceLabel(restaurant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appPlaceStyle(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (restaurant.tag.isNotEmpty)
                      AppChip(
                        icon: Icons.local_dining_rounded,
                        label: restaurant.tag,
                      ),
                    if (rating != '–')
                      AppChip(icon: Icons.star_rounded, label: rating),
                    if (restaurant.videoUrl != null &&
                        restaurant.videoUrl!.isNotEmpty)
                      const AppChip(
                        icon: Icons.music_note_rounded,
                        label: 'TikTok Review',
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    AppCircleButton(
                      icon: Icons.favorite_rounded,
                      size: kActionButtonSize,
                      iconColor: kAccentEmber,
                      semanticLabel: 'Liked',
                      onTap: () => widget.onUnlike(restaurant),
                    ),
                    AppCircleButton(
                      icon: Icons.chat_bubble_rounded,
                      size: kActionButtonSize,
                      badgeCount: restaurant.reviews.length,
                      semanticLabel: 'Reviews',
                      onTap: () => widget.onOpenRestaurant(restaurant),
                    ),
                    AppCircleButton(
                      icon: Icons.route_rounded,
                      size: kActionButtonSize,
                      semanticLabel: 'Details',
                      onTap: () => widget.onOpenRestaurant(restaurant),
                    ),
                    AppCircleButton(
                      icon: Icons.close_rounded,
                      size: kActionButtonSize,
                      semanticLabel: 'Remove from likes',
                      onTap: () => widget.onUnlike(restaurant),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LikedThumbnailStrip extends StatelessWidget {
  const _LikedThumbnailStrip({
    required this.liked,
    required this.activeIndex,
    required this.onSelected,
  });

  final List<Restaurant> liked;
  final int activeIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final count = liked.length > 5 ? 5 : liked.length;
    // Keep the active restaurant visible even when it sits past the first 5.
    final visibleIndices = <int>[
      for (var i = 0; i < count; i++) i,
    ];
    if (!visibleIndices.contains(activeIndex)) {
      visibleIndices[visibleIndices.length - 1] = activeIndex;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusPill),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(kRadiusPill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < visibleIndices.length; i++)
              Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                child: _StripThumb(
                  restaurant: liked[visibleIndices[i]],
                  active: visibleIndices[i] == activeIndex,
                  onTap: () => onSelected(visibleIndices[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StripThumb extends StatelessWidget {
  const _StripThumb({
    required this.restaurant,
    required this.active,
    required this.onTap,
  });

  final Restaurant restaurant;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: Colors.white.withValues(alpha: 0.10),
      child: const Icon(
        Icons.restaurant_rounded,
        color: Colors.white54,
        size: 16,
      ),
    );

    return Semantics(
      label: restaurant.name,
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? kAccentEmber : Colors.transparent,
              width: 2,
            ),
          ),
          child: ClipOval(
            child: restaurant.imageUrls.isEmpty
                ? fallback
                : Image.network(
                    restaurant.imageUrls.first,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => fallback,
                  ),
          ),
        ),
      ),
    );
  }
}

class _EmptyLikes extends StatelessWidget {
  const _EmptyLikes();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white38,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No likes yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Swipe right on restaurants you love and they will show up here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
