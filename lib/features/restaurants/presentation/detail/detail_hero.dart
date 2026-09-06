import 'package:flutter/material.dart';

import '../../../../core/ui/app_spacing.dart';
import '../../../../core/ui/design_tokens.dart';
import '../../../../core/ui/tiktok_thumbnail_placeholder.dart';
import '../../data/tiktok_player_factory.dart';
import '../tiktok_player.dart';

/// The top two fifths of the restaurant screen: the clip (or the first photo,
/// or the placeholder), the design's two scrims, the floating topbar, and low
/// over the deep end of the scrim the title block.
///
/// The whole hero is one tap target for the fullscreen player — the design's
/// `.video .tag` promises sound, and sound only exists in TikTok's own player
/// (D4/D89), so the tap has to reach it from anywhere on the clip.
class DetailHero extends StatelessWidget {
  const DetailHero({
    super.key,
    required this.title,
    required this.tags,
    required this.metaLine,
    required this.videoUrl,
    required this.imageUrl,
    required this.bitten,
    required this.onOpenPlayer,
    required this.leading,
    required this.trailing,
    this.playerFuture,
    this.videoHiddenForFullscreen = false,
  });

  final String title;

  /// The cuisine, and "Halal" when the caption said so. Empty renders nothing.
  final List<String> tags;

  /// "Kampung Baru · 1.2 km · open till 2 am", already assembled and already
  /// missing whatever is unknown. Empty renders nothing.
  final String metaLine;

  final String? videoUrl;
  final String? imageUrl;

  /// The bite: this place is already ngap'd.
  final bool bitten;

  /// Null when there is no clip to open, which is also what hides the hint.
  final VoidCallback? onOpenPlayer;

  final Widget leading;
  final Widget trailing;

  final Future<TikTokPlayerHandle>? playerFuture;

  /// True while the fullscreen route holds the player. One controller cannot
  /// be mounted in two WebViews, so the hero falls back to its photo — the
  /// same trade the deck's card makes.
  final bool videoHiddenForFullscreen;

  bool get _showsVideo =>
      !videoHiddenForFullscreen && videoUrl != null && videoUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final open = onOpenPlayer;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Only the media and its scrims are bitten. Biting the whole hero
        // would clip the topbar's buttons out of the corner along with it.
        BiteNotch(
          borderRadius: BorderRadius.zero,
          bitten: bitten,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: _buildMedia()),
              const PhotoTopScrim(height: 150),
              const PhotoBottomScrim(height: 300),
            ],
          ),
        ),
        if (open != null)
          Positioned.fill(
            child: Semantics(
              label: 'Watch TikTok review',
              button: true,
              // Excluding drops the tap action with the children's semantics,
              // so it is re-declared here (D83).
              excludeSemantics: true,
              onTap: open,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: open,
              ),
            ),
          ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: _TitleBlock(title: title, tags: tags, metaLine: metaLine),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              // The design's `.topbar{top:var(--s3)}`, under the status bar.
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [leading, trailing],
                  ),
                  // The prototype puts its `.tag` at the same height as the
                  // back button, where the two would collide. Under the bar
                  // instead — same corner, nothing overlapping.
                  if (_showsVideo) ...[
                    const SizedBox(height: AppSpacing.xs),
                    const IgnorePointer(child: MutedHint()),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedia() {
    final url = videoUrl;
    if (_showsVideo) {
      return IgnorePointer(
        child: TikTokPlayerView(
          key: ValueKey(url),
          videoUrl: url!,
          playerFuture: playerFuture,
        ),
      );
    }

    final photo = imageUrl;
    if (photo == null || photo.isEmpty) {
      return TikTokThumbnailPlaceholder(
        creatorHandle: tiktokCreatorHandle(videoUrl),
      );
    }

    return Image.network(
      photo,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return TikTokThumbnailPlaceholder(
          creatorHandle: tiktokCreatorHandle(videoUrl),
        );
      },
    );
  }
}

/// Tags, the 36 px name, then neighbourhood · distance · open state.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    required this.tags,
    required this.metaLine,
  });

  final String title;
  final List<String> tags;
  final String metaLine;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tags.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in tags) AppTitleTagChip(label: tag),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: kDisplayFontFamily,
              fontSize: kFontSizeDetailTitle,
              fontWeight: FontWeight.w700,
              height: 1.05,
              letterSpacing: -0.72,
              color: kTextOnPhoto,
            ),
          ),
          if (metaLine.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              metaLine,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: kTextFontFamily,
                fontSize: kFontSizeSmall,
                fontWeight: FontWeight.w400,
                color: kTextOnPhotoSecondary,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Says the clip is playing without sound, and where to get it.
///
/// The same hint the swipe card carries, in the same words: the tap does not
/// unmute the clip, it opens the player that can. Duplicated rather than
/// shared because the card's copy is private to `swipe_card.dart`.
class MutedHint extends StatelessWidget {
  const MutedHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kFillOnPhoto,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: kHairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.volume_off_rounded,
            size: 13,
            color: kTextOnPhotoMuted,
          ),
          const SizedBox(width: 6),
          Text(
            'Tap for sound',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: kTextOnPhotoMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
