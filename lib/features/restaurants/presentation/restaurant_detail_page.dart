import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/open_directions.dart';
import '../../../core/location/place_name.dart';
import '../../../core/location/user_position_state.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/glass_ui.dart';
import '../../../core/ui/rating_label.dart';
import '../../../core/ui/tiktok_thumbnail_placeholder.dart';
import '../models/restaurant_detail_data.dart';
import '../state/likes_controller.dart';
import 'tiktok_player.dart';

/// One restaurant in full: hero photo, the facts, its location and its top
/// review.
class RestaurantDetailPage extends StatefulWidget {
  const RestaurantDetailPage({
    super.key,
    required this.data,
  });

  final RestaurantDetailData data;

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage>
    with UserPositionState {
  int _heroIndex = 0;
  final GlobalKey _locationKey = GlobalKey();
  final GlobalKey _reviewKey = GlobalKey();
  String? _placeName;

  bool get _liked => LikesController.instance.isLiked(widget.data.id);

  @override
  void initState() {
    super.initState();
    loadUserPosition();
    unawaited(_resolvePlaceName());
    LikesController.instance.addListener(_onLikesChanged);
    // Best-effort: an unreachable backend leaves the heart empty, and the
    // toggle below surfaces its own error if the user then taps it.
    LikesController.instance.ensureLoaded().catchError((Object error) {
      debugPrint('Likes load failed: $error');
    });
  }

  @override
  void dispose() {
    LikesController.instance.removeListener(_onLikesChanged);
    super.dispose();
  }

  void _onLikesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _resolvePlaceName() async {
    final name = await resolvePlaceNameForCoordinates(
      widget.data.latitude,
      widget.data.longitude,
    );
    if (!mounted || name == null) {
      return;
    }
    setState(() {
      _placeName = name;
    });
  }

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

  Future<void> _toggleLike() async {
    final likes = LikesController.instance;
    try {
      if (likes.isLiked(widget.data.id)) {
        await likes.unlike(widget.data.id, source: 'detail');
      } else {
        await likes.like(widget.data.id, source: 'detail');
      }
    } on Object catch (error) {
      debugPrint('Like toggle failed: $error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that change.')),
      );
    }
  }

  String _distanceLabel() {
    final position = userPosition;
    if (position == null) {
      return 'Distance loading';
    }

    if (!hasMapFix(widget.data.latitude, widget.data.longitude)) {
      // Measuring to the 0,0 sentinel reports the distance to Null Island,
      // which reads as a real answer.
      return 'Distance unknown';
    }

    final meters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      widget.data.latitude,
      widget.data.longitude,
    );

    if (meters >= 100000) {
      return '100km +';
    }

    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km away';
    }

    return '${meters.toStringAsFixed(0)} m away';
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) {
      return;
    }

    unawaited(
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      ),
    );
  }

  Widget _heroPlaceholder() {
    return TikTokThumbnailPlaceholder(
      creatorHandle: tiktokCreatorHandle(widget.data.videoUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = widget.data.imageUrls;
    final heroIndex =
        imageUrls.isEmpty ? 0 : _heroIndex.clamp(0, imageUrls.length - 1);
    final heroUrl = imageUrls.isEmpty ? null : imageUrls[heroIndex];
    final videoUrl = widget.data.videoUrl;

    return Scaffold(
      backgroundColor: kBackgroundDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Hero image pinned behind the scrolling content.
          Positioned.fill(
            child: heroUrl == null
                ? _heroPlaceholder()
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: SizedBox.expand(
                      key: ValueKey(heroUrl),
                      child: Image.network(
                        heroUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _heroPlaceholder();
                        },
                      ),
                    ),
                  ),
          ),
          const PhotoWash(),
          const PhotoTopScrim(),
          const PhotoBottomScrim(),
          SingleChildScrollView(
            child: Column(
              children: [
                _buildHeroPane(context, videoUrl),
                _buildDetails(context),
              ],
            ),
          ),
          _buildTopControls(context, imageUrls, heroIndex, videoUrl),
        ],
      ),
    );
  }

  /// The first screenful: name, distance, chips and the round action buttons,
  /// sized to the viewport so the details start exactly below the fold.
  Widget _buildHeroPane(BuildContext context, String? videoUrl) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          child: Column(
            children: [
              const Spacer(),
              Text.rich(
                TextSpan(
                  text: widget.data.title,
                  style: glassTitleStyle(context),
                  children: [
                    if (ratingLabel(widget.data.rating) != '–')
                      TextSpan(
                        text: '  ${ratingLabel(widget.data.rating)}',
                        style: glassTitleMutedStyle(context),
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
                      _distanceLabel(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: glassPlaceStyle(context),
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
                  if (ratingLabel(widget.data.rating) != '–')
                    GlassChip(
                      icon: Icons.star_rounded,
                      label: ratingLabel(widget.data.rating),
                    ),
                  if (widget.data.tag.isNotEmpty)
                    GlassChip(
                      icon: Icons.local_dining_rounded,
                      label: widget.data.tag,
                    ),
                  if (videoUrl != null && videoUrl.isNotEmpty)
                    const GlassChip(
                      icon: Icons.music_note_rounded,
                      label: 'TikTok Review',
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GlassCircleButton(
                    icon: Icons.favorite_rounded,
                    iconColor: _liked ? kAccentLime : kTextOnPhoto,
                    semanticLabel: _liked ? 'Liked' : 'Like',
                    onTap: () => unawaited(_toggleLike()),
                  ),
                  GlassCircleButton(
                    icon: Icons.chat_bubble_rounded,
                    semanticLabel: 'Reviews',
                    onTap: () => _scrollToSection(_reviewKey),
                  ),
                  GlassCircleButton(
                    icon: Icons.route_rounded,
                    semanticLabel: 'Location',
                    onTap: () => _scrollToSection(_locationKey),
                  ),
                  GlassCircleButton(
                    icon: Icons.close_rounded,
                    semanticLabel: 'Close',
                    onTap: () => unawaited(Navigator.of(context).maybePop()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    return Container(
      width: double.infinity,
      color: kBackgroundDark,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        20,
        AppSpacing.screenPadding,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.data.details,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 16),
          if (widget.data.imageUrls.isNotEmpty) ...[
            _DetailCard(
              title: 'More photos',
              child: Column(
                children: widget.data.imageUrls
                    .map(
                      (imageUrl) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(kRadiusThumb),
                          child: AspectRatio(
                            aspectRatio: 1.7,
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return TikTokThumbnailPlaceholder(
                                  creatorHandle: tiktokCreatorHandle(
                                    widget.data.videoUrl,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          KeyedSubtree(
            key: _locationKey,
            child: _DetailCard(
              title: 'Location',
              child: _buildLocationBody(context),
            ),
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: _reviewKey,
            child: _DetailCard(
              title: 'Top review',
              child: _buildReviewBody(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBody(BuildContext context) {
    final hasFix = hasMapFix(widget.data.latitude, widget.data.longitude);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_pin, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_placeName != null) ...[
                    Text(
                      _placeName!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    hasFix
                        ? '${_distanceLabel()} from your location'
                        : 'No location on file for this place',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (hasFix) ...[
          const SizedBox(height: 12),
          _DirectionsButton(onTap: () => unawaited(_openDirections())),
        ],
      ],
    );
  }

  Widget _buildReviewBody(BuildContext context) {
    if (widget.data.reviewText.isEmpty) {
      return Text(
        'No reviews yet',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.66),
            ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.data.reviewName,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.68),
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.data.reviewText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                height: 1.35,
              ),
        ),
      ],
    );
  }

  /// Fixed top controls: back, photo switcher, video.
  ///
  /// Positioned rather than a plain Stack child: StackFit.expand would stretch
  /// this row to the full screen height, centring the controls vertically and
  /// letting the invisible row swallow drags meant for the scroll view
  /// underneath.
  Widget _buildTopControls(
    BuildContext context,
    List<String> imageUrls,
    int heroIndex,
    String? videoUrl,
  ) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              GlassCircleButton(
                icon: Icons.arrow_back_rounded,
                size: kUtilityButtonSize,
                background: Colors.black.withValues(alpha: 0.34),
                semanticLabel: 'Back',
                onTap: () => unawaited(Navigator.of(context).maybePop()),
              ),
              Expanded(
                child: imageUrls.length > 1
                    ? Center(
                        child: _HeroThumbnailStrip(
                          imageUrls: imageUrls,
                          activeIndex: heroIndex,
                          onSelected: (index) {
                            setState(() {
                              _heroIndex = index;
                            });
                          },
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (videoUrl != null && videoUrl.isNotEmpty)
                GlassCircleButton(
                  icon: Icons.play_arrow_rounded,
                  size: kUtilityButtonSize,
                  background: Colors.black.withValues(alpha: 0.34),
                  semanticLabel: 'Watch TikTok review',
                  onTap: () {
                    unawaited(
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              TikTokPlayerScreen(videoUrl: videoUrl),
                        ),
                      ),
                    );
                  },
                )
              else
                const SizedBox(width: kUtilityButtonSize),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top-center photo switcher from the reference design: a frosted pill of
/// mini thumbnails; the active one gets an accent ring.
class _HeroThumbnailStrip extends StatelessWidget {
  const _HeroThumbnailStrip({
    required this.imageUrls,
    required this.activeIndex,
    required this.onSelected,
  });

  final List<String> imageUrls;
  final int activeIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final visible = imageUrls.length > 5 ? imageUrls.sublist(0, 5) : imageUrls;

    // Five 36px thumbnails need ~216px, more than the slot between the back
    // and play buttons on a 320pt-wide phone. Shrink the pill to fit instead
    // of overflowing it off the right edge.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: _pill(visible),
    );
  }

  Widget _pill(List<String> visible) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusPill),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: kGlassBlurSigma,
          sigmaY: kGlassBlurSigma,
        ),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(kRadiusPill),
            border: Border.all(color: kGlassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < visible.length; i++)
                Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                  // Matches _StripThumb on the Like tab: screen readers need
                  // to know these photo swatches are buttons.
                  child: Semantics(
                    label: 'Photo ${i + 1} of ${visible.length}',
                    button: true,
                    selected: i == activeIndex,
                    child: GestureDetector(
                      onTap: () => onSelected(i),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(kRadiusPill),
                          border: Border.all(
                            color: i == activeIndex
                                ? kAccentLime
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            visible[i],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const ColoredBox(
                                color: kGlassFill,
                                child: Icon(
                                  Icons.image_not_supported_rounded,
                                  color: Colors.white54,
                                  size: 16,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionsButton extends StatelessWidget {
  const _DirectionsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: kAccentLime,
        borderRadius: BorderRadius.circular(kRadiusPill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusPill),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.directions_rounded,
                  size: 18,
                  color: kOnAccentLime,
                ),
                const SizedBox(width: 8),
                // Flexible, or a large accessibility text scale pushes the
                // label past the button's edge instead of ellipsising.
                Flexible(
                  child: Text(
                    'Get directions',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: kOnAccentLime,
                          fontWeight: FontWeight.w700,
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
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfacePanel,
        borderRadius: BorderRadius.circular(kRadiusPanel),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: glassPanelTitleStyle(context)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
