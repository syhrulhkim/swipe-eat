import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/rating_label.dart';
import '../../../core/ui/tiktok_thumbnail_placeholder.dart';
import '../../restaurants/models/restaurant.dart';

/// Like tab: the most recent liked restaurant full-bleed, a top strip of the
/// other liked spots to switch between, then the same eyebrow / big name /
/// facts-strip / action-row stack the detail page uses, so moving between the
/// two reads as one screen scrolling rather than two designs.
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.liked.length > 1)
                  Center(
                    child: _LikedThumbnailStrip(
                      liked: widget.liked,
                      activeIndex: selectedIndex,
                      onSelected: (index) {
                        setState(() {
                          _selectedId = widget.liked[index].id;
                        });
                      },
                    ),
                  ),
                const Spacer(),
                if (restaurant.tag.isNotEmpty) ...[
                  AppEyebrow(label: restaurant.tag),
                  const SizedBox(height: 8),
                ],
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
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                AppStatStrip(
                  stats: [
                    AppStat(
                      label: 'Distance',
                      value: widget.distanceLabel(restaurant),
                    ),
                    if (rating != '–')
                      AppStat(label: 'Rating', value: rating),
                  ],
                ),
                if (restaurant.videoUrl != null &&
                    restaurant.videoUrl!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const AppChip(
                    icon: Icons.music_note_rounded,
                    label: 'TikTok Review',
                    tint: kAccentEmber,
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    AppCircleButton(
                      icon: Icons.favorite_rounded,
                      size: kActionButtonSize,
                      iconColor: kAccentEmber,
                      semanticLabel: 'Liked',
                      onTap: () => widget.onUnlike(restaurant),
                    ),
                    const SizedBox(width: 12),
                    AppCircleButton(
                      icon: Icons.chat_bubble_rounded,
                      size: kActionButtonSize,
                      badgeCount: restaurant.reviews.length,
                      semanticLabel: 'Reviews',
                      onTap: () => widget.onOpenRestaurant(restaurant),
                    ),
                    const SizedBox(width: 12),
                    AppCircleButton(
                      icon: Icons.route_rounded,
                      size: kActionButtonSize,
                      semanticLabel: 'Details',
                      onTap: () => widget.onOpenRestaurant(restaurant),
                    ),
                    const SizedBox(width: 12),
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
          color: kFillOnPhoto,
          borderRadius: BorderRadius.circular(kRadiusPill),
          border: Border.all(color: kHairline),
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
    return const AppEmptyState(
      eyebrow: 'Nothing saved',
      title: 'No likes yet',
      message:
          'Swipe right on restaurants you love and they will show up here.',
      art: Icon(Icons.favorite_rounded, color: kTextOnPhotoMuted, size: 40),
    );
  }
}
