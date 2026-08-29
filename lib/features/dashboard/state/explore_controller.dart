import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/user_location.dart';
import '../../auth/state/auth_controller.dart';
import '../../restaurants/data/restaurant_repository.dart';
import '../../restaurants/models/restaurant.dart';

/// The restaurants the Explore map shows, and how they were fetched.
class ExploreController extends ChangeNotifier {
  ExploreController({
    required this.authController,
    RestaurantRepository? restaurants,
    Future<Position> Function()? resolvePosition,
  })  : _restaurants = restaurants ?? RestaurantRepository(),
        _resolvePosition = resolvePosition ?? resolveUserPosition {
    _appliedRadiusKm = authController.user?.searchRadiusKm;
    authController.addListener(_onAuthChanged);
  }

  final AuthController authController;
  final RestaurantRepository _restaurants;
  final Future<Position> Function() _resolvePosition;

  List<Restaurant> _rows = const [];
  List<Restaurant> get restaurants => _rows;

  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  /// The radius the rows on screen were fetched under. The tabs live in an
  /// IndexedStack that never re-inits, so a Settings change has to be listened
  /// for — the radius is a server-side filter, and stale rows would break its
  /// promise that out-of-range places are not shown.
  int? _appliedRadiusKm;

  @override
  void dispose() {
    authController.removeListener(_onAuthChanged);
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
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // The radius rule lives server-side: what the deck may not serve,
      // Explore may not show. A fallback fix is not a real location — passing
      // null lets the RPC measure from the profile's stored coordinates.
      final position = await _resolvePosition();
      final hasRealPosition = !isFallbackUserPosition(position);
      _rows = await _restaurants.search(
        latitude: hasRealPosition ? position.latitude : null,
        longitude: hasRealPosition ? position.longitude : null,
      );
      _loading = false;
      notifyListeners();
    } on Object catch (error) {
      debugPrint('Explore load failed: $error');
      _loading = false;
      _error = 'Could not load restaurants.';
      notifyListeners();
    }
  }
}
