import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/user_location.dart';
import '../../../core/ui/design_tokens.dart';
import '../../auth/models/app_user.dart';
import '../../auth/state/auth_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../../restaurants/domain/opening_hours.dart';
import '../../restaurants/models/restaurant.dart';
import '../../restaurants/state/deck_handoff.dart';
import '../data/nearby_repository.dart';
import '../domain/nearby_format.dart';
import '../models/nearby_place.dart';

/// How many pins the map draws. The RPC returns up to 60 so the results bar's
/// counts and its minimum price describe the whole radius; only the nearest
/// [kNearbyPinLimit] are drawn. Five is a view, not a pile: each pin keeps its
/// name and cuisine legible, and the five closest are the five the user is
/// about to choose between. "Swipe all N" is the way to the rest.
const int kNearbyPinLimit = 5;

/// The RPC's page size: what the results bar counts over.
const int kNearbyFetchLimit = 60;

/// Everything the Nearby map knows: where the user is, how wide the circle is,
/// and what is inside it.
///
/// Repositories and the position resolver arrive through the constructor, so
/// the whole screen can be driven in a test with no Supabase client and no
/// platform channel.
class NearbyController extends ChangeNotifier {
  NearbyController({
    required this.authController,
    NearbyRepository? repository,
    ProfileRepository? profiles,
    DeckHandoff? handoff,
    Future<Position> Function()? resolvePosition,
    DateTime Function()? now,
  })  : _repository = repository ?? NearbyRepository(),
        _profiles = profiles ?? ProfileRepository(),
        _handoff = handoff ?? DeckHandoff.instance,
        _resolvePosition = resolvePosition ?? resolveUserPosition,
        _now = now ?? OpeningHours.kualaLumpurNow {
    _radiusKm = _initialRadiusKm(authController.user);
    _appliedFilterSignature = _filterSignature(authController.user);
    authController.addListener(_onAuthChanged);
  }

  final AuthController authController;
  final NearbyRepository _repository;
  final ProfileRepository _profiles;
  final DeckHandoff _handoff;
  final Future<Position> Function() _resolvePosition;
  final DateTime Function() _now;

  /// The clock the open lines are read against — Kuala Lumpur time, the zone
  /// the catalogue's hours are written in and the one the server's
  /// `is_open_at` evaluates in, so a pin and the "Open now" count can never
  /// disagree for a user roaming abroad. Injected so "closing within the hour"
  /// is a one-line test rather than a wait.
  DateTime get now => _now();

  static double _initialRadiusKm(AppUser? user) {
    final stored = user?.searchRadiusKm;
    if (stored == null || stored <= 0) {
      return kNearbyDefaultRadiusKm;
    }
    return nearestNearbyRadiusStep(stored.toDouble());
  }

  /// Every server-side rule the map's query obeys except the radius. The
  /// radius is the stepper's, not the profile's, once the user has touched it
  /// — the map would jump under their finger if Settings could move it.
  ///
  /// The diet and budget answers belong here because `get_nearby` applies them
  /// as hard rules (D105): a place the user cannot eat at is a wrong pin, not
  /// a worse one, so turning one on has to refetch.
  static String _filterSignature(AppUser? user) {
    if (user == null) {
      return '';
    }
    return [
      user.filterMinRating,
      user.filterCuisineIds.join(','),
      user.filterDietaryTagIds.join(','),
      user.halalOnly,
      user.vegetarian,
      user.budgetMax,
    ].join('|');
  }

  String? _appliedFilterSignature;

  double _radiusKm = kNearbyDefaultRadiusKm;

  /// True once the stepper has moved the circle. Until then the circle is only
  /// a default the controller guessed at, and a profile that hydrates later is
  /// allowed to replace it — see [_onAuthChanged].
  bool _radiusTouched = false;

  /// How wide the circle is, in kilometres. Always one of
  /// [kNearbyRadiusSteps].
  double get radiusKm => _radiusKm;

  bool get canWiden => _radiusKm < kNearbyRadiusSteps.last;
  bool get canNarrow => _radiusKm > kNearbyRadiusSteps.first;

  NearbyOrigin? _origin;

  /// Where the map is centred and what the query measured from: the device
  /// fix, else the coordinates the profile stored. The same chain
  /// `deck_scored` uses, so the map and the deck cannot disagree about where
  /// the user is (D121).
  NearbyOrigin? get origin => _origin;

  List<NearbyPlace> _places = const [];

  /// Everything inside the radius, closest first.
  List<NearbyPlace> get places => _places;

  /// The pins the map draws: the nearest [kNearbyPinLimit].
  List<NearbyPlace> get pins => _places.length <= kNearbyPinLimit
      ? _places
      : _places.sublist(0, kNearbyPinLimit);

