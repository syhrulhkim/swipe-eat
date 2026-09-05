import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_lottie.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/empty_state.dart';
import '../../auth/state/auth_controller.dart';
import '../domain/meal_label.dart';
import '../models/restaurant_card.dart';
import '../models/restaurant_detail_data.dart';
import '../state/deck_controller.dart';
import 'discovery_filter_sheet.dart';
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

  /// The clip the fullscreen route is currently showing, if any. The card
  /// underneath must not mount the same controller at the same time.
  String? _fullscreenVideoUrl;
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

  void _animateOut({required bool liked, bool later = false}) {
    final card = _deck.current;
    if (card == null || _motionType != _SwipeMotionType.idle) {
      return;
    }

    // Optimistic: the card flies out immediately and the write follows behind
    // it.
    unawaited(_deck.recordSwipe(card, liked: liked, later: later));

    setState(() {
      _motionType = _SwipeMotionType.swipeOut;
      _animationStartOffset = _dragOffset;
      // Later flies up, off the top — its gesture's direction.
      _animationEndOffset =
          later ? const Offset(0, -900) : Offset(liked ? 460 : -460, -220);
    });

    _motionController.forward(from: 0);
  }

  /// A tap on Skip / Ngap / Later, which starts from a resting card rather
  /// than a drag, so it nudges the card first to give the fly-out a direction.
  void _triggerAction({required bool liked, bool later = false}) {
    if (_deck.current == null || _motionType != _SwipeMotionType.idle) {
      return;
    }

    setState(() {
      _motionController.stop();
      _motionType = _SwipeMotionType.idle;
      _dragOffset = later ? const Offset(0, -14) : Offset(liked ? 14 : -14, -1);
    });

    _animateOut(liked: liked, later: later);
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
          // Popping resolves this future as the reverse transition starts, so
          // the card remounts the player while a fading fullscreen route still
          // holds it — the two-mounts-one-controller state this handover
          // exists to avoid. Leaving on the same frame keeps them exclusive.
          reverseTransitionDuration: Duration.zero,
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
    // During a fly-out the travel may be vertical (super like), so the frame
    // measures full distance; a drag measures dx only, because vertical drag
    // alone must not read as swipe progress.
    final travel = _motionType == _SwipeMotionType.swipeOut
        ? offset.distance
        : offset.dx.abs();
    final dragPercentage = (travel / 260).clamp(0.0, 1.0);

    return _MotionFrame(
      progress: progress,
      offset: offset,
      dragPercentage: dragPercentage,
      lift: Curves.easeOutCubic.transform(dragPercentage),
    );
  }

  Future<void> _openFilters() {
    return showDiscoveryFilterSheet(context, deck: _deck);
  }

  /// The info block's tap: the restaurant's own screen, handed the card so it
  /// paints before the row is refetched.
  void _openDetail(RestaurantCard card) {
    context.push('/restaurant/${card.id}', extra: card.toDetailPayload());
  }

  Widget _buildActionBar() {
    return DeckActionBar(
      onPass: () => _triggerAction(liked: false),
      onLike: () => _triggerAction(liked: true),
      onLater: () => _triggerAction(liked: true, later: true),
    );
  }

  DeckHeader _buildHeader() {
    return DeckHeader(
      locationLabel: _deck.locationLabel,
      radiusKm: widget.authController.user?.searchRadiusKm,
      mealLabel: mealLabel(DateTime.now()),
      stalenessLabel: _deck.stalenessLabel,
      activeFilterCount:
          widget.authController.user?.activeFilterCount ?? 0,
      onFilterTap: () => unawaited(_openFilters()),
    );
  }

  // Keeps the header above the loading/error/empty states so those states
  // aren't a bare widget on an otherwise blank tab.
  Widget _deckMessage(Widget child) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: Center(child: child)),
      ],
    );
  }

  Widget _messageCard({
    required String eyebrow,
    required String title,
    required String subtitle,
    required String actionLabel,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
    AppMotion? art,
  }) {
    return _deckMessage(
      AppEmptyState(
        eyebrow: eyebrow,
        title: title,
        message: subtitle,
        actionLabel: actionLabel,
        onAction: () => unawaited(_deck.load()),
        secondaryActionLabel: secondaryActionLabel,
        onSecondaryAction: onSecondaryAction,
        // Played once, not looped: the state is standing still, and art that
        // keeps moving on it reads as work in progress.
        art: art == null
            ? null
            : AppLottie(motion: art, size: 96, repeat: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _deck,
      builder: (context, _) {
        return _buildDeck(context);
      },
    );
  }

  Widget _buildDeck(BuildContext context) {
    if (_deck.loading) {
      return _deckMessage(const AppLottie(motion: AppMotion.spinner, size: 72));
    }

    final deckError = _deck.error;
    if (deckError != null) {
      return _messageCard(
        eyebrow: 'Deck stalled',
        title: 'Something went wrong',
        subtitle: deckError,
        actionLabel: 'Try again',
      );
    }

    if (_deck.cards.isEmpty) {
      return _messageCard(
        eyebrow: 'Nothing dealt',
        title: 'No restaurants yet',
        subtitle: 'Check back soon.',
        actionLabel: 'Reload',
        art: AppMotion.pin,
      );
    }

    final current = _deck.current;
    if (current == null) {
      // Not a local replay: every card in the deck is already swiped
      // server-side, so replaying it would fight `get_deck`'s exclusion. A
      // reload lets the backend deal fresh rows — or resurface old passes via
      // its 3-day exhaustion fallback.
      return _messageCard(
        eyebrow: 'That is everyone',
        title: 'No more cards',
        subtitle: 'Reload to keep swiping.',
        actionLabel: 'Reload deck',
        art: AppMotion.heart,
      );
    }

    final next = _deck.next;
    // The design's swipe screen, top to bottom: the location header, the
    // deck, the three actions. The card is a rounded surface inside the
    // screen padding, not a full-bleed one under the status bar.
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (next != null)
                  Positioned.fill(child: _buildBehindCard(next)),
                Positioned.fill(child: _buildTopCard(current)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildActionBar(),
        const SizedBox(height: 4),
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
        distanceText: _deck.distanceLabelFor(next),
        onTap: () => unawaited(_openVideoPlayer(next)),
        onOpenDetail: () => _openDetail(next),
        tiktokPlayerFuture: _deck.players.warm(next.videoUrl),
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

  Widget _buildTopCard(RestaurantCard current) {
    final gesturesLocked = _motionType != _SwipeMotionType.idle;

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
              // Up-swipe saves the place for later. Checked first, and only
              // when the drag is not already a committed left/right.
              if (_dragOffset.dy < -140 && _dragOffset.dx.abs() < 110) {
                _animateOut(liked: true, later: true);
                return;
              }

              if (_dragOffset.dx > 110) {
                _animateOut(liked: true);
                return;
              }

              if (_dragOffset.dx < -110) {
                _animateOut(liked: false);
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

          // The stamps live here, not in the card: this builder ticks every
          // frame while the card (a WebView host) is built once as `child`.
          final likeOpacity =
              frame.offset.dx > 20 ? frame.dragPercentage : 0.0;
          final nopeOpacity =
              frame.offset.dx < -20 ? frame.dragPercentage : 0.0;

          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: frame.offset,
              child: Transform.rotate(
                angle: frame.offset.dx / 900,
                child: Transform.scale(
                  scale: scale,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      child!,
                      Positioned(
                        top: 26,
                        right: 22,
                        child: SwipeStamp(
                          label: 'Ngap!',
                          color: kAccentEmber,
                          angle: -12,
                          opacity: likeOpacity,
                        ),
                      ),
                      Positioned(
                        top: 26,
                        left: 22,
                        child: SwipeStamp(
                          label: 'Skip',
                          color: kAccentCream,
                          angle: 12,
                          opacity: nopeOpacity,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        child: SwipeCard(
          key: ValueKey(current.id),
          data: current,
          distanceText: _deck.distanceLabelFor(current),
          onTap: () => unawaited(_openVideoPlayer(current)),
          onOpenDetail: () => _openDetail(current),
          tiktokPlayerFuture: _deck.players.warm(current.videoUrl),
          videoHiddenForFullscreen: _fullscreenVideoUrl != null &&
              _fullscreenVideoUrl == current.videoUrl,
        ),
      ),
    );
  }
}

/// The design's three-button bar under the deck: a ghost Skip, the Ngap
/// button, a ghost Later, centred as equals around the one that matters.
///
/// Three, not five. Rewind and the super-like star are gone with the features
/// behind them — the design has neither, and a control for a feature that no
/// longer exists is worse than a missing one.
class DeckActionBar extends StatelessWidget {
  const DeckActionBar({
    super.key,
    required this.onPass,
    required this.onLike,
    required this.onLater,
  });

  final VoidCallback onPass;
  final VoidCallback onLike;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIconButton(
          icon: Icons.close_rounded,
          size: kActionButtonSize,
          iconSize: 22,
          onPhoto: false,
          background: kSurfaceDark,
          semanticLabel: 'Skip',
          onTap: onPass,
        ),
        const SizedBox(width: 20),
        AppNgapButton(onTap: onLike),
        const SizedBox(width: 20),
        // A clock, not a bookmark: "later" here is about when you eat, not
        // about filing the place away.
        AppIconButton(
          icon: Icons.schedule_rounded,
          size: kActionButtonSize,
          iconSize: 22,
          onPhoto: false,
          background: kSurfaceDark,
          semanticLabel: 'Save for later',
          onTap: onLater,
        ),
      ],
    );
  }
}

/// The deck's top bar, the design's `.topbar`: where the user is with the
/// radius and the meal under it, and the filters button.
class DeckHeader extends StatelessWidget {
  const DeckHeader({
    super.key,
    required this.locationLabel,
    this.radiusKm,
    this.mealLabel,
    this.stalenessLabel,
    this.activeFilterCount = 0,
    this.onFilterTap,
  });

  /// The user's reverse-geocoded whereabouts, from the profile row — not a
  /// hardcoded town.
  final String locationLabel;

  /// The search radius from Settings; null means no limit.
  final int? radiusKm;

  /// "dinner", "lunch" — the meal the hour is closest to.
  final String? mealLabel;

  /// Set when the deck came off the device instead of the server. Shown under
  /// the location so saved cards are never mistaken for fresh ones.
  final String? stalenessLabel;

  /// How many discovery filters are on — the badge on the filter button.
  final int activeFilterCount;

  /// Opens the discovery filter sheet. Null hides the button.
  final VoidCallback? onFilterTap;

  String get _subline {
    final parts = <String>[
      radiusKm == null ? 'any distance' : 'within $radiusKm km',
      if (mealLabel != null) mealLabel!,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 18, color: kAccentCream),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: kTextFontFamily,
                          fontSize: kFontSizeBody,
                          fontWeight: FontWeight.w600,
                          color: kAccentCream,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        _subline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: kTextFontFamily,
                          fontSize: kFontSizeMicro,
                          fontWeight: FontWeight.w400,
                          color: kCreamSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onFilterTap != null) ...[
                  const SizedBox(width: 8),
                  AppIconButton(
                    icon: Icons.tune_rounded,
                    size: kUtilityButtonSize,
                    iconSize: 20,
                    onPhoto: false,
                    background: kGlass,
                    semanticLabel: 'Filters',
                    badgeCount: activeFilterCount,
                    onTap: onFilterTap!,
                  ),
                ],
              ],
            ),
            if (stalenessLabel != null) ...[
              const SizedBox(height: 10),
              AppChip(
                icon: Icons.cloud_off_rounded,
                label: stalenessLabel!,
                onPhoto: false,
              ),
            ],
          ],
        ),
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
