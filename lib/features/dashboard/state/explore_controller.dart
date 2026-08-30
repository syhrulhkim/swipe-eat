import 'package:flutter/foundation.dart';

import '../../restaurants/data/restaurant_repository.dart';
import '../../restaurants/models/cuisine_count.dart';
import '../../restaurants/models/restaurant.dart';

/// The cuisine tiles the Explore grid shows, plus the Top Picks rail above
/// them.
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

  /// Today's shortlist. Best-effort: empty on failure, and the rail simply
  /// does not render — the grid is the tab's contract, the rail a bonus.
  List<Restaurant> _topPicks = const [];
  List<Restaurant> get topPicks => _topPicks;

  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    final topPicksFuture = _restaurants
        .topPicks()
        .catchError((Object error) {
      debugPrint('Top picks load failed: $error');
      return const <Restaurant>[];
    });

    try {
      _cuisines = await _restaurants.cuisineCounts();
      _topPicks = await topPicksFuture;
      _loading = false;
      notifyListeners();
    } on Object catch (error) {
      debugPrint('Explore load failed: $error');
      _topPicks = await topPicksFuture;
      _loading = false;
      _error = 'Could not load categories.';
      notifyListeners();
    }
  }
}