  /// The two closest results carry the ember ring. Nothing else about them
  /// differs — it is the map's way of saying "start here".
  bool isProminent(NearbyPlace place) {
    final index = _places.indexOf(place);
    return index >= 0 && index < 2;
  }

  /// The blob's diameter for [place]: the closer, the larger. Full size at
  /// your feet, [kNearbyPinSmallSize] at the edge of the circle, linear in
  /// between — so a glance at the map says how far without reading a badge.
  double pinSizeFor(NearbyPlace place) {
    final radius = _radiusKm <= 0 ? 1.0 : _radiusKm;
    final t = (place.distanceKm / radius).clamp(0.0, 1.0);
    return kNearbyPinBigSize + (kNearbyPinSmallSize - kNearbyPinBigSize) * t;
  }

  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  /// True when neither the device nor the profile knows where the user is —
  /// the one state the map cannot draw itself out of.
  bool _needsLocation = false;
  bool get needsLocation => _needsLocation;

  /// How many of the results are open right now. Places with unknown hours
  /// are not counted: the bar says how many are open, not how many might be.
  int get openNowCount =>
      _places.where((place) => place.openNow == true).length;

  /// The cheapest dish price any result names, or null when none of them do —
  /// the bar hides the figure rather than inventing one.
  int? get minPriceFrom {
    int? cheapest;
    for (final place in _places) {
      final price = place.restaurant.priceFrom;
      if (price == null || price <= 0) {
        continue;
      }
      if (cheapest == null || price < cheapest) {
        cheapest = price;
      }
    }
    return cheapest;
  }

  /// Guards overlapping loads (init, retry, and every radius tap): only the
  /// newest may publish, so a slow small circle cannot land on top of a fast
  /// big one.
  int _loadGeneration = 0;

  bool _disposed = false;

  /// True when [generation] no longer speaks for this controller: a newer load
  /// has started, or the controller is gone. Either way the run that asks must
  /// return without notifying — a notification after dispose throws, and a
  /// stale one paints the wrong circle.
  bool _isStale(int generation) =>
      _disposed || generation != _loadGeneration;

