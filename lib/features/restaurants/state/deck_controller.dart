import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/open_directions.dart';
import '../../../core/location/place_name.dart';
import '../../../core/location/user_location.dart';
import '../../auth/state/auth_controller.dart';
import '../../profile/data/profile_repository.dart';
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
    Future<Position> Function()? resolvePosition,
  })  : _restaurants = restaurants ?? RestaurantRepository(),
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
      players.clear();
      notifyListeners();
      _warmPlayers(from: 0, count: 5);
    } on Object catch (error) {
      debugPrint('Deck load failed: $error');
      if (generation != _loadGeneration) {
        return;
      }

      _loading = false;
      _error = 'Could not load restaurants. Check your connection.';
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
  Future<void> recordSwipe(RestaurantCard card, {required bool liked}) async {
    final position = _userPosition;
    final hasRealPosition =
        position != null && !isFallbackUserPosition(position);
    final latitude = hasRealPosition ? position.latitude : null;
    final longitude = hasRealPosition ? position.longitude : null;

    try {
      if (liked) {
        // Through the likes controller so the Like tab and any open detail
        // page update without their own round trip.
        await _likes.like(card.id, latitude: latitude, longitude: longitude);
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
