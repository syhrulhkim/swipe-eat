import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/ui/design_tokens.dart';
import '../data/tiktok_player_factory.dart';

/// TikTok's player filling its slot, with the card's framing on top.
///
/// [playerFuture] lets the deck hand over a warmed player; without one the
/// view builds its own.
class TikTokPlayerView extends StatefulWidget {
  const TikTokPlayerView({
    super.key,
    required this.videoUrl,
    this.applyCardFraming = true,
    this.playerFuture,
  });

  final String videoUrl;

  /// Nudges and scales the player so the clip's subject clears the card's
  /// title block. The fullscreen route turns it off.
  final bool applyCardFraming;

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
                    child: widget.applyCardFraming
                        ? Transform.translate(
                            offset: Offset(0, constraints.maxHeight * 0.07),
                            child: Transform.scale(
                              scale: 1.03,
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
                if (widget.applyCardFraming)
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

  /// The deck's warmed player, so opening fullscreen does not start a second
  /// copy of the same video playing behind the first. The card hides its own
  /// WebView while this route is up: one controller cannot be mounted twice.
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
              applyCardFraming: false,
              playerFuture: playerFuture,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topRight,
                  child: AppCircleButton(
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
