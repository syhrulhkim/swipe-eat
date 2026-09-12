import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/tiktok_thumbnail_placeholder.dart';
import '../../../core/ui/progress_dots.dart';
import '../data/tiktok_player_factory.dart';
import '../domain/opening_hours.dart';
import '../models/restaurant_card.dart';
import 'tiktok_player.dart';

/// One restaurant as a full-bleed card: its clip or photos behind, and low
/// over the scrim the design's info block — the fact chips, the name, and a
/// line of distance, neighbourhood and price.
///
/// The card carries no buttons. The action bar is the deck's, below the
/// cards, so the card is the same surface whether it is on top or behind.
class SwipeCard extends StatefulWidget {
  const SwipeCard({
    super.key,
    required this.data,
    required this.distanceText,
    required this.onTap,
    required this.onOpenDetail,
    this.tiktokPlayerFuture,
    this.videoLent = false,
    this.autoplay = true,
    this.onPlay,
    this.isBehind = false,
    this.clock = OpeningHours.kualaLumpurNow,
  });

  final RestaurantCard data;
  final String distanceText;

  /// A tap on the clip: the fullscreen player.
  final VoidCallback onTap;

  /// A tap on the info block: the restaurant's own screen.
  final VoidCallback onOpenDetail;

  final Future<TikTokPlayerHandle>? tiktokPlayerFuture;

  /// True while another screen holds this card's player. One controller
  /// cannot be mounted in two `WebView`s, so the card falls back to its photo
  /// for as long as the detail screen has it — the same trade the detail hero
  /// makes for the fullscreen route (D150).
  final bool videoLent;

  /// Whether the clip may start on its own (D146). False shows the card's
  /// photo under a play button instead; the deck only warms a player once
  /// [onPlay] has been pressed, so "off" costs no WebView at all.
  final bool autoplay;

  /// Pressed on that play button. Null when the card has no clip to play.
  final VoidCallback? onPlay;

  final bool isBehind;

  /// What time it is in Kuala Lumpur, for the "open now" chip. Injected so a
  /// test can pin it; see [OpeningHours.kualaLumpurNow] for why not the
  /// device clock.
  final DateTime Function() clock;

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  int _imageIndex = 0;
  Offset? _imagePointerStart;
  bool _imagePointerMoved = false;

