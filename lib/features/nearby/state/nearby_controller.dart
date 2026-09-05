import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/user_location.dart';
import '../../auth/models/app_user.dart';
import '../../auth/state/auth_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../../restaurants/models/restaurant.dart';
import '../../restaurants/state/deck_handoff.dart';
import '../data/nearby_repository.dart';
import '../domain/nearby_format.dart';
import '../models/nearby_place.dart';

/// How many pins the map draws. The RPC returns up to 60 so the results bar's
/// counts and its minimum price describe the whole radius; only the nearest
/// [kNearbyPinLimit] are drawn, because a blob is 76 px wide and any more
/// than this is a pile, not a map.
const int kNearbyPinLimit = 30;

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
        _now = now ?? DateTime.now {
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

  /// The clock the open lines are read against. Injected so "closing within
  /// the hour" is a one-line test rather than a wait.
  DateTime get now => _now();

  static double _initialRadiusKm(AppUser? user) {
    final stored = user?.searchRadiusKm;
    if (stored == null || stored <= 0) {
      return kNearbyDefaultRadiusKm;
    }
    return nearestNearbyRadiusStep(stored.toDouble());
  }

  /// Only the discovery filters. The radius is the stepper's, not the
  /// profile's, once the screen is open — the map would jump under the user's
  /// finger if Settings could move it.
  static String _filterSignature(AppUser? user) {
    if (user == null) {
      return '';
    }
    return [
      user.filterMinRating,
      user.filterCuisineIds.join(','),
      user.filterDietaryTagIds.join(','),
    ].join('|');
  }

  String? _appliedFilterSignature;

  double _radiusKm = kNearbyDefaultRadiusKm;

  /// How wide the circle is, in kilometres. Always one of
  /// [kNearbyRadiusSteps].
  double get radiusKm => _radiusKm;

  bool get canWiden => _radiusKm < kNearbyRadiusSteps.last;
  bool get canNarrow => _radiusKm > kNearbyRadiusSteps.first;

  NearbyOrigin? _origin;

  /// Where the map is centred and what the query measured from: the device
  /// fix when there is one, else the coordinates the profile stored.
  NearbyOrigin? get origin => _origin;

  List<NearbyPlace> _places = const [];

  /// Everything inside the radius, closest first.
  List<NearbyPlace> get places => _places;

  /// The pins the map draws: the nearest [kNearbyPinLimit].
  List<NearbyPlace> get pins => _places.length <= kNearbyPinLimit
      ? _places
      : _places.sublist(0, kNearbyPinLimit);

  /// The two closest results are drawn big. Nothing else about them differs —
  /// it is the map's way of saying "start here".
  bool isProminent(NearbyPlace place) {
    final index = _places.indexOf(place);
    return index >= 0 && index < 2;
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

  @override
  void dispose() {
    authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final signature = _filterSignature(authController.user);
    if (signature == _appliedFilterSignature) {
      return;
    }
    _appliedFilterSignature = signature;
    unawaited(load());
  }

  Future<void> load() async {
    final generation = ++_loadGeneration;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final origin = await _resolveOrigin();
      if (generation != _loadGeneration) {
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
      if (generation != _loadGeneration) {
        return;
      }

      _places = places;
      _loading = false;
      notifyListeners();
    } on Object catch (error) {
      debugPrint('Nearby load failed: $error');
      if (generation != _loadGeneration) {
        return;
      }
      _places = const [];
      _loading = false;
      _error = 'Could not load the map. Check your connection.';
      notifyListeners();
    }
  }

  /// The device fix, or the coordinates the profile stored for an account that
  /// has never granted location on this device. Null means neither exists,
  /// which is the empty state.
  Future<NearbyOrigin?> _resolveOrigin() async {
    final position = await _resolvePosition();
    if (!isFallbackUserPosition(position)) {
      return NearbyOrigin(position.latitude, position.longitude);
    }

    // A fallback is not a fix — centring on it would put the user in a town
    // they have never been to and call it "away from you".
    try {
      return await _repository.storedOrigin();
    } on Object catch (error) {
      debugPrint('Nearby stored origin failed: $error');
      return null;
    }
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
    if (km == _radiusKm) {
      return Future<void>.value();
    }
    _radiusKm = km;
    notifyListeners();
    return load();
  }

  /// "Swipe all N": hands every result to the deck. The dashboard listens to
  /// the same hand-off and brings the deck forward.
  void swipeAll() {
    if (_places.isEmpty) {
      return;
    }

    final restaurants = <Restaurant>[
      for (final place in _places) place.restaurant,
    ];
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
  }) async {
    try {
      final user = await _profiles.setDiscoveryFilters(
        cuisineIds: cuisineIds,
        dietaryTagIds: dietaryTagIds,
        minRating: minRating,
      );
      authController.applyUser(user);
      return true;
    } on Object catch (error) {
      debugPrint('Nearby discovery filters write failed: $error');
      return false;
    }
  }
}
