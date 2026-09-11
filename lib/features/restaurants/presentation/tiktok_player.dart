import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/ui/design_tokens.dart';
import '../data/tiktok_player_factory.dart';

/// How the clip is fitted into the box it is given.
enum TikTokFraming {
  /// The swipe card: the clip covers the box, nudged down so its subject
  /// clears the title block.
  card,

  /// The detail hero: the same nudge, but no cover. The hero is barely taller
  /// than it is wide, and covering a 9:16 clip in that box crops it to a
  /// two-times zoom on the middle.
  hero,

  /// The fullscreen route: TikTok's own player, untouched.
  fullscreen,
}

/// How far down the box the clip is nudged, as a fraction of its height, so
/// the clip's subject clears the title block.
const double _kShift = 0.07;

/// What the clip must be scaled by to fill [constraints] after that nudge.
///
/// TikTok's player letterboxes: it fits a 9:16 clip inside whatever box it is
/// given and pads the rest black. On a card that is not exactly 9:16 that
/// padding shows as bars, and the nudge exposes more of it along the top, so
/// the scale is computed from the fitted size rather than guessed.
@visibleForTesting
double tikTokFramingScale(BoxConstraints constraints, TikTokFraming framing) {
  final width = constraints.maxWidth;
  final height = constraints.maxHeight;
  if (framing != TikTokFraming.card ||
      width <= 0 ||
      height <= 0 ||
      !width.isFinite ||
      !height.isFinite) {
    // The hero keeps the hand-picked nudge-and-a-hair it has always had.
    return 1.03;
  }

  const clipAspect = 9 / 16;
  final fittedWidth = math.min(width, height * clipAspect);
  final fittedHeight = math.min(height, width / clipAspect);

  return math.max(
    width / fittedWidth,
    (1 + (2 * _kShift)) * height / fittedHeight,
  );
}

/// TikTok's player filling its slot, with the card's framing on top.
///
/// [playerFuture] lets the deck hand over a warmed player; without one the
/// view builds its own.
class TikTokPlayerView extends StatefulWidget {
  const TikTokPlayerView({
    super.key,
    required this.videoUrl,
    this.framing = TikTokFraming.card,
    this.playerFuture,
  });

  final String videoUrl;

  /// How the clip is fitted into the slot — see [TikTokFraming].
  final TikTokFraming framing;

  final Future<TikTokPlayerHandle>? playerFuture;

  @override
  State<TikTokPlayerView> createState() => _TikTokPlayerViewState();
}

class _TikTokPlayerViewState extends State<TikTokPlayerView> {
  late Future<TikTokPlayerHandle> _playerFuture;

  @override
  void initState() {
    super.initState();
    _playerFuture = widget.playerFuture ?? createTikTokPlayer(widget.videoUrl);
  }

  @override
  void didUpdateWidget(TikTokPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The deck reuses this state across cards when the key allows it, so a new
    // video or a newly warmed player has to replace the old future rather than
    // leave the previous clip on screen.
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.playerFuture != widget.playerFuture) {
      _playerFuture =
          widget.playerFuture ?? createTikTokPlayer(widget.videoUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TikTokPlayerHandle>(
      future: _playerFuture,
      builder: (context, snapshot) {
        final handle = snapshot.data;

        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                if (handle != null)
                  ClipRect(
                    child: widget.framing != TikTokFraming.fullscreen
                        ? Transform.translate(
                            offset: Offset(0, constraints.maxHeight * _kShift),
                            child: Transform.scale(
                              scale: tikTokFramingScale(
                                constraints,
                                widget.framing,
                              ),
                              alignment: Alignment.center,
                              child: SizedBox.expand(
                                child: WebViewWidget(
                                  controller: handle.controller,
                                ),
                              ),
                            ),
                          )
                        : SizedBox.expand(
                            child: WebViewWidget(controller: handle.controller),
                          ),
                  ),
                if (widget.framing != TikTokFraming.fullscreen)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 138,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.96),
                              Colors.black.withValues(alpha: 0.84),
                              Colors.black.withValues(alpha: 0.58),
                              Colors.black.withValues(alpha: 0.26),
                              Colors.black.withValues(alpha: 0.00),
                            ],
                            stops: const [0.0, 0.16, 0.40, 0.72, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (snapshot.connectionState != ConnectionState.done)
                  const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (handle == null)
                  // The player could not even be built — no WebView is coming,
                  // so without this the card would sit on a bare black
                  // rectangle.
                  const _PlayerUnavailable()
                else
                  // Built, but the page can still fail underneath it: no
                  // network, or a clip TikTok has pulled. The handle reports
                  // that after the future is long done.
                  _PlayerStatusOverlay(handle: handle),
              ],
            );
          },
        );
      },
    );
  }
}

