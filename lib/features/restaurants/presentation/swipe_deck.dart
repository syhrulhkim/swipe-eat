import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/open_directions.dart';
import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_lottie.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/rating_label.dart';
import '../../../core/ui/tiktok_thumbnail_placeholder.dart';
import '../../auth/state/auth_controller.dart';
import '../models/restaurant_card.dart';
import '../state/deck_controller.dart';
import '../state/visit_prompt_controller.dart';
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
  bool _infoExpanded = false;

  /// Drives the intermittent match moment on ordinary likes.
  final math.Random _random = math.Random();

  /// Decided when the fly-out starts, published to [_matchCard] when it
  /// finishes — the overlay must not appear over a card still in flight.
  RestaurantCard? _pendingMatchCard;
  bool _pendingMatchSuper = false;

  /// The restaurant the match overlay is celebrating, if it is up.
  RestaurantCard? _matchCard;
  bool _matchIsSuper = false;

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
        if (_pendingMatchCard != null) {
          _matchCard = _pendingMatchCard;
          _matchIsSuper = _pendingMatchSuper;
          _pendingMatchCard = null;
        }
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

  void _animateOut({required bool liked, bool superLike = false}) {
    final card = _deck.current;
    if (card == null ||
        _motionType != _SwipeMotionType.idle ||
        _deck.outOfSwipes) {
      return;
    }

    // Optimistic: the card flies out immediately and the write follows behind
    // it.
    unawaited(_deck.recordSwipe(card, liked: liked, superLike: superLike));

    // A super like always earns the moment — it is the emphatic yes. An
    // ordinary like gets it roughly one time in four: Tinder does not stop
    // the flow on every right-swipe, and neither should the deck.
    final celebrate = superLike || (liked && _random.nextInt(4) == 0);
    _pendingMatchCard = celebrate ? card : null;
    _pendingMatchSuper = superLike;

    setState(() {
      _motionType = _SwipeMotionType.swipeOut;
      _animationStartOffset = _dragOffset;
      // A super like flies up, off the top — its gesture's direction.
      _animationEndOffset =
          superLike ? const Offset(0, -900) : Offset(liked ? 460 : -460, -220);
    });

    _motionController.forward(from: 0);
  }

  /// A tap on the pass/like/super-like button, which starts from a resting
  /// card rather than a drag, so it nudges the card first to give the fly-out
  /// a direction.
  void _triggerAction({required bool liked, bool superLike = false}) {
    if (_deck.current == null ||
        _motionType != _SwipeMotionType.idle ||
        _deck.outOfSwipes) {
      return;
    }

    setState(() {
      _motionController.stop();
      _motionType = _SwipeMotionType.idle;
      _dragOffset =
          superLike ? const Offset(0, -14) : Offset(liked ? 14 : -14, -1);
    });

    _animateOut(liked: liked, superLike: superLike);
  }

  /// Takes back the last swipe. The await chain lives in the controller; here
  /// only the drag state is reset so the returning card lands at rest.
  Future<void> _rewind() async {
    if (_motionType != _SwipeMotionType.idle) {
      return;
    }

    final restored = await _deck.rewind();
    if (!restored || !mounted) {
      return;
    }

    setState(() {
      _dragOffset = Offset.zero;
      _infoExpanded = false;
      // A rewind is a "wait, no" — any celebration of the swipe it undoes
      // would ring false.
      _pendingMatchCard = null;
      _matchCard = null;
    });
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

  void _setReviewInteractionActive(bool active) {
    if (_reviewInteractionActive == active) {
      return;
    }

    setState(() {
      _reviewInteractionActive = active;
    });
  }

  Future<void> _openFilters() {
    return showDiscoveryFilterSheet(context, deck: _deck);
  }

  DeckHeader _buildHeader() {
    return DeckHeader(
      locationLabel: _deck.locationLabel,
      stalenessLabel: _deck.stalenessLabel,
      streakDays: _deck.streakDays,
      swipesLeft: _deck.swipesLeft,
      activeFilterCount:
          widget.authController.user?.activeFilterCount ?? 0,
      onFilterTap: () => unawaited(_openFilters()),
    );
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
          child: _buildHeader(),
        ),
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
        final matchCard = _matchCard;

        // The overlay sits above whatever the deck is showing — including
        // the exhausted state, which the last card's like may have caused.
        return Stack(
          children: [
            _buildDeck(context),
            if (matchCard != null)
              Positioned.fill(
                child: _MatchOverlay(
                  card: matchCard,
                  isSuperLike: _matchIsSuper,
                  onDismiss: () => setState(() => _matchCard = null),
                ),
              ),
          ],
        );
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

    // Checked before the cards: the limit is about the user's day, not the
    // deck's supply. Rewind stays offered — taking a swipe back refunds it.
    if (_deck.outOfSwipes) {
      return _messageCard(
        eyebrow: 'Daily limit',
        title: 'Out of swipes for today',
        subtitle: 'All ${DeckController.dailySwipeLimit} swipes are spent. '
            'Come back tomorrow — the streak keeps counting.',
        actionLabel: 'Refresh',
        secondaryActionLabel: _deck.canRewind ? 'Rewind last swipe' : null,
        onSecondaryAction:
            _deck.canRewind ? () => unawaited(_rewind()) : null,
        art: AppMotion.heart,
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
        // Rewind still works from the empty deck: it brings the very last
        // card back, exactly as Tinder does.
        secondaryActionLabel: _deck.canRewind ? 'Rewind last swipe' : null,
        onSecondaryAction:
            _deck.canRewind ? () => unawaited(_rewind()) : null,
        art: AppMotion.heart,
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
          child: _buildHeader(),
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
              // Up-swipe is the super like, as on Tinder. Checked first, and
              // only when the drag is not already a committed left/right.
              if (_dragOffset.dy < -140 && _dragOffset.dx.abs() < 110) {
                _animateOut(liked: true, superLike: true);
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
          onPass: () => _triggerAction(liked: false),
          onLike: () => _triggerAction(liked: true),
          onSuperLike: () => _triggerAction(liked: true, superLike: true),
          onRewind: _deck.canRewind ? () => unawaited(_rewind()) : null,
        ),
      ),
    );
  }
}

