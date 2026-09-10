import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/distance_label.dart';
import '../../../core/location/open_directions.dart';
import '../../../core/location/user_position_state.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/page_transitions.dart';
import '../../wishlist/state/wishlist_controller.dart';
import '../data/restaurant_repository.dart';
import '../data/tiktok_player_factory.dart';
import '../domain/opening_hours.dart';
import '../models/dish.dart';
import '../models/restaurant_detail_data.dart';
import '../state/likes_controller.dart';
import '../state/visit_prompt_controller.dart';
import 'detail/about_paragraph.dart';
import 'detail/detail_cta_bar.dart';
import 'detail/detail_hero.dart';
import 'detail/dish_list.dart';
import 'detail/facts_strip.dart';
import 'detail/friends_bite_row.dart';
import 'tiktok_player.dart';

/// S3 — one restaurant, top to bottom: the clip, what it costs and how many
/// people have bitten it, what they order, and the one thing to do next.
///
/// Reviews are not here. With six reviews across the whole catalogue the card
/// they used to sit in was empty on almost every restaurant, and the redesign
/// spends that space on dishes instead.
class RestaurantDetailPage extends StatefulWidget {
  const RestaurantDetailPage({
    super.key,
    required this.data,
    this.repository,
    this.wishlist,
    this.tiktokPlayerFuture,
    this.clock = OpeningHours.kualaLumpurNow,
  });

  final RestaurantDetailData data;

  /// Injected by tests; in the app the page builds its own. Only the ngap
  /// count is read through it.
  final RestaurantRepository? repository;

  /// Injected by tests. The page makes one when it is not given one, and
  /// disposes only what it made.
  final WishlistController? wishlist;

  /// A warmed player, so a widget test never starts a real WebView. Null in
  /// the app: the page opens its own and stops it on the way out.
  final Future<TikTokPlayerHandle>? tiktokPlayerFuture;

  /// What time it is in Kuala Lumpur, for the open line. See
  /// [OpeningHours.kualaLumpurNow] for why not the device clock.
  final DateTime Function() clock;

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage>
    with UserPositionState {
  late final RestaurantRepository _repository =
      widget.repository ?? RestaurantRepository();

  late final WishlistController _wishlist =
      widget.wishlist ?? WishlistController();
  late final bool _ownsWishlist = widget.wishlist == null;

  /// The hero's player. Owned here when the caller passed none, so it is also
  /// stopped here — there is no cache on this screen to evict it.
  Future<TikTokPlayerHandle>? _playerFuture;
  late final bool _ownsPlayer = widget.tiktokPlayerFuture == null;

  /// True while the fullscreen route holds the player.
  bool _fullscreenOpen = false;

  /// Null until the count arrives, and still null if it never does — an
  /// unanswered fact is a hidden tile, not a zero.
  int? _ngapCount;

  bool _settingDate = false;

  int get _id => widget.data.id;

  bool get _liked => LikesController.instance.isLiked(_id);

  @override
  void initState() {
    super.initState();
    loadUserPosition();

    final videoUrl = widget.data.videoUrl;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      _playerFuture = widget.tiktokPlayerFuture ?? createTikTokPlayer(videoUrl);
      // A player nobody has mounted yet has no listener, so a failed load
      // would surface as an unhandled async error. The view still reports it.
      unawaited(_playerFuture!.then((_) {}, onError: (Object error) {
        debugPrint('TikTok player load failed: $error');
      }));
    }

    LikesController.instance.addListener(_onControllerChanged);
    _wishlist.addListener(_onControllerChanged);

    // Best-effort: an unreachable backend leaves the marks empty, and the
    // taps below surface their own errors if the user then uses them.
    LikesController.instance.ensureLoaded().catchError((Object error) {
      debugPrint('Likes load failed: $error');
    });
    unawaited(_wishlist.ensureLoaded());
    unawaited(_loadNgapCount());
  }

