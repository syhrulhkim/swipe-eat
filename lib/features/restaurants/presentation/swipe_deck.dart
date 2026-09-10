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
import '../state/deck_handoff.dart';
import 'discovery_filter_sheet.dart';
import 'swipe_card.dart';

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
    this.isActive = true,
    this.handoff,
  });

  final AuthController authController;

  /// Injected by tests; in the app the deck builds its own.
  final DeckController? controller;

  /// Which hand-off the deck deals from ("Swipe all" on the map). Defaults to
  /// the shared instance; injected so a test can wire one map to one deck.
  /// Whether the deck's tab is the one on screen.
  ///
  /// The dashboard keeps every tab mounted in an `IndexedStack`, so a clip
  /// the user unmuted would go on playing out loud from behind the map. It
  /// does not: leaving the tab mutes it.
  final bool isActive;

  /// The hand-off the Nearby map's "Swipe all" publishes to. Injected so a
  /// widget test can drive it; the app wires the shared instance.
  final DeckHandoff? handoff;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final DeckController _deck = widget.controller ??
      DeckController(
        authController: widget.authController,
        handoff: widget.handoff,
      );
  late final bool _ownsController = widget.controller == null;
  StreamSubscription<String>? _messages;
  StreamSubscription<String>? _likeMessages;

  Offset _dragOffset = Offset.zero;

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
    WidgetsBinding.instance.addObserver(this);
    _messages = _deck.messages.listen(_showMessage);
    _likeMessages = _deck.likeMessages.listen(_showMessage);
    if (_ownsController) {
      unawaited(_deck.load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // The trip to Settings to switch location on is an app switch, so this is
    // where the app finds out. Without it the deck keeps the fallback — and
    // the stale town name that goes with it — until the next cold start.
    if (state == AppLifecycleState.resumed) {
      unawaited(_deck.refreshLocation());
    }
  }

  @override
  void didUpdateWidget(covariant SwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _muteCurrentClip();
    }
  }

  /// Sends the card on screen back to silent.
  void _muteCurrentClip() {
    final videoUrl = _deck.current?.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) {
      return;
    }

    unawaited(_deck.players.warm(videoUrl)?.then((h) => h.setMuted(true)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_messages?.cancel());
    unawaited(_likeMessages?.cancel());
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
    return showDiscoveryFilterSheet(
      context,
      authController: _deck.authController,
      onApply: _deck.applyDiscoveryFilters,
    );
  }

  /// A tap anywhere on the card: the restaurant's own screen, handed the card
  /// so it paints before the row is refetched.
  void _openDetail(RestaurantCard card) {
    // The deck card stays mounted under the opaque detail route. If its clip
    // was unmuted it would keep playing audio behind a hero showing the same
    // clip, so the card's player goes back to silent on the way out.
    _muteCurrentClip();

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
      handoffLabel: _deck.handoffLabel,
      activeFilterCount: widget.authController.user?.activeFilterCount ?? 0,
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

  /// "A", "A and B", "A, B and C" — the rules read as a sentence, because the
  /// card is a sentence.
  static String _sentenceList(List<String> parts) {
    if (parts.length == 1) {
      return parts.single;
    }
    return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
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
      // An empty deck under a rule the user set is a consequence of their own
      // answer, so the card names the rule instead of implying the app has no
      // food in it.
      final rules = widget.authController.user?.narrowingRules ?? const [];
      if (rules.isNotEmpty) {
        return _messageCard(
          eyebrow: 'Nothing dealt',
          title: 'Your rules leave nothing here',
          subtitle: '${_sentenceList(rules)} rules out everything we know '
              'about nearby. Loosen one in Settings and the deck fills again.',
          actionLabel: 'Reload',
          art: AppMotion.pin,
        );
      }
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
        onTap: () => _openDetail(next),
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
          final likeOpacity = frame.offset.dx > 20 ? frame.dragPercentage : 0.0;
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
          onTap: () => _openDetail(current),
          onOpenDetail: () => _openDetail(current),
          tiktokPlayerFuture: _deck.players.warm(current.videoUrl),
        ),
      ),
    );
  }
}

