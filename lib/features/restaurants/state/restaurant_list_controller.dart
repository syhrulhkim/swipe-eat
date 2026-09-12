import 'package:flutter/foundation.dart';

import '../models/restaurant.dart';

/// A lazily loaded, refreshable restaurant list — the Visited and Reviewed
/// segments each hold one, fed by their own RPC.
///
/// Unlike LikesController this is per-screen state, not an app singleton:
/// the hosting tab owns it, so account changes dispose it with the tab and
/// there is nothing to leak between sessions.
class RestaurantListController extends ChangeNotifier {
  RestaurantListController(this._fetch);

  final Future<List<Restaurant>> Function() _fetch;

  List<Restaurant> _rows = const [];
  List<Restaurant> get rows => List.unmodifiable(_rows);

  bool _loaded = false;
  bool get isLoaded => _loaded;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  /// Loads on the first call and is a no-op afterwards, so the segment can
  /// call it every time it becomes visible.
  Future<void> ensureLoaded() {
    if (_loaded || _loading) {
      return Future.value();
    }
    return refresh();
  }

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _rows = await _fetch();
      _loaded = true;
    } on Object catch (error) {
      debugPrint('Restaurant list load failed: $error');
      _error = 'Could not load this list.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