  @override
  void dispose() {
    LikesController.instance.removeListener(_onControllerChanged);
    _wishlist.removeListener(_onControllerChanged);
    if (_ownsWishlist) {
      _wishlist.dispose();
    }
    if (_ownsPlayer) {
      final player = _playerFuture;
      if (player != null) {
        // Otherwise the WebView keeps its audio and its network alive until
        // the collector gets to it.
        unawaited(player.then((handle) => handle.release()).catchError(
              (Object error) =>
                  debugPrint('TikTok player release failed: $error'),
            ));
      }
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadNgapCount() async {
    try {
      final count = await _repository.ngapCount(_id);
      if (!mounted) {
        return;
      }
      setState(() => _ngapCount = count);
    } on Object catch (error) {
      // A count we could not read is a fact we do not have; the tile stays
      // hidden rather than claiming nobody has been.
      debugPrint('Ngap count failed: $error');
    }
  }

  // -------------------------------------------------------------------------
  // The title's meta line
  // -------------------------------------------------------------------------

  /// "Kampung Baru · 1.2 km · open till 2 am", with every unknown part gone.
  String _metaLine() {
    final neighbourhood = widget.data.neighbourhood?.trim();
    final open = widget.data.hours.statusLabel(widget.clock());
    final distance = _distanceSegment();

    return [
      if (neighbourhood != null && neighbourhood.isNotEmpty) neighbourhood,
      if (distance != null) distance,
      // The design writes it lower-case, mid-sentence: it is the third fact in
      // a list, not the start of one.
      if (open != null) open.toLowerCase(),
    ].join(' · ');
  }

  /// The deck's distance wording without its verb — "1.2 km away" reads as a
  /// sentence, and this line is a list. Null rather than the deck's city
  /// fallback: on this screen an unknown distance is a segment we drop.
  String? _distanceSegment() {
    final position = userPosition;
    if (position == null ||
        !hasMapFix(widget.data.latitude, widget.data.longitude)) {
      return null;
    }

    final label = distanceLabelFrom(
      position,
      latitude: widget.data.latitude,
      longitude: widget.data.longitude,
    );
    return label.endsWith(' away')
        ? label.substring(0, label.length - ' away'.length)
        : label;
  }

  List<String> _heroTags() {
    final tag = widget.data.tag.trim();
    return [
      if (tag.isNotEmpty) tag,
      if (widget.data.isHalal == true) 'Halal',
    ];
  }

  // -------------------------------------------------------------------------
  // The facts
  // -------------------------------------------------------------------------

  /// Only what the catalogue can answer (D111). The design's third tile is a
  /// typical wait, which we have no data for at all, so it never appears.
  List<DetailFact> _facts() {
    final priceFrom = widget.data.priceFrom;
    final ngaps = _ngapCount;

    return [
      if (priceFrom != null)
        DetailFact(
          // Not the design's "RM 8–15 per person": what we hold is the
          // cheapest dish on the menu, so the tile says that instead of
          // implying a band nobody measured.
          value: 'From ${formatRinggit(priceFrom)}',
          caption: 'cheapest dish',
        ),
      if (ngaps != null && ngaps > 0)
        DetailFact(value: formatThousands(ngaps), caption: 'ngaps'),
    ];
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  Future<void> _openPlayer(String videoUrl) async {
    setState(() => _fullscreenOpen = true);
    await Navigator.of(context).push(
      // The same fade the deck opens the player with: one screen reached two
      // ways should not arrive two ways.
      fadeThroughRoute<void>(
        context,
        (_) => TikTokPlayerScreen(
          videoUrl: videoUrl,
          playerFuture: _playerFuture,
        ),
      ),
    );
    if (mounted) {
      setState(() => _fullscreenOpen = false);
    }
  }

  Future<void> _toggleWishlist() async {
    final existing = _wishlist.itemForRestaurant(_id);
    if (existing != null) {
      await _wishlist.remove(existing.id);
    } else {
      await _wishlist.addRestaurant(_id, title: widget.data.title);
    }

    final error = _wishlist.error;
    if (!mounted || error == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _openDirections() async {
    final opened = await openDirections(
      latitude: widget.data.latitude,
      longitude: widget.data.longitude,
      label: widget.data.title,
    );
    if (opened) {
      // Remember the trip so the dashboard can ask whether it happened. Never
      // blocks the tap; a cache that will not write only costs the question.
      unawaited(VisitPromptController.instance.recordDirections(
        restaurantId: _id,
        name: widget.data.title,
      ));
      return;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open maps for this place.')),
    );
  }

  /// "Set a date" bites the place first (D112).
  ///
  /// A plan is a thing you do about a restaurant you want; a plan on a place
  /// that is not in your bites would be an orphan the Bites tab never shows.
  /// A like that will not write stops the push — arriving at the planner
  /// having silently failed the thing the planner assumes is worse than not
  /// arriving.
  Future<void> _setDate() async {
    final likes = LikesController.instance;
    if (!likes.isLiked(_id)) {
      setState(() => _settingDate = true);
      try {
        await likes.like(_id, source: 'detail');
      } on Object catch (error) {
        debugPrint('Like before plan failed: $error');
        if (!mounted) {
          return;
        }
        setState(() => _settingDate = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save that change.')),
        );
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() => _settingDate = false);
    }

    if (!mounted) {
      return;
    }
    final imageUrls = widget.data.imageUrls;
    // The push resolves when the planner pops; nothing here waits on it.
    unawaited(context.push('/plans/new', extra: <String, dynamic>{
      'restaurantId': _id,
      'title': widget.data.title,
      'coverUrl': imageUrls.isEmpty ? null : imageUrls.first,
      'neighbourhood': widget.data.neighbourhood,
      'tag': widget.data.tag,
    }));
  }

  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final videoUrl = data.videoUrl;
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final onWishlist = _wishlist.itemForRestaurant(_id) != null;
    final facts = _facts();

    return Scaffold(
      backgroundColor: kBackgroundDark,
      body: Stack(
        children: [
          const ScreenGlow(),
          Column(
            children: [
              SizedBox(
                height: math.max(
                  kDetailHeroMinHeight,
                  MediaQuery.sizeOf(context).height * kDetailHeroFraction,
                ),
                child: DetailHero(
                  title: data.title,
                  tags: _heroTags(),
                  metaLine: _metaLine(),
                  videoUrl: videoUrl,
                  imageUrl:
                      data.imageUrls.isEmpty ? null : data.imageUrls.first,
                  bitten: _liked,
                  playerFuture: _playerFuture,
                  videoHiddenForFullscreen: _fullscreenOpen,
                  onOpenPlayer:
                      hasVideo ? () => unawaited(_openPlayer(videoUrl)) : null,
                  leading: AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    size: kUtilityButtonSize,
                    semanticLabel: 'Back',
                    onTap: () => unawaited(Navigator.of(context).maybePop()),
                  ),
                  trailing: AppIconButton(
                    icon: onWishlist
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: kUtilityButtonSize,
                    iconColor: onWishlist ? kAccentEmber : kTextOnPhoto,
                    semanticLabel:
                        onWishlist ? 'Remove from wishlist' : 'Add to wishlist',
                    onTap: () => unawaited(_toggleWishlist()),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    AppSpacing.md,
                    20,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (facts.isNotEmpty) ...[
                        FactsStrip(facts: facts),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (data.dishes.isNotEmpty) ...[
                        DishList(dishes: data.dishes),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (data.details.trim().isNotEmpty)
                        AboutParagraph(text: data.details),
                      const FriendsBiteRow(avatars: [], caption: null),
                    ],
                  ),
                ),
              ),
              DetailCtaBar(
                busy: _settingDate,
                onSetDate: () => unawaited(_setDate()),
                onDirections: hasMapFix(data.latitude, data.longitude)
                    ? () => unawaited(_openDirections())
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