/// The deck's top chrome: where the user is, and the way into Settings, over a
/// gradient that keeps both legible against any clip.
class DeckHeader extends StatelessWidget {
  const DeckHeader({
    super.key,
    required this.locationLabel,
    this.stalenessLabel,
    this.streakDays = 0,
    this.swipesLeft,
    this.activeFilterCount = 0,
    this.onFilterTap,
  });

  /// The user's reverse-geocoded whereabouts, from the profile row — not a
  /// hardcoded town.
  final String locationLabel;

  /// Set when the deck came off the device instead of the server. Shown under
  /// the location chip so saved cards are never mistaken for fresh ones.
  final String? stalenessLabel;

  /// Consecutive swipe days; the flame chip appears from 2 up — a one-day
  /// "streak" is just today.
  final int streakDays;

  /// Today's remaining allowance, or null when unknown. The chip only appears
  /// once it runs low; a full counter would nag every swipe.
  final int? swipesLeft;

  /// How many discovery filters are on — the badge on the filter button.
  final int activeFilterCount;

  /// Opens the discovery filter sheet. Null hides the button.
  final VoidCallback? onFilterTap;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: AppChip(
                          icon: Icons.place_rounded,
                          label: locationLabel,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onFilterTap != null) ...[
                            AppCircleButton(
                              icon: Icons.tune_rounded,
                              size: kUtilityButtonSize,
                              iconSize: 20,
                              background: Colors.black.withValues(alpha: 0.34),
                              semanticLabel: 'Discovery filters',
                              badgeCount: activeFilterCount,
                              onTap: onFilterTap!,
                            ),
                            const SizedBox(width: 8),
                          ],
                          AppCircleButton(
                            icon: Icons.settings_rounded,
                            size: kUtilityButtonSize,
                            iconSize: 20,
                            background: Colors.black.withValues(alpha: 0.34),
                            semanticLabel: 'Settings',
                            onTap: () => context.push('/settings'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (stalenessLabel != null ||
                      streakDays >= 2 ||
                      (swipesLeft != null && swipesLeft! <= 10)) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (stalenessLabel != null)
                          AppChip(
                            icon: Icons.cloud_off_rounded,
                            label: stalenessLabel!,
                          ),
                        if (streakDays >= 2)
                          AppChip(
                            icon: Icons.local_fire_department_rounded,
                            label: '$streakDays-day streak',
                            tint: kTintMorning,
                          ),
                        if (swipesLeft != null && swipesLeft! <= 10)
                          AppChip(
                            icon: Icons.hourglass_bottom_rounded,
                            label: swipesLeft == 0
                                ? 'No swipes left today'
                                : swipesLeft == 1
                                    ? '1 swipe left today'
                                    : '$swipesLeft swipes left today',
                            tint: kAccentEmber,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The match moment: a full-screen take-over after a like the deck decides to
/// celebrate, and after every super like. A restaurant cannot swipe back, so
/// this is honest about what it is — a nudge to actually go — rather than a
/// faked reciprocity.
class _MatchOverlay extends StatelessWidget {
  const _MatchOverlay({
    required this.card,
    required this.isSuperLike,
    required this.onDismiss,
  });

  final RestaurantCard card;
  final bool isSuperLike;
  final VoidCallback onDismiss;

  Future<void> _openDirections(BuildContext context) async {
    final opened = await openDirections(
      latitude: card.latitude,
      longitude: card.longitude,
      label: card.title,
    );
    if (opened) {
      unawaited(VisitPromptController.instance.recordDirections(
        restaurantId: card.id,
        name: card.title,
      ));
      return;
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open maps for this place.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canRoute = hasMapFix(card.latitude, card.longitude);

    // Fades and settles in once; a finite animation, so tests can pump it to
    // rest.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      // Opaque and gesture-absorbing: nothing under it may take a tap.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: kBackgroundDark),
            if (card.imageUrls.isNotEmpty)
              Image.network(
                card.imageUrls.first,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    TikTokThumbnailPlaceholder(
                  creatorHandle: tiktokCreatorHandle(card.videoUrl),
                ),
              )
            else
              TikTokThumbnailPlaceholder(
                creatorHandle: tiktokCreatorHandle(card.videoUrl),
              ),
            const PhotoWash(),
            const PhotoBottomScrim(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    AppEyebrow(
                      label: isSuperLike ? 'Must try' : "It's a match",
                    ),
                    const SizedBox(height: 8),
                    Text(
                      card.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: appTitleStyle(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSuperLike
                          ? 'Starred and saved to your likes — this one jumps '
                              'the queue.'
                          : 'Saved to your likes. Go while the craving is hot.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: kTextOnPhotoSecondary,
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (canRoute) ...[
                      AppPrimaryButton(
                        label: 'Get directions',
                        icon: Icons.directions_rounded,
                        expand: true,
                        onPressed: () => unawaited(_openDirections(context)),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    AppSecondaryButton(
                      label: 'Keep swiping',
                      expand: true,
                      onPressed: onDismiss,
                    ),
                  ],
                ),
              ),
            ),
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
