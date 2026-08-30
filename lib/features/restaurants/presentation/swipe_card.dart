import 'package:flutter/material.dart';
import '../../../core/location/open_directions.dart';
import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/tiktok_thumbnail_placeholder.dart';
import '../data/tiktok_player_factory.dart';
import '../models/restaurant_card.dart';
import 'review_carousel.dart';
import 'tiktok_player.dart';

/// One restaurant as a full-bleed card: its clip or photos behind, its name,
/// rating and distance in a panel at the bottom.
class SwipeCard extends StatefulWidget {
  const SwipeCard({
    super.key,
    required this.data,
    required this.infoExpanded,
    required this.ratingText,
    required this.distanceText,
    required this.onTap,
    required this.onInfoTap,
    required this.onReviewInteractionChanged,
    this.tiktokPlayerFuture,
    this.videoHiddenForFullscreen = false,
    this.onPass,
    this.onLike,
    this.onSuperLike,
    this.onRewind,
    this.isBehind = false,
    this.likeOpacity = 0,
    this.nopeOpacity = 0,
  });

  final RestaurantCard data;
  final bool infoExpanded;
  final String ratingText;
  final String distanceText;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;
  final ValueChanged<bool> onReviewInteractionChanged;
  final Future<TikTokPlayerHandle>? tiktokPlayerFuture;

  /// True while the fullscreen route holds this card's player. One controller
  /// cannot be mounted in two WebViews at once, so the card gives it up and
  /// falls back to its photos until the route closes.
  final bool videoHiddenForFullscreen;

  /// Absent on the card behind: it must never act on the deck while the top
  /// card is the one being dragged.
  final VoidCallback? onPass;
  final VoidCallback? onLike;

  /// The Tinder extras. [onSuperLike] follows the same rule as [onPass];
  /// [onRewind] is null both on the card behind and when there is nothing
  /// swiped yet to take back — the button then renders dimmed and inert.
  final VoidCallback? onSuperLike;
  final VoidCallback? onRewind;

  final bool isBehind;
  final double likeOpacity;
  final double nopeOpacity;

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  int _imageIndex = 0;
  Offset? _imagePointerStart;
  bool _imagePointerMoved = false;