/// Covers the player while its page is failing, and offers another go.
class _PlayerStatusOverlay extends StatelessWidget {
  const _PlayerStatusOverlay({required this.handle});

  final TikTokPlayerHandle handle;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TikTokPlayerStatus>(
      valueListenable: handle.status,
      builder: (context, status, _) {
        if (status != TikTokPlayerStatus.failed) {
          return const SizedBox.shrink();
        }

        return ColoredBox(
          color: Colors.black,
          child: _PlayerUnavailable(
            onRetry: () => unawaited(handle.load()),
          ),
        );
      },
    );
  }
}

class _PlayerUnavailable extends StatelessWidget {
  const _PlayerUnavailable({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final onRetry = this.onRetry;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Video unavailable',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: kAccentEmber),
              child: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

/// The clip on its own, filling the screen.
class TikTokPlayerScreen extends StatelessWidget {
  const TikTokPlayerScreen({
    super.key,
    required this.videoUrl,
    this.playerFuture,
  });

  final String videoUrl;

  /// The caller's warmed player, so opening fullscreen does not start a second
  /// copy of the same video playing behind the first. The screen underneath
  /// hides its own WebView while this route is up: one controller cannot be
  /// mounted twice.
  final Future<TikTokPlayerHandle>? playerFuture;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            TikTokPlayerView(
              key: ValueKey(videoUrl),
              videoUrl: videoUrl,
              framing: TikTokFraming.fullscreen,
              playerFuture: playerFuture,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topRight,
                  child: AppIconButton(
                    icon: Icons.close_rounded,
                    size: kUtilityButtonSize,
                    background: Colors.black.withValues(alpha: 0.48),
                    // A WebView platform view cannot be blurred by a
                    // BackdropFilter, so don't pay for one.
                    onPhoto: false,
                    semanticLabel: 'Close player',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Says the clip is playing without sound, and turns it on.
///
/// The tap reloads the player unmuted (D89, amended). It always swallows the
/// tap, even before [player] resolves: the hint sits on the card, and letting
/// the tap fall through would open the restaurant instead of doing what the
/// pill says.
class MutedHint extends StatelessWidget {
  const MutedHint({super.key, this.player});

  final Future<TikTokPlayerHandle>? player;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TikTokPlayerHandle>(
      future: player,
      builder: (context, snapshot) {
        final handle = snapshot.data;
        if (handle == null) {
          return const _MutedHintButton(muted: true);
        }

        return ValueListenableBuilder<bool>(
          valueListenable: handle.muted,
          builder: (context, muted, _) {
            return _MutedHintButton(
              muted: muted,
              onTap: () => unawaited(handle.setMuted(!muted)),
            );
          },
        );
      },
    );
  }
}

/// "Tap to play" — the same pill, for a card whose clip is not playing because
/// the user turned autoplay off, or is on mobile data with Wi-Fi-only chosen
/// (D146).
///
/// The same shape and the same corner as [MutedHint] on purpose: it occupies
/// the slot the sound control will occupy the moment the clip starts, so the
/// card does not rearrange itself under the thumb that just pressed it.
class PlayHint extends StatelessWidget {
  const PlayHint({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Tap to play',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap ?? () {},
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: kSurfaceDark.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(kRadiusPill),
            border: Border.all(color: kHairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                size: 16,
                color: kTextOnPhoto,
              ),
              const SizedBox(width: 7),
              Text(
                'Tap to play',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: kTextOnPhoto,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MutedHintButton extends StatelessWidget {
  const _MutedHintButton({required this.muted, this.onTap});

  final bool muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // The pill's own words are the label; without this they are announced
      // twice.
      excludeSemantics: true,
      label: muted ? 'Tap for sound' : 'Mute',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap ?? () {},
        child: Container(
          // Sized as a control, not as a caption: at the old 13 px glyph and
          // 5 px padding the pill was 24 px tall — under any sane thumb, on a
          // card whose every other pixel means "swipe me".
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            // Solid rather than the 35% wash the other on-photo chips use: it
            // sits over a moving clip that can go white at any frame.
            color: kSurfaceDark.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(kRadiusPill),
            border: Border.all(
              // Ember once the sound is on, so the state is readable at a
              // glance and not only by reading the word.
              color: muted ? kHairline : kAccentEmber,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                size: 16,
                color: muted ? kTextOnPhoto : kAccentEmber,
              ),
              const SizedBox(width: 7),
              Text(
                muted ? 'Tap for sound' : 'Sound on',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: muted ? kTextOnPhoto : kAccentEmber,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