/// The design's three-button bar under the deck: a ghost Skip, the Ngap
/// button, a ghost Later, in three equal columns with the one that matters in
/// the middle.
///
/// The ghosts carry their word under the glyph. The Ngap button already says
/// its own, and the primer taught all three as words, so a cross and a clock
/// on their own would be asking the user to remember a lesson from a screen
/// they saw once. Equal columns keep Ngap dead-centre whatever the captions
/// measure.
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
        _GhostAction(
          icon: Icons.close_rounded,
          caption: 'Skip',
          semanticLabel: 'Skip',
          onTap: onPass,
        ),
        const SizedBox(width: kDeckActionGap),
        AppNgapButton(onTap: onLike),
        const SizedBox(width: kDeckActionGap),
        // A clock, not a bookmark: "later" here is about when you eat, not
        // about filing the place away.
        _GhostAction(
          icon: Icons.schedule_rounded,
          caption: 'Later',
          semanticLabel: 'Save for later',
          onTap: onLater,
        ),
      ],
    );
  }
}

/// One of the two ghosts flanking Ngap: the disc, and its word underneath.
class _GhostAction extends StatelessWidget {
  const _GhostAction({
    required this.icon,
    required this.caption,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String caption;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // As wide as the Ngap disc, so the bar is three equal columns and the
      // captions cannot nudge the centre one off-centre.
      width: kNgapButtonSize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIconButton(
            icon: icon,
            size: kActionButtonSize,
            iconSize: 22,
            onPhoto: false,
            background: kSurfaceDark,
            semanticLabel: semanticLabel,
            onTap: onTap,
          ),
          const SizedBox(height: kDeckActionCaptionGap),
          // The button already announces itself; a second node reading the
          // same word would make a screen reader say every move twice.
          ExcludeSemantics(
            child: Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: kTextFontFamily,
                fontSize: kFontSizeMicro,
                fontWeight: FontWeight.w600,
                color: kCreamSecondary,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The deck's top bar, the design's `.topbar`: where the user is with the
/// radius and the meal under it, and the discovery-settings button.
class DeckHeader extends StatelessWidget {
  const DeckHeader({
    super.key,
    required this.locationLabel,
    this.radiusKm,
    this.mealLabel,
    this.stalenessLabel,
    this.handoffLabel,
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

  /// Set while the deck is dealing a list handed over from Nearby ("Swipe all
  /// 6"), so the user knows these six are not the ranked deck.
  final String? handoffLabel;

  /// Set while the deck is dealing a list handed over from Nearby ("Swipe all
  /// 6"), so the user knows these six are not the ranked deck. Its own chip —
  /// the offline chip's cloud would say the wrong thing about fresh rows.
  /// How many discovery filters are on — the badge on the discovery button,
  /// and what turns it ember.
  final int activeFilterCount;

  /// Opens the discovery settings sheet. Null hides the button.
  final VoidCallback? onFilterTap;

  /// Whether a filter is narrowing the deck beyond radius and meal, which the
  /// subline already reports.
  bool get _narrowed => activeFilterCount > 0;

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
                  // The sheet behind this sets radius, cuisines, dietary needs
                  // and rating — the whole of what the deck is allowed to
                  // show — so it is named for that, not for one of its rows.
                  // The count is a value rather than part of the name, so
                  // "Discovery settings" is what a screen reader lands on and
                  // "2 filters on" is what it hears next. Excluding the
                  // button's own node drops its tap action, so the action is
                  // re-declared here (D83).
                  Semantics(
                    label: 'Discovery settings',
                    value: _narrowed
                        ? '$activeFilterCount ${activeFilterCount == 1 ? 'filter' : 'filters'} on'
                        : null,
                    button: true,
                    excludeSemantics: true,
                    onTap: onFilterTap,
                    child: AppIconButton(
                      icon: Icons.tune_rounded,
                      size: kUtilityButtonSize,
                      iconSize: 20,
                      onPhoto: false,
                      background: kGlass,
                      // Ember is the palette's word for "chosen". A filter that
                      // is on is a choice the deck is obeying, and the glyph
                      // says so before the count is read.
                      iconColor: _narrowed ? kAccentEmber : kTextOnPhoto,
                      badgeCount: activeFilterCount,
                      onTap: onFilterTap!,
                    ),
                  ),
                ],
              ],
            ),
            if (stalenessLabel != null || handoffLabel != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (handoffLabel != null)
                    AppChip(
                      icon: Icons.near_me_rounded,
                      label: handoffLabel!,
                      onPhoto: false,
                      tint: kAccentEmber,
                    ),
                  if (stalenessLabel != null)
                    AppChip(
                      icon: Icons.cloud_off_rounded,
                      label: stalenessLabel!,
                      onPhoto: false,
                    ),
                ],
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