  @override
  void didUpdateWidget(covariant SwipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.id != widget.data.id) {
      _imageIndex = 0;
    }
  }

  void _changeImage(int delta) {
    final nextIndex =
        (_imageIndex + delta).clamp(0, widget.data.imageUrls.length - 1);
    if (nextIndex == _imageIndex) {
      return;
    }

    setState(() {
      _imageIndex = nextIndex;
    });
  }

  void _handleImageTap(Offset localPosition, double width) {
    if (widget.data.imageUrls.length <= 1) {
      return;
    }

    final isLeftSide = localPosition.dx < width / 2;
    _changeImage(isLeftSide ? -1 : 1);
  }

  @override
  Widget build(BuildContext context) {
    const bottomRadius = Radius.circular(kRadiusCard);
    final cardVideoUrl = widget.data.videoUrl;
    final showsPhotos = widget.isBehind ||
        widget.videoHiddenForFullscreen ||
        cardVideoUrl == null ||
        cardVideoUrl.isEmpty;
    final hasMultipleImages = showsPhotos && widget.data.imageUrls.length > 1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: bottomRadius,
            bottomRight: bottomRadius,
          ),
          child: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: bottomRadius,
                bottomRight: bottomRadius,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Square at the top (the card runs under the status-bar
                // scrim); only the outer bottom corners are rounded.
                Positioned.fill(
                  child: ClipRect(child: _buildMedia()),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 1.00),
                            Colors.black.withValues(alpha: 1.00),
                            Colors.black.withValues(alpha: 0.96),
                            Colors.black.withValues(alpha: 0.84),
                            Colors.black.withValues(alpha: 0.56),
                            Colors.black.withValues(alpha: 0.22),
                            Colors.black.withValues(alpha: 0.00),
                          ],
                          stops: const [0.0, 0.14, 0.28, 0.46, 0.70, 0.90, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                const PhotoBottomScrim(height: 360),
                if (hasMultipleImages)
                  Positioned(
                    top: 150,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: ProgressDots(
                          count: widget.data.imageUrls.length,
                          activeIndex: _imageIndex,
                          style: ProgressDotsStyle.photo,
                        ),
                      ),
                    ),
                  ),
                // The Figma's bottom panel: an opaque grey card carrying the
                // name, the rating block, the fact chips and — on the top
                // card — the action bar, all in one rounded surface.
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: AppSpacing.screenPadding + 2,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kSurfacePanel,
                      borderRadius: BorderRadius.circular(kRadiusSheet),
                      border: Border.all(color: kHairline),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RestaurantInfoPanel(
                          data: widget.data,
                          expanded: widget.infoExpanded,
                          ratingText: widget.ratingText,
                          distanceText: widget.distanceText,
                          onTap: widget.onInfoTap,
                          onReviewInteractionChanged:
                              widget.onReviewInteractionChanged,
                        ),
                        if (widget.onPass != null &&
                            widget.onLike != null) ...[
                          const SizedBox(height: 14),
                          Container(height: 1, color: kHairline),
                          const SizedBox(height: 14),
                          _buildActionBar(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The Figma's "✕ Pass | Like" bar, flanked by the two Tinder extras:
  /// rewind on the far left, the super-like star between the pills.
  Widget _buildActionBar() {
    final rewind = widget.onRewind;

    return Row(
      children: [
        // Inert-but-visible when there is nothing to take back, so the
        // control keeps its place in the bar instead of popping in after the
        // first swipe.
        IgnorePointer(
          ignoring: rewind == null,
          child: Opacity(
            opacity: rewind == null ? 0.4 : 1,
            child: AppCircleButton(
              icon: Icons.replay_rounded,
              size: kUtilityButtonSize,
              iconSize: 20,
              onPhoto: false,
              background: kSurfaceDark,
              semanticLabel: 'Rewind',
              onTap: rewind ?? () {},
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppSecondaryButton(
            label: 'Pass',
            icon: Icons.close_rounded,
            expand: true,
            onPressed: widget.onPass,
          ),
        ),
        const SizedBox(width: 10),
        AppCircleButton(
          icon: Icons.star_rounded,
          size: kUtilityButtonSize,
          iconSize: 22,
          iconColor: kAccentEmber,
          onPhoto: false,
          background: kSurfaceDark,
          semanticLabel: 'Must try',
          onTap: widget.onSuperLike ?? () {},
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppPrimaryButton(
            label: 'Like',
            icon: Icons.favorite_rounded,
            expand: true,
            onPressed: widget.onLike,
          ),
        ),
      ],
    );
  }

  /// The clip when the card has one and is on top, its photos otherwise.
  ///
  /// The card behind never gets a player: two WebViews on screen would fight
  /// over audio and cost a second platform view for a card the user cannot
  /// even read yet. The fullscreen route takes the player away for the same
  /// reason.
  Widget _buildMedia() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final videoUrl = widget.data.videoUrl;
        if (!widget.isBehind &&
            !widget.videoHiddenForFullscreen &&
            videoUrl != null &&
            videoUrl.isNotEmpty) {
          return IgnorePointer(
            child: TikTokPlayerView(
              key: ValueKey(videoUrl),
              videoUrl: videoUrl,
              playerFuture: widget.tiktokPlayerFuture,
            ),
          );
        }

        if (widget.data.imageUrls.isEmpty) {
          return TikTokThumbnailPlaceholder(
            creatorHandle: tiktokCreatorHandle(widget.data.videoUrl),
          );
        }

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            _imagePointerStart = event.localPosition;
            _imagePointerMoved = false;
          },
          onPointerMove: (event) {
            final start = _imagePointerStart;
            if (start == null || _imagePointerMoved) {
              return;
            }

            if ((event.localPosition - start).distance > 12) {
              _imagePointerMoved = true;
            }
          },
          onPointerUp: (event) {
            final start = _imagePointerStart;
            final moved = _imagePointerMoved;
            _imagePointerStart = null;
            _imagePointerMoved = false;

            if (start == null || moved) {
              return;
            }

            _handleImageTap(event.localPosition, constraints.maxWidth);
          },
          onPointerCancel: (_) {
            _imagePointerStart = null;
            _imagePointerMoved = false;
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: SizedBox.expand(
              key: ValueKey(widget.data.imageUrls[_imageIndex]),
              child: Image.network(
                widget.data.imageUrls[_imageIndex],
                fit: BoxFit.cover,
                alignment: Alignment.center,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return const SizedBox.expand(
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return SizedBox.expand(
                    child: TikTokThumbnailPlaceholder(
                      creatorHandle: tiktokCreatorHandle(widget.data.videoUrl),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The panel at the bottom of a card: category, name, rating, distance, and —
/// once expanded — the description and reviews.
class RestaurantInfoPanel extends StatefulWidget {
  const RestaurantInfoPanel({
    super.key,
    required this.data,
    required this.expanded,
    required this.ratingText,
    required this.distanceText,
    required this.onTap,
    required this.onReviewInteractionChanged,
  });

  final RestaurantCard data;
  final bool expanded;
  final String ratingText;
  final String distanceText;
  final VoidCallback onTap;
  final ValueChanged<bool> onReviewInteractionChanged;

  @override
  State<RestaurantInfoPanel> createState() => _RestaurantInfoPanelState();
}

class _RestaurantInfoPanelState extends State<RestaurantInfoPanel> {
  Future<void> _openDirections() async {
    final opened = await openDirections(
      latitude: widget.data.latitude,
      longitude: widget.data.longitude,
      label: widget.data.title,
    );
    if (opened || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open maps for this place.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Unrated restaurants render ratingLabel's '–', which would put a bare
    // dash in the rating block — the block only appears for real ratings.
    final hasRating = widget.ratingText.trim() != '–';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(kRadiusPanel),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: widget.expanded
                  ? _buildExpandedDetails(context)
                  : const SizedBox.shrink(),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: appTitleStyle(context),
                  ),
                ),
                if (hasRating) ...[
                  const SizedBox(width: 12),
                  _RatingBlock(ratingText: widget.ratingText),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Flexible(
                  child: AppChip(
                    icon: Icons.place_rounded,
                    label: widget.distanceText,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: AppChip(label: widget.data.tag),
                ),
                if (hasMapFix(widget.data.latitude, widget.data.longitude)) ...[
                  const SizedBox(width: 8),
                  // Its own tap target: the surrounding InkWell expands the
                  // panel, and leaving directions to that gesture would open
                  // maps every time the user peeked at the reviews.
                  Flexible(
                    child: GestureDetector(
                      onTap: _openDirections,
                      behavior: HitTestBehavior.opaque,
                      child: const AppChip(
                        label: 'Directions',
                        icon: Icons.directions_rounded,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  turns: widget.expanded ? 0.5 : 0,
                  child: Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white.withValues(alpha: 0.65),
                    size: 22,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedDetails(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadiusPanel),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            // Opaque rather than translucent: this panel carries paragraphs of
            // text over a moving video, and only a solid ground keeps them
            // readable frame to frame.
            color: kSurfaceDark,
            borderRadius: BorderRadius.circular(kRadiusPanel),
            border: Border.all(color: kHairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.data.details,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
              ),
              const SizedBox(height: 10),
              ReviewCarousel(
                reviews: widget.data.reviews,
                onInteractionChanged: widget.onReviewInteractionChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Figma's ember rating tile: the number large, "Google rating" under it
/// so the figure is never mistaken for a price or a distance.
class _RatingBlock extends StatelessWidget {
  const _RatingBlock({required this.ratingText});

  final String ratingText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kAccentEmber,
        borderRadius: BorderRadius.circular(kRadiusThumb),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ratingText,
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: kDisplayFontFamily,
              color: kOnAccent,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Google rating',
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              color: kOnAccent.withValues(alpha: 0.75),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
