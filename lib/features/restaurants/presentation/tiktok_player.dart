import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/ui/glass_ui.dart';
import '../data/tiktok_player_factory.dart';

/// TikTok's player filling its slot, with the card's framing on top.
///
/// [controllerFuture] lets the deck hand over a warmed controller; without one
/// the view builds its own, which is what the fullscreen route does.
class TikTokPlayerView extends StatefulWidget {
  const TikTokPlayerView({
    super.key,
    required this.videoUrl,
    this.applyCardFraming = true,
    this.controllerFuture,
  });

  final String videoUrl;

  /// Nudges and scales the player so the clip's subject clears the card's
  /// title block. The fullscreen route turns it off.
  final bool applyCardFraming;

  final Future<WebViewController>? controllerFuture;

  @override
  State<TikTokPlayerView> createState() => _TikTokPlayerViewState();
}

class _TikTokPlayerViewState extends State<TikTokPlayerView> {
  late Future<WebViewController> _controllerFuture;

  @override
  void initState() {
    super.initState();
    _controllerFuture = widget.controllerFuture ??
        createTikTokPlayerController(widget.videoUrl);
  }

  @override
  void didUpdateWidget(TikTokPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The deck reuses this state across cards when the key allows it, so a new
    // video or a newly warmed controller has to replace the old future rather
    // than leave the previous clip on screen.
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.controllerFuture != widget.controllerFuture) {
      _controllerFuture = widget.controllerFuture ??
          createTikTokPlayerController(widget.videoUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WebViewController>(
      future: _controllerFuture,
      builder: (context, snapshot) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData)
                  ClipRect(
                    child: widget.applyCardFraming
                        ? Transform.translate(
                            offset: Offset(0, constraints.maxHeight * 0.07),
                            child: Transform.scale(
                              scale: 1.03,
                              alignment: Alignment.center,
                              child: SizedBox.expand(
                                child: WebViewWidget(
                                  controller: snapshot.data!,
                                ),
                              ),
                            ),
                          )
                        : SizedBox.expand(
                            child: WebViewWidget(
                              controller: snapshot.data!,
                            ),
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
                else if (snapshot.hasError)
                  // The spinner is gone but no WebView arrived, so without
                  // this the card would sit on a bare black rectangle.
                  Center(
                    child: Text(
                      'Video unavailable',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// The clip on its own, filling the screen.
class TikTokPlayerScreen extends StatelessWidget {
  const TikTokPlayerScreen({
    super.key,
    required this.videoUrl,
    this.controllerFuture,
  });

  final String videoUrl;

  /// The deck's warmed controller, so opening fullscreen does not start a
  /// second copy of the same video playing behind the first.
  final Future<WebViewController>? controllerFuture;

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
              controllerFuture: controllerFuture,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topRight,
                  child: GlassCircleButton(
                    icon: Icons.close_rounded,
                    size: kUtilityButtonSize,
                    background: Colors.black.withValues(alpha: 0.48),
                    // A WebView platform view cannot be blurred by a
                    // BackdropFilter, so don't pay for one.
                    frosted: false,
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
