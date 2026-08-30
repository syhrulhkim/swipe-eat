import 'package:flutter/foundation.dart';

import '../../restaurants/data/restaurant_repository.dart';
import '../../restaurants/models/cuisine_count.dart';

/// The cuisine tiles the Explore grid shows.
///
/// Counts are catalog-wide, not radius-bound (see [CuisineCount]), so unlike
/// the old map this controller has no reason to watch the profile radius —
/// the per-cuisine list applies the radius when a tile is opened.
class ExploreController extends ChangeNotifier {
  ExploreController({RestaurantRepository? restaurants})
      : _restaurants = restaurants ?? RestaurantRepository();

  final RestaurantRepository _restaurants;

  List<CuisineCount> _cuisines = const [];
  List<CuisineCount> get cuisines => _cuisines;

  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _cuisines = await _restaurants.cuisineCounts();
      _loading = false;
      notifyListeners();
    } on Object catch (error) {
      debugPrint('Explore load failed: $error');
      _loading = false;
      _error = 'Could not load categories.';
      notifyListeners();
    }
  }
}
