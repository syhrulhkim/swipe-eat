import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/open_directions.dart';
import '../../../core/location/place_name.dart';
import '../../../core/location/user_location.dart';
import '../../auth/models/app_user.dart';
import '../../auth/state/auth_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../../../core/storage/cached_at.dart';
import '../data/deck_cache.dart';
import '../data/restaurant_repository.dart';
import '../data/swipe_repository.dart';
import '../models/restaurant.dart';
import '../models/restaurant_card.dart';
import 'deck_handoff.dart';
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
    Future<String?> Function(Position)? resolvePlace,
    DeckHandoff? handoff,
  })  : _restaurants = restaurants ?? RestaurantRepository(),
        _cache = cache ?? const DeckCache(),
        _swipes = swipes ?? SwipeRepository(),
        _profiles = profiles ?? ProfileRepository(),
        _likes = likes ?? LikesController.instance,
        players = players ?? TikTokPlayerCache(),
        _resolvePosition = resolvePosition ?? resolveUserPosition,
        _handoff = handoff ?? DeckHandoff.instance,
        // Injected the way onboarding injects it: the OS geocoder is the one
        // dependency here a test cannot stand up, and its failure is a real
        // path, not an edge case.
        _resolvePlace = resolvePlace ?? resolvePlaceName {
    _appliedDeckSignature = _deckSignature(authController.user);
    authController.addListener(_onAuthChanged);
    _handoffRevision = _handoff.revision;
    _handoff.addListener(_onHandoff);
  }

  final AuthController authController;
  final RestaurantRepository _restaurants;
  final SwipeRepository _swipes;
  final ProfileRepository _profiles;
  final LikesController _likes;

  /// The likes controller's own message channel, surfaced here so a screen
  /// that already listens to this controller hears both without wiring two
  /// subscriptions to two objects.
  Stream<String> get likeMessages => _likes.messages;
  final DeckCache _cache;
  final Future<Position> Function() _resolvePosition;
  final DeckHandoff _handoff;
  final Future<String?> Function(Position) _resolvePlace;

  /// The hand-off revision this deck has already dealt, so a rebuild-driven
  /// notification cannot re-deal a list the deck is already showing.
  late int _handoffRevision;

  /// Warm players for the cards around the top one; the widget hands these to
  /// the card it is building.
  final TikTokPlayerCache players;

  List<RestaurantCard> _cards = const [];
  List<RestaurantCard> get cards => _cards;

  int _cursor = 0;
  int get index => _index;

  /// Every move of the cursor restarts the dwell clock, wherever the move came
  /// from — the next card, a reload, a filter change. A getter/setter pair
  /// rather than a call at each of the four sites, because the one that gets
  /// forgotten is the one that reports a dwell of four minutes.
  int get _index => _cursor;
  set _index(int value) {
    _cursor = value;
    _topCardShownAt = DateTime.now();
  }

  DateTime _topCardShownAt = DateTime.now();

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
  ///
  /// A fallback position means the app asked and got nothing — services off,
  /// permission denied, no fix at all. The stored name is then whatever town
  /// the user was in the last time it worked, which can be days and a hundred
  /// kilometres ago, so the header says why it has no answer instead of
  /// presenting an old one as current.
  String get locationLabel {
    final position = _userPosition;
    if (position != null && isFallbackUserPosition(position)) {
      return 'Location off';
    }
    return authController.user?.lastPlaceName ?? 'Nearby';
  }

  /// True once every dealt card has been swiped.
  bool get isExhausted => _index >= _cards.length;

  RestaurantCard? get current => isExhausted ? null : _cards[_index];
  RestaurantCard? get next =>
      _index + 1 < _cards.length ? _cards[_index + 1] : null;

  /// Guards against overlapping [load] runs (init + retry buttons): only the
  /// newest request may publish its result, so a stale slow response can never
  /// overwrite a fresher deck.
  int _loadGeneration = 0;

  /// The deck-shaping profile state the current deck was dealt under: radius,
  /// discovery filters, and the diet & budget hard rules. The tabs live in an
  /// IndexedStack that never re-inits, so a change to any of them has to be
  /// listened for — they are server-side filters, and stale cards would break
  /// their promises.
  ///
  /// Deliberately excludes `lastPlaceName` and the stored fix: every load
  /// syncs those through [applyUser], and including them would make each load
  /// trigger the next.
  String? _appliedDeckSignature;

  static String _deckSignature(AppUser? user) {
    if (user == null) {
      return '';
    }
    return [
      user.searchRadiusKm,
      user.filterMinRating,
      user.filterCuisineIds.join(','),
      user.filterDietaryTagIds.join(','),
      // Hard rules in `deck_scored` (D105): flipping one in Settings changes
      // which places may be dealt at all, so the deck has to be re-dealt.
      user.halalOnly,
      user.vegetarian,
      user.budgetMax,
    ].join('|');
  }

  /// Errors worth telling the user about, raised by [recordSwipe]. The widget
  /// drains this to show a toast; nothing else depends on it.
  final StreamController<String> _messages =
      StreamController<String>.broadcast();
  Stream<String> get messages => _messages.stream;

  /// Swipe writes still in flight, by restaurant id. Swipes are optimistic,
  /// so anything that needs a row to exist must wait for its write to land.
  final Map<int, Future<void>> _pendingWrites = {};

  bool _disposed = false;

  /// True when [generation] no longer speaks for this deck: a newer load (or a
  /// hand-off) has started, or the controller is gone. Either way the run that
  /// asks returns without notifying — a notification after dispose throws.
  bool _isStale(int generation) => _disposed || generation != _loadGeneration;

  @override
  void dispose() {
    _disposed = true;
    // Anything still awaiting belongs to a generation that no longer exists,
    // so it goes quiet instead of notifying a disposed notifier.
    _loadGeneration += 1;
    authController.removeListener(_onAuthChanged);
    _handoff.removeListener(_onHandoff);
    unawaited(_messages.close());
    super.dispose();
  }

  void _onHandoff() {
    if (_handoff.revision == _handoffRevision) {
      return;
    }
    _handoffRevision = _handoff.revision;
    dealFrom(_handoff.restaurants, label: _handoff.label);
  }

  /// Replaces the deck with a list another screen has already fetched — the
  /// Nearby map's "Swipe all N". No RPC: the rows are the ones the map is
  /// showing, and re-querying would risk dealing a different set than the one
  /// the user just looked at.
  ///
  /// Takes the load generation with it, or a `load()` still in flight would
  /// land afterwards and quietly throw the hand-off away.
  void dealFrom(List<Restaurant> restaurants, {String? label}) {
    if (restaurants.isEmpty) {
      return;
    }

    _loadGeneration += 1;
    _cards = restaurants.map(RestaurantCard.fromRestaurant).toList();
    _index = 0;
    _loading = false;
    _error = null;
    // Not a cached deck: these rows came off the server a moment ago, so the
    // staleness chip must not appear over them.
    _dealtFromCacheAt = null;
    _handoffLabel = label;
    players.clear();
    notifyListeners();
    _warmPlayers(from: 0, count: 5);
  }

  String? _handoffLabel;

  /// Where the cards on screen came from when they were handed over rather
  /// than dealt ("Nearby · 6 places"). Null for an ordinary deck.
  String? get handoffLabel => _handoffLabel;

  void _onAuthChanged() {
    final signature = _deckSignature(authController.user);
    if (signature == _appliedDeckSignature) {
      return;
    }
    _appliedDeckSignature = signature;
    unawaited(load());
  }

  /// Re-deals if the app still has nothing but the fallback to go on.
  ///
  /// [resolveUserPosition] drops its session cache after a fallback, so this
  /// is the call that picks up a fix the moment the user comes back from
  /// Settings having turned location on. Guarded on the fallback because a
  /// re-deal restarts the stack: someone six cards in, with a perfectly good
  /// fix, must not lose their place every time they switch apps.
  Future<void> refreshLocation() async {
    final position = _userPosition;
    if (position != null && !isFallbackUserPosition(position)) {
      return;
    }
    await load();
  }

  Future<void> load() async {
    if (_disposed) {
      return;
    }
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
      if (_isStale(generation)) {
        return;
      }

      _cards = restaurants.map(RestaurantCard.fromRestaurant).toList();
      _index = 0;
      _loading = false;
      _dealtFromCacheAt = null;
      _handoffLabel = null;
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
      if (_isStale(generation)) {
        return;
      }

      final cached = await _cache.read(authController.sessionUserId ?? '');
      if (_isStale(generation)) {
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
      // These cards came off the device, not off the map a moment ago, so
      // whatever handed the last deck over does not get the credit.
      _handoffLabel = null;
      // These cards are the cache's, not the map's: leaving the hand-off label
      // on them would credit "Nearby · 6 places" to a deck saved days ago.
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
      final placeName = await _resolvePlace(position);
      final user = await _profiles.updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        placeName: placeName,
      );
      authController.applyUser(user);
    } on Object catch (error) {
      // The write failed, so the profile keeps the whole of its last fix —
      // coordinates and name together, which at least agree with each other.
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
    bool later = false,
  }) {
    late final Future<void> write;
    write = _writeSwipe(card, liked: liked, later: later).whenComplete(() {
      // Identity check: a re-swipe of the same restaurant may already own the
      // slot by the time this one settles.
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
    required bool later,
  }) async {
    final position = _userPosition;
    final hasRealPosition =
        position != null && !isFallbackUserPosition(position);
    final latitude = hasRealPosition ? position.latitude : null;
    final longitude = hasRealPosition ? position.longitude : null;
    final dwellMs = _dwellMs();
    final unmuted = await _isUnmuted(card);

    try {
      if (liked) {
        // Through the likes controller so the Like tab and any open detail
        // page update without their own round trip.
        await _likes.like(
          card.id,
          later: later,
          latitude: latitude,
          longitude: longitude,
          dwellMs: dwellMs,
          unmuted: unmuted,
        );
      } else {
        await _swipes.record(
          restaurantId: card.id,
          liked: false,
          latitude: latitude,
          longitude: longitude,
          dwellMs: dwellMs,
          unmuted: unmuted,
        );
      }
    } on Object catch (error) {
      debugPrint('Swipe write failed: $error');
      if (!_messages.isClosed) {
        _messages.add('Could not save that swipe.');
      }
    }
  }

  /// How long the card has been the top card (D149). Clamped at ten minutes:
  /// past that the phone was in a pocket, not in front of a face, and a wild
  /// number would be read later as attention.
  int _dwellMs() {
    final elapsed = DateTime.now().difference(_topCardShownAt).inMilliseconds;
    if (elapsed < 0) {
      return 0;
    }
    return elapsed > _maxDwellMs ? _maxDwellMs : elapsed;
  }

  static const _maxDwellMs = 10 * 60 * 1000;

  /// Whether the card's clip had sound on at the moment of the swipe (D149).
  /// Read off the warmed player rather than reported up from the mute button,
  /// which would mean threading a callback through three widgets. Null when
  /// there is no player to ask — a card with no clip, or one whose player has
  /// not loaded — because that is not the same as muted.
  Future<bool?> _isUnmuted(RestaurantCard card) async {
    final player = players.peek(card.videoUrl);
    if (player == null) {
      return null;
    }
    try {
      return !(await player).muted.value;
    } on Object {
      return null;
    }
  }

  /// Writes the discovery filter sheet's state to the profile. The returned
  /// row goes through [AuthController.applyUser], whose change notification
  /// is what reloads the deck — no explicit reload here.
  Future<bool> applyDiscoveryFilters({
    required List<int> cuisineIds,
    required List<int> dietaryTagIds,
    double? minRating,
    int? searchRadiusKm,
  }) async {
    // Two writes, because the radius has its own RPC. The radius goes first:
    // if it fails the filters are left alone, so the sheet's "could not save"
    // is the whole truth rather than half of it.
    //
    // Only the last row reaches [applyUser], and only once. Applying the
    // radius on its own would re-deal the deck under the new radius and the
    // old filters, a whole load thrown away a moment later.
    AppUser? written;
    try {
      if (searchRadiusKm != authController.user?.searchRadiusKm) {
        written = await _profiles.updateSearchRadius(searchRadiusKm);
      }

      written = await _profiles.setDiscoveryFilters(
        cuisineIds: cuisineIds,
        dietaryTagIds: dietaryTagIds,
        minRating: minRating,
      );
      return true;
    } on Object catch (error) {
      debugPrint('Discovery filters write failed: $error');
      if (!_messages.isClosed) {
        _messages.add('Could not save your discovery settings.');
      }
      return false;
    } finally {
      // Whatever landed is the truth now, half a sheet included.
      if (written != null) {
        authController.applyUser(written);
      }
    }
  }

  /// How far the user is from [card], phrased for the card's location row.
  /// The point the deck was dealt around, which is the only point a distance
  /// on a card may be measured from.
  ///
  /// It mirrors `deck_scored`'s own chain — the device fix, else the profile's
  /// stored one — because the server applies the radius from there. Measuring
  /// from anywhere else is how a card the server picked as "within 15 km"
  /// ends up labelled 78 km: three origins on one screen.
  ///
  /// A fallback position is not a fix. It is a made-up coordinate near the
  /// seeded data, and the RPC is told nothing about it, so it must not be
  /// measured from either.
  ({double latitude, double longitude})? get _deckOrigin {
    final position = _userPosition;
    if (position != null && !isFallbackUserPosition(position)) {
      return (latitude: position.latitude, longitude: position.longitude);
    }

    final user = authController.user;
    final latitude = user?.lastLatitude;
    final longitude = user?.lastLongitude;
    if (latitude == null || longitude == null ||
        !hasMapFix(latitude, longitude)) {
      return null;
    }
    return (latitude: latitude, longitude: longitude);
  }

  String distanceLabelFor(RestaurantCard card) {
    final origin = _deckOrigin;
    if (origin == null) {
      // Nothing to measure from — not the device, not the profile. Saying
      // "loading" is honest: the first fix is still the likely answer.
      return _userPosition == null ? 'Distance loading' : 'Distance unknown';
    }

    if (!hasMapFix(card.latitude, card.longitude)) {
      // Measuring to the 0,0 sentinel reports the distance to Null Island,
      // which reads as a real answer.
      return 'Distance unknown';
    }

    final meters = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      card.latitude,
      card.longitude,
    );

    if (meters >= 100000) {
      return '100km +';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
