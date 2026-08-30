import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/open_directions.dart';
import '../../../core/location/place_name.dart';
import '../../../core/location/user_location.dart';
import '../../auth/state/auth_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../../../core/storage/cached_at.dart';
import '../data/deck_cache.dart';
import '../data/restaurant_repository.dart';
import '../data/swipe_repository.dart';
import '../models/restaurant_card.dart';
import 'likes_controller.dart';
import 'tiktok_player_cache.dart';

/// Everything the swipe deck knows: which cards were dealt, which one is on
/// top, and what happened to the ones already swiped.
///
/// The widget keeps only its animation state. Repositories arrive through the
/// constructor so the deck can be driven by fakes in a test without a live
/// Supabase client.
class DeckController extends ChangeNotifier {
  DeckController({
    required this.authController,
    RestaurantRepository? restaurants,
    SwipeRepository? swipes,
    ProfileRepository? profiles,
    LikesController? likes,
    TikTokPlayerCache? players,
    DeckCache? cache,
    Future<Position> Function()? resolvePosition,
  })  : _restaurants = restaurants ?? RestaurantRepository(),
        _cache = cache ?? const DeckCache(),
        _swipes = swipes ?? SwipeRepository(),
        _profiles = profiles ?? ProfileRepository(),
        _likes = likes ?? LikesController.instance,
        players = players ?? TikTokPlayerCache(),
        _resolvePosition = resolvePosition ?? resolveUserPosition {
    _appliedRadiusKm = authController.user?.searchRadiusKm;
    authController.addListener(_onAuthChanged);
  }

  final AuthController authController;
  final RestaurantRepository _restaurants;
  final SwipeRepository _swipes;
  final ProfileRepository _profiles;
  final LikesController _likes;
  final DeckCache _cache;
  final Future<Position> Function() _resolvePosition;

  /// Warm players for the cards around the top one; the widget hands these to
  /// the card it is building.
  final TikTokPlayerCache players;

  List<RestaurantCard> _cards = const [];
  List<RestaurantCard> get cards => _cards;

  int _index = 0;
  int get index => _index;

  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Position? _userPosition;
  Position? get userPosition => _userPosition;

  DateTime? _dealtFromCacheAt;

  /// True when the cards on screen came off the device rather than the server.
  bool get isStale => _dealtFromCacheAt != null;

  /// What the deck says about itself when it is stale, so the user is never
  /// shown a saved deck as if it were live.
  String? get stalenessLabel {
    final savedAt = _dealtFromCacheAt;
    return savedAt == null ? null : 'Offline · saved ${describeAge(savedAt)}';
  }

  /// What the header chip says: the reverse-geocoded name of the last stored
  /// fix, or 'Nearby' for an account that has never granted location.
  String get locationLabel => authController.user?.lastPlaceName ?? 'Nearby';

  /// True once every dealt card has been swiped.
  bool get isExhausted => _index >= _cards.length;

  RestaurantCard? get current => isExhausted ? null : _cards[_index];
  RestaurantCard? get next =>
      _index + 1 < _cards.length ? _cards[_index + 1] : null;

  /// Guards against overlapping [load] runs (init + retry buttons): only the
  /// newest request may publish its result, so a stale slow response can never
  /// overwrite a fresher deck.
  int _loadGeneration = 0;

  /// The radius the current deck was dealt under. The tabs live in an
  /// IndexedStack that never re-inits, so a Settings change has to be listened
  /// for — the radius is a server-side filter, and stale cards would break its
  /// promise that out-of-range places are not dealt.
  int? _appliedRadiusKm;

  /// Errors worth telling the user about, raised by [recordSwipe]. The widget
  /// drains this to show a toast; nothing else depends on it.
  final StreamController<String> _messages = StreamController<String>.broadcast();
  Stream<String> get messages => _messages.stream;

  /// Swipe writes still in flight, by restaurant id. [rewind] must wait for
  /// the write it is undoing: swipes are optimistic, so an undo fired before
  /// its write lands would delete nothing — and then the write would put the
  /// row right back.
  final Map<int, Future<void>> _pendingWrites = {};