  @override
  void dispose() {
    _disposed = true;
    // Anything still awaiting belongs to a generation that no longer exists,
    // so it goes quiet instead of notifying a disposed notifier.
    _loadGeneration += 1;
    authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final user = authController.user;
    var refetch = false;

    // The tab can be built before the profile has hydrated, in which case the
    // map opened on the default circle rather than the user's. Adopt theirs
    // when it arrives — but never once the stepper has been touched: a circle
    // the thumb set is the user's answer, and Settings must not overrule it.
    if (!_radiusTouched) {
      final adopted = _initialRadiusKm(user);
      if (adopted != _radiusKm) {
        _radiusKm = adopted;
        refetch = true;
      }
    }

    final signature = _filterSignature(user);
    if (signature != _appliedFilterSignature) {
      _appliedFilterSignature = signature;
      refetch = true;
    }

    if (!refetch) {
      return;
    }
    notifyListeners();
    unawaited(load());
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
      final origin = await _resolveOrigin();
      if (_isStale(generation)) {
        return;
      }

      if (origin == null) {
        _origin = null;
        _places = const [];
        _loading = false;
        _needsLocation = true;
        notifyListeners();
        return;
      }

      _origin = origin;
      _needsLocation = false;

      final places = await _repository.fetchNearby(
        latitude: origin.latitude,
        longitude: origin.longitude,
        radiusKm: _radiusKm,
        limit: kNearbyFetchLimit,
      );
      if (_isStale(generation)) {
        return;
      }

      _places = places;
      _loading = false;
      notifyListeners();
    } on Object catch (error) {
      debugPrint('Nearby load failed: $error');
      if (_isStale(generation)) {
        return;
      }
      _places = const [];
      _loading = false;
      _error = 'Could not load the map. Check your connection.';
      notifyListeners();
    }
  }

  /// The passport pin, else the device fix, else the coordinates the profile
  /// stored for an account that has never granted location on this device.
  /// Null means none of the three exists, which is the empty state.
  ///
  /// The passport is resolved *here* rather than inside `get_nearby`, unlike
  /// `deck_scored` (D12): the client draws the me-dot and fits the camera to
  /// this origin, so an RPC that quietly swapped in a different one would
  /// measure every distance from a place the map is not showing.
  /// The device fix, else the coordinates the profile stored for an account
  /// that has never granted location on this device. Null means neither
  /// exists, which is the empty state.
  ///
  /// The passport pin used to come first (D12). D84 retired passport, but the
  /// column kept winning this chain — and a stale pin nobody could see was
  /// silently centring the map on a city the user had left, with every
  /// distance measured from there. Removed 2026-09-10 (D121).
  Future<NearbyOrigin?> _resolveOrigin() async {
    final position = await _resolvePosition();
    if (!isFallbackUserPosition(position)) {
      return NearbyOrigin(position.latitude, position.longitude);
    }

    // A fallback is not a fix — centring on it would put the user in a town
    // they have never been to and call it "away from you".
    final user = authController.user;
    final latitude = user?.lastLatitude;
    final longitude = user?.lastLongitude;
    if (latitude == null ||
        longitude == null ||
        (latitude == 0 && longitude == 0)) {
      return null;
    }
    return NearbyOrigin(latitude, longitude);
  }

  /// Widens the circle one step and refetches. The map's zoom follows.
  Future<void> widen() {
    final index = kNearbyRadiusSteps.indexOf(_radiusKm);
    if (index < 0 || index + 1 >= kNearbyRadiusSteps.length) {
      return Future<void>.value();
    }
    return setRadiusKm(kNearbyRadiusSteps[index + 1]);
  }

  /// Narrows the circle one step and refetches.
  Future<void> narrow() {
    final index = kNearbyRadiusSteps.indexOf(_radiusKm);
    if (index <= 0) {
      return Future<void>.value();
    }
    return setRadiusKm(kNearbyRadiusSteps[index - 1]);
  }

  /// Sets the radius directly. Never written to the profile: the stepper is a
  /// way of looking around, not a setting — Settings owns `search_radius_km`.
  Future<void> setRadiusKm(double km) {
    // Touched even when the circle does not move: the user has answered the
    // question, and a profile arriving late must not overrule the answer.
    _radiusTouched = true;
    if (km == _radiusKm) {
      return Future<void>.value();
    }
    _radiusKm = km;
    notifyListeners();
    return load();
  }

  /// The results "Swipe all" would actually deal: everything in the circle the
  /// user has not already swiped.
  ///
  /// The pins keep showing all of them — the map's job is to say what is
  /// there. Not repeating itself is the deck's job, and a hand-off of cards it
  /// has already shown would read as the app forgetting (D117).
  List<NearbyPlace> get unswiped => [
        for (final place in _places)
          if (!place.swiped) place,
      ];

  /// The number the bar's button carries. Zero when everything around the user
  /// is already swiped, which disables it rather than dealing an empty deck.
  int get swipeAllCount => unswiped.length;

  /// "Swipe all N": hands the unswiped results to the deck. The dashboard
  /// listens to the same hand-off and brings the deck forward.
  void swipeAll() {
    final restaurants = <Restaurant>[
      for (final place in _places)
        if (!place.swiped) place.restaurant,
    ];
    if (restaurants.isEmpty) {
      return;
    }
    _handoff.handOff(
      restaurants,
      label: 'Nearby · ${restaurants.length} '
          '${restaurants.length == 1 ? 'place' : 'places'}',
    );
  }

  /// Writes the discovery filter sheet's state to the profile. The returned
  /// row goes through [AuthController.applyUser], and it is that notification
  /// — not this method — that refetches the map and the deck alike.
  Future<bool> applyDiscoveryFilters({
    required List<int> cuisineIds,
    required List<int> dietaryTagIds,
    double? minRating,
    int? searchRadiusKm,
  }) async {
    // Read before the writes: applyUser lands after them, so asking
    // afterwards would compare the new radius against itself.
    final radiusChanged = searchRadiusKm != authController.user?.searchRadiusKm;

    // Only the last row reaches [applyUser], and only once — the same rule
    // `DeckController.applyDiscoveryFilters` follows. Applying the radius on
    // its own would refetch the map and re-deal the deck under the new radius
    // and the old filters, two loads thrown away a moment later.
    AppUser? written;
    try {
      if (radiusChanged) {
        written = await _profiles.updateSearchRadius(searchRadiusKm);
      }
      written = await _profiles.setDiscoveryFilters(
        cuisineIds: cuisineIds,
        dietaryTagIds: dietaryTagIds,
        minRating: minRating,
      );
      return true;
    } on Object catch (error) {
      debugPrint('Nearby discovery filters write failed: $error');
      return false;
    } finally {
      // Whatever landed is the truth now, half a sheet included.
      if (written != null) {
        authController.applyUser(written);
      }
      // The stepper's local override has to give way to a radius the sheet
      // just wrote, or the map would keep drawing the old circle.
      if (radiusChanged && authController.user?.searchRadiusKm != null) {
        _radiusTouched = false;
      }
    }
  }
}