  @override
  void dispose() {
    // A swiped-away card is gone from the screen, but its player is not gone
    // from the cache — it is held warm for four more swipes. Unmuted, that is
    // a clip nobody can see still making noise, so the sound goes off with
    // the card.
    unawaited(widget.tiktokPlayerFuture?.then((h) => h.setMuted(true)));
    super.dispose();
  }

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
    final cardVideoUrl = widget.data.videoUrl;
    final showsPhotos = widget.isBehind ||
        cardVideoUrl == null ||
        cardVideoUrl.isEmpty;
    final hasMultipleImages = showsPhotos && widget.data.imageUrls.length > 1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(kRadiusCard),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: kSurfaceDark,
            borderRadius: BorderRadius.circular(kRadiusCard),
            boxShadow: kCardShadow,
          ),
          // The hairline goes in *front* of the media, not behind it. A
          // background border is painted before the child, and the clip fills
          // the card to its outer edge, so the photo covered the outline
          // everywhere — most visibly at the corners, where the card looked
          // like it had no edge at all.
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadiusCard),
            border: Border.all(color: kHairline),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: _buildMedia()),
              // The design's `.video::after`: a light wash at the top so the
              // muted hint reads, and the deep one at the bottom under the
              // info block.
              const PhotoTopScrim(height: 120),
              const PhotoBottomScrim(height: 360),
              if (hasMultipleImages)
                Positioned(
                  top: 14,
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
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: RestaurantInfoBlock(
                  data: widget.data,
                  distanceText: widget.distanceText,
                  now: widget.clock(),
                  onTap: widget.onOpenDetail,
                ),
              ),
              // Last child, so the hint is in front of the top scrim rather
              // than under 72% black — and in front of every other layer for
              // hit testing, which is the whole point of a control the user
              // has to be able to find and press. The clip starts silent
              // (D89); tapping this reloads it with TikTok's own sound on.
              if (_showsVideo)
                Positioned(
                  left: 16,
                  top: 16,
                  child: MutedHint(player: widget.tiktokPlayerFuture),
                ),
              // Same corner, same reasons, for the card whose clip is not
              // playing because the user said so (D146).
              if (_offersPlay)
                Positioned(
                  left: 16,
                  top: 16,
                  child: PlayHint(onTap: widget.onPlay),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Whether this card is showing a clip — the front card, with a video.
  bool get _hasVideo =>
      widget.data.videoUrl != null && widget.data.videoUrl!.isNotEmpty;

  bool get _showsVideo =>
      !widget.isBehind && !widget.videoLent && widget.autoplay && _hasVideo;

  /// The front card, holding a clip nobody has asked to play yet (D146).
  bool get _offersPlay =>
      !widget.isBehind && !widget.videoLent && !widget.autoplay && _hasVideo;

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
        if (_showsVideo && videoUrl != null) {
          // The player itself takes no taps: a WebView would eat the swipe.
          // The sound hint is not here — it lives at the top of the card's
          // own stack, in front of the scrim rather than washed out under it.
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
            duration: kMotionDuration,
            switchInCurve: kMotionEase,
            switchOutCurve: kMotionEase,
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

/// The design's `.info`: fact chips, the name, then distance · neighbourhood
/// and the price. Sits low over the scrim; a tap opens the restaurant.
class RestaurantInfoBlock extends StatelessWidget {
  const RestaurantInfoBlock({
    super.key,
    required this.data,
    required this.distanceText,
    required this.now,
    required this.onTap,
  });

  final RestaurantCard data;
  final String distanceText;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final openLabel = data.hours.statusLabel(now);
    final isOpen = data.hours.isOpenAt(now) ?? false;
    final priceLabel = data.priceLabel;
    final neighbourhood = data.neighbourhood;

    final tags = <Widget>[
      // Only the open state is worth a chip: "closed" on a card you are being
      // dealt is a reason to skip, and the meta line already says when.
      if (isOpen && openLabel != null) AppTagChip.fresh(label: openLabel),
      if (data.tag.trim().isNotEmpty) AppTagChip(label: data.tag),
      if (data.isHalal == true) const AppTagChip(label: 'Halal'),
    ];

    // Read what is shown, no more and no less: the open chip only while it is
    // painted, and the cuisine and halal chips the sighted user gets too.
    return Semantics(
      button: true,
      label: [
        data.title,
        if (isOpen && openLabel != null) openLabel,
        if (data.tag.trim().isNotEmpty) data.tag,
        if (data.isHalal == true) 'Halal',
        distanceText,
        if (neighbourhood != null) neighbourhood,
        if (priceLabel != null) priceLabel,
      ].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tags.isNotEmpty) ...[
              Wrap(spacing: 6, runSpacing: 6, children: tags),
              const SizedBox(height: 8),
            ],
            Text(
              data.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: kDisplayFontFamily,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 0.98,
                letterSpacing: -0.85,
                color: kTextOnPhoto,
              ),
            ),
            const SizedBox(height: 6),
            _MetaLine(
              distanceText: distanceText,
              neighbourhood: neighbourhood,
              priceLabel: priceLabel,
            ),
          ],
        ),
      ),
    );
  }
}

/// `<b>1.2 km</b> · Kampung Baru   <b>From RM 8</b>` — the design's `.meta`.
class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.distanceText,
    required this.neighbourhood,
    required this.priceLabel,
  });

  final String distanceText;
  final String? neighbourhood;
  final String? priceLabel;

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(
      fontFamily: kTextFontFamily,
      fontSize: kFontSizeSmall,
      fontWeight: FontWeight.w400,
      color: kTextOnPhotoSecondary,
      height: 1.3,
    );
    const strong = TextStyle(
      fontWeight: FontWeight.w600,
      color: kTextOnPhoto,
    );

    return Row(
      children: [
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: distanceText, style: strong),
                if (neighbourhood != null) TextSpan(text: ' · $neighbourhood'),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        ),
        if (priceLabel != null) ...[
          const SizedBox(width: 10),
          // Flexible too, or the price takes its full width first and the
          // distance span is left with less than nothing at large text.
          Flexible(
            child: Text(
              priceLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: muted.merge(strong),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Ngap!" or "Skip", rubber-stamped across the top corner as the card drags.
///
/// Painted by the deck over the top card, not by the card itself: the deck's
/// fly-out ticks without rebuilding the card (it hosts a WebView), so a stamp
/// inside the card would freeze at the release value.
class SwipeStamp extends StatelessWidget {
  const SwipeStamp({
    super.key,
    required this.label,
    required this.color,
    required this.angle,
    required this.opacity,
  });

  final String label;
  final Color color;

  /// Degrees. The design tilts Ngap! to the left and Skip to the right.
  final double angle;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: angle * 3.141592653589793 / 180,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: kDisplayFontFamily,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.56,
                  color: color,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