  @override
  void dispose() {
    authController.removeListener(_onAuthChanged);
    unawaited(_messages.close());
    super.dispose();
  }

  void _onAuthChanged() {
    final radius = authController.user?.searchRadiusKm;
    if (radius == _appliedRadiusKm) {
      return;
    }
    _appliedRadiusKm = radius;
    unawaited(load());
  }

  Future<void> load() async {
    final generation = ++_loadGeneration;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // The position is an input to the server-side ranking, so it is resolved
      // first. It is session-cached, so only the very first load pays for the
      // permission dialog and the GPS fix. A fallback position is not a real
      // fix — passing null lets the RPC fall back to the profile's stored
      // coordinates instead of ranking around a bogus origin.
      final position = await _resolvePosition();
      _userPosition = position;
      final hasRealPosition = !isFallbackUserPosition(position);
      if (hasRealPosition) {
        // Fire-and-forget: the deck must not wait on reverse geocoding.
        unawaited(_syncLocation(position));
      }

      // Ranked, radius-filtered and de-duplicated against past swipes by the
      // get_deck RPC; the rows arrive in serve order.
      final restaurants = await _restaurants.fetchDeck(
        latitude: hasRealPosition ? position.latitude : null,
        longitude: hasRealPosition ? position.longitude : null,
      );
      if (generation != _loadGeneration) {
        return;
      }

      _cards = restaurants.map(RestaurantCard.fromRestaurant).toList();
      _index = 0;
      _loading = false;
      _dealtFromCacheAt = null;
      players.clear();
      notifyListeners();
      _warmPlayers(from: 0, count: 5);

      // Kept for the next launch that cannot reach the server. Fire-and-forget:
      // the deck is already on screen and a failed write costs nothing.
      unawaited(_cache.save(
        userId: authController.sessionUserId ?? '',
        restaurants: restaurants,
      ));
    } on Object catch (error) {
      debugPrint('Deck load failed: $error');
      if (generation != _loadGeneration) {
        return;
      }

      final cached = await _cache.read(authController.sessionUserId ?? '');
      if (generation != _loadGeneration) {
        return;
      }

      _loading = false;
      if (cached == null) {
        _error = 'Could not load restaurants. Check your connection.';
        notifyListeners();
        return;
      }

      // Something to swipe beats an error page. The cards are marked stale, so
      // the deck says where they came from, and the swipes still write — they
      // just fail their own way if the connection is still down.
      _cards = cached.restaurants.map(RestaurantCard.fromRestaurant).toList();
      _index = 0;
      _dealtFromCacheAt = cached.savedAt;
      players.clear();
      notifyListeners();
    }
  }

  /// Pushes a real fix (and its reverse-geocoded name) onto the profile, so
  /// the header chip and every server-side radius rule agree on where the user
  /// is. The returned profile row feeds [AuthController.applyUser], which is
  /// what swaps the chip from the stale name to the current one.
  Future<void> _syncLocation(Position position) async {
    try {
      final placeName = await resolvePlaceName(position);
      final user = await _profiles.updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        placeName: placeName,
      );
      authController.applyUser(user);
    } on Object catch (error) {
      // The chip keeps the last stored name; nothing else depends on this.
      debugPrint('Location sync failed: $error');
    }
  }

  /// Warms the players for the next few cards, so a swipe lands on a clip that
  /// is already running.
  void warmUpcomingPlayers() => _warmPlayers(from: _index, count: 3);

  void _warmPlayers({required int from, required int count}) {
    for (var offset = 0; offset < count; offset++) {
      final cardIndex = from + offset;
      if (cardIndex < 0 || cardIndex >= _cards.length) {
        continue;
      }
      players.warm(_cards[cardIndex].videoUrl);
    }
  }

  /// Moves past the top card once its fly-out animation has finished.
  void advance() {
    if (isExhausted) {
      return;
    }
    _index += 1;
    notifyListeners();
  }

  /// Records a swipe. Optimistic by design: the card has already flown out, so
  /// a failed write costs a toast and nothing else — the backend never saw the
  /// swipe, and the card simply resurfaces on a future deck.
  ///
  /// The returned future never throws; failures end at the toast.
  Future<void> recordSwipe(
    RestaurantCard card, {
    required bool liked,
    bool superLike = false,
  }) {
    late final Future<void> write;
    write = _writeSwipe(card, liked: liked, superLike: superLike)
        .whenComplete(() {
      // Identity check: a re-swipe of the same restaurant (rewind, then swipe
      // again) may already own the slot by the time this one settles.
      if (identical(_pendingWrites[card.id], write)) {
        _pendingWrites.remove(card.id);
      }
    });
    _pendingWrites[card.id] = write;
    return write;
  }

  Future<void> _writeSwipe(
    RestaurantCard card, {
    required bool liked,
    required bool superLike,
  }) async {
    final position = _userPosition;
    final hasRealPosition =
        position != null && !isFallbackUserPosition(position);
    final latitude = hasRealPosition ? position.latitude : null;
    final longitude = hasRealPosition ? position.longitude : null;

    try {
      if (liked) {
        // Through the likes controller so the Like tab and any open detail
        // page update without their own round trip.
        await _likes.like(
          card.id,
          superLike: superLike,
          latitude: latitude,
          longitude: longitude,
        );
      } else {
        await _swipes.record(
          restaurantId: card.id,
          liked: false,
          latitude: latitude,
          longitude: longitude,
        );
      }
    } on Object catch (error) {
      debugPrint('Swipe write failed: $error');
      if (!_messages.isClosed) {
        _messages.add('Could not save that swipe.');
      }
    }
  }

  /// Whether there is a swipe to take back: something swiped from this deal,
  /// and no reload in progress (a reload is about to re-deal from index 0).
  bool get canRewind => _index > 0 && !_loading;

  /// Takes back the most recent swipe: deletes its row server-side, then steps
  /// the deck back so the card is on top again.
  ///
  /// Not optimistic, unlike the swipes themselves: stepping back before the
  /// delete confirms would show a card the server still considers swiped, and
  /// re-swiping it from that state gets confusing fast. Returns whether the
  /// card came back.
  Future<bool> rewind() async {
    if (!canRewind) {
      return false;
    }
    final generation = _loadGeneration;
    final card = _cards[_index - 1];

    // Wait out the optimistic write being undone (see [_pendingWrites]); it
    // catches its own errors, so this await cannot throw.
    final pending = _pendingWrites[card.id];
    if (pending != null) {
      await pending;
    }

    try {
      await _swipes.undo(restaurantId: card.id);
    } on Object catch (error) {
      debugPrint('Undo swipe failed: $error');
      if (!_messages.isClosed) {
        _messages.add('Could not undo that swipe.');
      }
      return false;
    }

    // A reload may have re-dealt the deck during the awaits above; the delete
    // still landed (the card will be dealt again), but this rewind's index no
    // longer means anything.
    if (generation != _loadGeneration) {
      return false;
    }

    if (_index > 0) {
      _index -= 1;
      notifyListeners();
    }

    // The undone swipe may have been a like; the Like tab must forget it.
    // Refreshed rather than surgically removed, because only the server knows
    // whether the row existed at all.
    unawaited(_likes.refresh().catchError((Object error) {
      debugPrint('Likes refresh after rewind failed: $error');
    }));
    return true;
  }

  /// How far the user is from [card], phrased for the card's location row.
  String distanceLabelFor(RestaurantCard card) {
    final position = _userPosition;
    if (position == null) {
      return 'Distance loading';
    }

    if (!hasMapFix(card.latitude, card.longitude)) {
      // Measuring to the 0,0 sentinel reports the distance to Null Island,
      // which reads as a real answer.
      return 'Distance unknown';
    }

    final meters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      card.latitude,
      card.longitude,
    );

    if (meters >= 100000) {
      return '100km +';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
