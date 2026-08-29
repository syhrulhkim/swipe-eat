import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/glass_ui.dart';
import '../../../core/ui/rating_label.dart';
import '../../auth/state/auth_controller.dart';
import '../models/restaurant_card.dart';
import '../state/deck_controller.dart';
import 'swipe_card.dart';
import 'tiktok_player.dart';

/// The card deck: one restaurant at a time, swiped right to like and left to
/// pass.
///
/// The widget owns the drag and the fly-out animation; everything else — which
/// cards exist, which is on top, what a swipe writes — belongs to
/// [DeckController].
class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.authController,
    this.controller,
  });

  final AuthController authController;

  /// Injected by tests; in the app the deck builds its own.
  final DeckController? controller;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck>
    with SingleTickerProviderStateMixin {
  late final DeckController _deck =
      widget.controller ?? DeckController(authController: widget.authController);
  late final bool _ownsController = widget.controller == null;
  StreamSubscription<String>? _messages;

  Offset _dragOffset = Offset.zero;
  bool _infoExpanded = false;

  /// The clip the fullscreen route is currently showing, if any. The card
  /// underneath must not mount the same controller at the same time.
  String? _fullscreenVideoUrl;
  bool _reviewInteractionActive = false;
  Offset _animationStartOffset = Offset.zero;
  Offset _animationEndOffset = Offset.zero;
  _SwipeMotionType _motionType = _SwipeMotionType.idle;

  late final AnimationController _motionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  )..addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) {
        return;
      }

      if (_motionType == _SwipeMotionType.swipeOut) {
        _deck.advance();
      }

      setState(() {
        _dragOffset = Offset.zero;
        _infoExpanded = false;
        _reviewInteractionActive = false;
        _motionType = _SwipeMotionType.idle;
      });

      _motionController.reset();
    });

  @override
  void initState() {
    super.initState();
    _messages = _deck.messages.listen(_showMessage);
    if (_ownsController) {
      unawaited(_deck.load());
    }
  }

  @override
  void dispose() {
    unawaited(_messages?.cancel());
    _motionController.dispose();
    if (_ownsController) {
      _deck.dispose();
    }
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _animateOut(bool liked) {
    final card = _deck.current;
    if (card == null || _motionType != _SwipeMotionType.idle) {
      return;
    }

    // Optimistic: the card flies out immediately and the write follows behind
    // it.
    unawaited(_deck.recordSwipe(card, liked: liked));

    setState(() {
      _motionType = _SwipeMotionType.swipeOut;
      _animationStartOffset = _dragOffset;
      _animationEndOffset = Offset(liked ? 460 : -460, -220);
    });

    _motionController.forward(from: 0);
  }

  /// A tap on the pass/like button, which starts from a resting card rather
  /// than a drag, so it nudges the card first to give the fly-out a direction.
  void _triggerAction(bool liked) {
    if (_deck.current == null || _motionType != _SwipeMotionType.idle) {
      return;
    }

    setState(() {
      _motionController.stop();
      _motionType = _SwipeMotionType.idle;
      _dragOffset = Offset(liked ? 14 : -14, -1);
    });

    _animateOut(liked);
  }

  Future<void> _openVideoPlayer(RestaurantCard data) async {
    final videoUrl = data.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty || !mounted) {
      return;
    }

    // The card hands its player over rather than letting the route build a
    // second one: two controllers on the same clip means the same audio twice,
    // and one controller cannot be mounted in two WebViews at once.
    setState(() {
      _fullscreenVideoUrl = videoUrl;
    });

    try {
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: true,
          barrierDismissible: false,
          pageBuilder: (context, animation, secondaryAnimation) {
            return TikTokPlayerScreen(
              videoUrl: videoUrl,
              playerFuture: _deck.players.warm(videoUrl),
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
        ),
      );
    } finally {
      // Whatever closed the route — the button, a back gesture, a failure on
      // the way in — the card takes its player back.
      if (mounted) {
        setState(() {
          _fullscreenVideoUrl = null;
        });
      }
    }
  }

  /// Card pose for the frame being painted.
  ///
  /// [_motionController] ticks without calling `setState`, so these values MUST
  /// be read inside an [AnimatedBuilder] listening to it. Deriving them once in
  /// `build` freezes the card at its release pose for the whole 640 ms and then
  /// teleports it.
  _MotionFrame _motionFrame() {
    final progress = Curves.easeInOutCubic.transform(_motionController.value);
    final offset = _motionType == _SwipeMotionType.idle
        ? _dragOffset
        : ui.Offset.lerp(
              _animationStartOffset,
              _animationEndOffset,
              progress,
            ) ??
            _dragOffset;
    final dragPercentage = (offset.dx.abs() / 260).clamp(0.0, 1.0);

    return _MotionFrame(
      progress: progress,
      offset: offset,
      dragPercentage: dragPercentage,
      lift: Curves.easeOutCubic.transform(dragPercentage),
    );
  }

  void _setReviewInteractionActive(bool active) {
    if (_reviewInteractionActive == active) {
      return;
    }

    setState(() {
      _reviewInteractionActive = active;
    });
  }

  // Keeps the floating header visible around the loading/error/empty states
  // so those states aren't a bare widget on an otherwise blank tab.
  Widget _deckMessage(Widget child) {
    return Stack(
      children: [
        Center(child: child),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: DeckHeader(locationLabel: _deck.locationLabel),
        ),
      ],
    );
  }

  Widget _messageCard({
    required String title,
    required String subtitle,
    required String actionLabel,
  }) {
    return _deckMessage(
      Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: FCard(
          title: Text(title),
          subtitle: Text(subtitle),
          child: FButton(
            variant: FButtonVariant.outline,
            onPress: () => unawaited(_deck.load()),
            child: Text(actionLabel),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _deck,
      builder: (context, _) => _buildDeck(context),
    );
  }

  Widget _buildDeck(BuildContext context) {
    if (_deck.loading) {
      return _deckMessage(const CircularProgressIndicator(strokeWidth: 2));
    }

    final deckError = _deck.error;
    if (deckError != null) {
      return _messageCard(
        title: 'Something went wrong',
        subtitle: deckError,
        actionLabel: 'Try again',
      );
    }

    if (_deck.cards.isEmpty) {
      return _messageCard(
        title: 'No restaurants yet',
        subtitle: 'Check back soon.',
        actionLabel: 'Reload',
      );
    }

    final current = _deck.current;
    if (current == null) {
      // Not a local replay: every card in the deck is already swiped
      // server-side, so replaying it would fight `get_deck`'s exclusion. A
      // reload lets the backend deal fresh rows — or resurface old passes via
      // its 3-day exhaustion fallback.
      return _messageCard(
        title: 'No more cards',
        subtitle: 'Reload to keep swiping.',
        actionLabel: 'Reload deck',
      );
    }

    final next = _deck.next;
    final motion = _motionFrame();

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (next != null) Positioned.fill(child: _buildBehindCard(next)),
              Positioned.fill(child: _buildTopCard(current, motion)),
            ],
          ),
        ),
        // Painted above the card so the settings button stays tappable; the
        // gradient itself ignores pointers so card gestures pass through the
        // top 300px.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: DeckHeader(locationLabel: _deck.locationLabel),
        ),
      ],
    );
  }

  Widget _buildBehindCard(RestaurantCard next) {
    return AnimatedBuilder(
      animation: _motionController,
      // The card itself is passed as `child` so it is built once, not on every
      // tick — it can host a WebView.
      child: SwipeCard(
        key: ValueKey(next.id),
        data: next,
        isBehind: true,
        infoExpanded: _infoExpanded,
        ratingText: ratingLabel(next.rating),
        distanceText: _deck.distanceLabelFor(next),
        onTap: () => unawaited(_openVideoPlayer(next)),
        tiktokPlayerFuture: _deck.players.warm(next.videoUrl),
        onInfoTap: () {
          setState(() {
            _infoExpanded = !_infoExpanded;
          });
        },
        onReviewInteractionChanged: _setReviewInteractionActive,
      ),
      builder: (context, child) {
        final lift = _motionFrame().lift;

        return Opacity(
          opacity: 0.82 + (lift * 0.18),
          child: Transform.translate(
            offset: Offset(0, 22 - (lift * 22)),
            child: Transform.scale(
              scale: 0.92 + (lift * 0.08),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopCard(RestaurantCard current, _MotionFrame motion) {
    final gesturesLocked =
        _motionType != _SwipeMotionType.idle || _reviewInteractionActive;

    return GestureDetector(
      onPanStart: gesturesLocked ? null : (_) => _deck.warmUpcomingPlayers(),
      onPanUpdate: gesturesLocked
          ? null
          : (details) {
              setState(() {
                if (_dragOffset == Offset.zero) {
                  _deck.warmUpcomingPlayers();
                }
                _motionController.stop();
                _motionType = _SwipeMotionType.idle;
                _dragOffset += details.delta;
              });
            },
      onPanEnd: gesturesLocked
          ? null
          : (details) {
              if (_dragOffset.dx > 110) {
                _animateOut(true);
                return;
              }

              if (_dragOffset.dx < -110) {
                _animateOut(false);
                return;
              }

              setState(() {
                _motionType = _SwipeMotionType.settleBack;
                _animationStartOffset = _dragOffset;
                _animationEndOffset = Offset.zero;
                _motionController.forward(from: 0);
                _dragOffset = Offset.zero;
              });
            },
      child: AnimatedBuilder(
        animation: _motionController,
        builder: (context, child) {
          // Read live from the controller: values captured in build() would
          // hold still for the whole animation.
          final frame = _motionFrame();
          final scale = _motionType == _SwipeMotionType.swipeOut
              ? ui.lerpDouble(1, 0.982, frame.progress) ?? 1
              : ui.lerpDouble(1, 0.995, frame.progress) ?? 1;
          final opacity = _motionType == _SwipeMotionType.swipeOut
              ? ui.lerpDouble(1, 0.84, frame.progress) ?? 1
              : 1.0;

          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: frame.offset,
              child: Transform.rotate(
                angle: frame.offset.dx / 900,
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              ),
            ),
          );
        },
        child: SwipeCard(
          key: ValueKey(current.id),
          data: current,
          likeOpacity: motion.offset.dx > 20 ? motion.dragPercentage : 0,
          nopeOpacity: motion.offset.dx < -20 ? motion.dragPercentage : 0,
          infoExpanded: _infoExpanded,
          ratingText: ratingLabel(current.rating),
          distanceText: _deck.distanceLabelFor(current),
          onTap: () => unawaited(_openVideoPlayer(current)),
          tiktokPlayerFuture: _deck.players.warm(current.videoUrl),
          videoHiddenForFullscreen: _fullscreenVideoUrl != null &&
              _fullscreenVideoUrl == current.videoUrl,
          onInfoTap: () {
            setState(() {
              _infoExpanded = !_infoExpanded;
            });
          },
          onReviewInteractionChanged: _setReviewInteractionActive,
          onPass: () => _triggerAction(false),
          onLike: () => _triggerAction(true),
        ),
      ),
    );
  }
}

/// The deck's top chrome: where the user is, and the way into Settings, over a
/// gradient that keeps both legible against any clip.
class DeckHeader extends StatelessWidget {
  const DeckHeader({super.key, required this.locationLabel});

  /// The user's reverse-geocoded whereabouts, from the profile row — not a
  /// hardcoded town.
  final String locationLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.90),
                      Colors.black.withValues(alpha: 0.82),
                      Colors.black.withValues(alpha: 0.66),
                      Colors.black.withValues(alpha: 0.46),
                      Colors.black.withValues(alpha: 0.30),
                      Colors.black.withValues(alpha: 0.16),
                      Colors.black.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.09, 0.20, 0.34, 0.50, 0.68, 0.86, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, left: 16, right: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassChip(
                    icon: Icons.place_rounded,
                    label: locationLabel,
                  ),
                  GlassCircleButton(
                    icon: Icons.settings_rounded,
                    size: kUtilityButtonSize,
                    iconSize: 20,
                    background: Colors.black.withValues(alpha: 0.34),
                    semanticLabel: 'Settings',
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _SwipeMotionType {
  idle,
  settleBack,
  swipeOut,
}

/// One frame of swipe motion: see `_SwipeDeckState._motionFrame`.
class _MotionFrame {
  const _MotionFrame({
    required this.progress,
    required this.offset,
    required this.dragPercentage,
    required this.lift,
  });

  /// Eased 0..1 position through the settle-back / swipe-out animation.
  final double progress;

  /// Where the top card sits relative to its resting position.
  final Offset offset;

  /// How far towards a committed swipe the card is, 0..1.
  final double dragPercentage;

  /// Eased [dragPercentage], used to raise the card behind into place.
  final double lift;
}
