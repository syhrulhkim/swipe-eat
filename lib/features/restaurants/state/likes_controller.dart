import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/restaurant_repository.dart';
import '../data/swipe_repository.dart';
import '../models/restaurant.dart';

/// How [LikesController] learns who is signed in. Separated so tests can
/// drive account changes without an initialised `Supabase.instance`.
class LikesAuthEvents {
  const LikesAuthEvents();

  /// Null when Supabase is not initialised (tests): nothing to follow.
  Stream<AuthState>? get changes {
    try {
      return Supabase.instance.client.auth.onAuthStateChange;
    } on Error catch (_) {
      // `Supabase.instance` asserts rather than throwing an exception when the
      // singleton was never initialised.
      return null;
    }
  }

  String? get currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } on Error catch (_) {
      return null;
    }
  }
}

/// Account-scoped like state, shared by the deck, the Like tab and the
/// restaurant detail page. Successor to the device-local `LikesStore`: the
/// swipes table is authoritative, this is only its cache plus the optimistic
/// edits in flight.
///
/// Because it caches *account* data behind an app-lifetime singleton, it
/// watches auth changes and drops everything when the account changes —
/// otherwise user B would see user A's hearts after a re-login on the same
/// device.
class LikesController extends ChangeNotifier {
  LikesController({
    RestaurantRepository? restaurants,
    SwipeRepository? swipes,
    bool followAuthChanges = true,
    LikesAuthEvents authEvents = const LikesAuthEvents(),
  })  : _restaurants = restaurants,
        _swipes = swipes,
        _followAuthChanges = followAuthChanges,
        _authEvents = authEvents;

  static LikesController instance = LikesController();

  /// Swaps [instance] for a fake-backed one. There is no restore: every test
  /// that touches the singleton installs its own in `setUp`.
  @visibleForTesting
  static LikesController replaceForTests(LikesController controller) =>
      instance = controller;

  RestaurantRepository? _restaurants;
  SwipeRepository? _swipes;
  final bool _followAuthChanges;
  final LikesAuthEvents _authEvents;

  // Lazy so the singleton can exist before Supabase.initialize has run.
  RestaurantRepository get _restaurantRepository =>
      _restaurants ??= RestaurantRepository();
  SwipeRepository get _swipeRepository => _swipes ??= SwipeRepository();

  List<Restaurant> _liked = const [];
  Set<int> _likedIds = <int>{};
  bool _loaded = false;
  Future<void>? _loading;
  StreamSubscription<AuthState>? _authSubscription;

  /// Whose data the cache holds (or is loading). Only a *different* incoming
  /// session may dump the cache — see [_ensureAuthSubscription].
  String? _accountId;

  /// Bumped by [reset] so an in-flight [refresh] cannot publish stale rows
  /// into the next account's session.
  int _generation = 0;

  bool get isLoaded => _loaded;

  /// Liked restaurants, newest like first (the backend's `updated_at` order).
  List<Restaurant> get liked => List.unmodifiable(_liked);

  bool isLiked(int restaurantId) => _likedIds.contains(restaurantId);

  /// Loads once; concurrent callers share the same request. A failed load
  /// clears itself so the next call retries instead of caching the error.
  Future<void> ensureLoaded() {
    _ensureAuthSubscription();
    if (_loaded) {
      return Future.value();
    }
    final pending = _loading;
    if (pending != null) {
      return pending;
    }
    late final Future<void> load;
    load = refresh().whenComplete(() {
      // Identity check, not a blind null: reset() clears the handle and a
      // newer load may own it by the time this stale future settles.
      if (identical(_loading, load)) {
        _loading = null;
      }
    });
    _loading = load;
    return load;
  }

  /// Re-reads the liked list from the backend.
  Future<void> refresh() async {
    _ensureAuthSubscription();
    final generation = _generation;
    final rows = await _restaurantRepository.likedRestaurants();
    if (generation != _generation) {
      return;
    }
    _liked = rows;
    _likedIds = {for (final restaurant in rows) restaurant.id};
    _loaded = true;
    notifyListeners();
  }

  /// Optimistic: the heart fills immediately, the write follows. On failure
  /// the heart empties again and the error is rethrown for the caller's
  /// toast. The full list re-syncs afterwards so ordering comes from the
  /// server, not from guesswork here.
  Future<void> like(
    int restaurantId, {
    String source = 'deck',
    bool superLike = false,
    double? latitude,
    double? longitude,
  }) async {
    final generation = _generation;
    _likedIds.add(restaurantId);
    notifyListeners();

    try {
      await _swipeRepository.record(
        restaurantId: restaurantId,
        liked: true,
        superLike: superLike,
        source: source,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (_) {
      if (generation == _generation) {
        _likedIds.remove(restaurantId);
        notifyListeners();
      }
      rethrow;
    }

    // Best-effort: the id set above is already correct; this only fetches the
    // row data and ordering for the Like tab.
    await refresh().catchError((Object error) {
      debugPrint('Refreshing likes failed: $error');
    });
  }

  Future<void> unlike(int restaurantId, {String source = 'likes'}) async {
    final generation = _generation;
    final index = _liked.indexWhere((r) => r.id == restaurantId);
    final removed = index >= 0 ? _liked[index] : null;

    if (!_likedIds.remove(restaurantId) && removed == null) {
      return;
    }
    if (removed != null) {
      _liked = List.of(_liked)..removeAt(index);
    }
    notifyListeners();

    try {
      await _swipeRepository.record(
        restaurantId: restaurantId,
        liked: false,
        source: source,
      );
    } catch (_) {
      if (generation == _generation) {
        _likedIds.add(restaurantId);
        // A concurrent refresh may have republished the list with the row
        // still in it (the unlike never landed); reinserting blindly would
        // render the restaurant twice.
        final alreadyBack = _liked.any((r) => r.id == restaurantId);
        if (removed != null && !alreadyBack) {
          _liked = List.of(_liked)
            ..insert(index.clamp(0, _liked.length), removed);
        }
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Forgets everything; the next [ensureLoaded] refetches for whoever is
  /// signed in then.
  void reset() {
    _generation++;
    _liked = const [];
    _likedIds = <int>{};
    _loaded = false;
    _loading = null;
    notifyListeners();
  }

  void _ensureAuthSubscription() {
    if (!_followAuthChanges || _authSubscription != null) {
      return;
    }
    final changes = _authEvents.changes;
    if (changes == null) {
      return;
    }
    _accountId = _authEvents.currentUserId;
    _authSubscription = changes.listen((state) {
      switch (state.event) {
        case AuthChangeEvent.signedOut:
          _accountId = null;
          reset();
        case AuthChangeEvent.signedIn:
          // The auth stream replays its latest event to every new listener,
          // so the first signedIn seen here is usually the very session this
          // controller is already loading for. Resetting on it would discard
          // that load and leave the Like tab spinning with no error — only
          // an actual change of account may dump the cache.
          final incoming = state.session?.user.id;
          if (incoming != _accountId) {
            _accountId = incoming;
            reset();
          }
        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
