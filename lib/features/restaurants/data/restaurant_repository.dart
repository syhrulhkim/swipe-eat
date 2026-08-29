import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/restaurant.dart';

class RestaurantRepository {
  RestaurantRepository({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;

  /// Resolved per call rather than in the constructor, so pages can be built
  /// in tests without an initialised `Supabase.instance` — the failure
  /// belongs to the request, where it can be caught and retried.
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  static const _deckColumns = 'id, name, tag, details, brand_color, rating, '
      'latitude, longitude, video_url, '
      'restaurant_images(url, position), reviews(author_name, body)';

  // A stalled connection would otherwise never resolve; surface it as an
  // error so the UI can offer a retry instead of spinning forever.
  static const _timeout = Duration(seconds: 15);

  /// The ranked, already-deduplicated deck. Ranking, the radius filter, taste
  /// weighting and "don't re-show swiped cards" all live in the `get_deck`
  /// RPC; the rows come back in serve order, so callers must not re-sort.
  ///
  /// Pass a real fix when there is one; null lets the RPC fall back to the
  /// coordinates stored on the profile, which is exactly right for users who
  /// denied location.
  Future<List<Restaurant>> fetchDeck({
    double? latitude,
    double? longitude,
    int limit = 30,
  }) async {
    final rows = await _client
        .rpc<dynamic>('get_deck', params: {
          'p_limit': limit,
          if (latitude != null) 'p_latitude': latitude,
          if (longitude != null) 'p_longitude': longitude,
        })
        .select(_deckColumns)
        .timeout(_timeout);

    return rows.map(Restaurant.fromJson).toList();
  }

  /// One restaurant by id, for the detail page opened from a link rather than
  /// from a card that already carries its data.
  ///
  /// Null means "no such restaurant for this user" — either it is gone or the
  /// catalog policy hides it — which the page shows as not found rather than
  /// as a failure to retry.
  Future<Restaurant?> fetchById(int id) async {
    final rows = await _client
        .from('restaurants')
        .select(_deckColumns)
        .eq('id', id)
        .limit(1)
        .timeout(_timeout);

    if (rows.isEmpty) {
      return null;
    }

    return Restaurant.fromJson(rows.first);
  }

  /// The Like tab: newest like first, straight from the swipes table.
  Future<List<Restaurant>> likedRestaurants({int limit = 200}) async {
    final rows = await _client
        .rpc<dynamic>('get_liked_restaurants', params: {'p_limit': limit})
        .select(_deckColumns)
        .timeout(_timeout);

    return rows.map(Restaurant.fromJson).toList();
  }

  /// Explore. A null [query] browses the catalog; either way the RPC applies
  /// the same radius rule as the deck — what the user cannot be served, they
  /// cannot find. The RPC caps at 100 rows, so with no radius set a 288-row
  /// catalog does not fit: the closest 100 win, which is the right 100 for a
  /// map.
  Future<List<Restaurant>> search({
    String? query,
    double? latitude,
    double? longitude,
    int limit = 100,
  }) async {
    final rows = await _client
        .rpc<dynamic>('search_restaurants', params: {
          if (query != null && query.trim().isNotEmpty)
            'p_query': query.trim(),
          'p_limit': limit,
          if (latitude != null) 'p_latitude': latitude,
          if (longitude != null) 'p_longitude': longitude,
        })
        .select(_deckColumns)
        .timeout(_timeout);

    return rows.map(Restaurant.fromJson).toList();
  }
}
