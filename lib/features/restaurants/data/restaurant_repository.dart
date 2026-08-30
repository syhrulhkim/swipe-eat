import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/single_row.dart';
import '../models/cuisine_count.dart';
import '../models/restaurant.dart';
import '../models/swipe_stats.dart';

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
  /// cannot find. [cuisineId] narrows the rows to one cuisine, which is how a
  /// tap on an Explore category tile becomes a list. The RPC caps at 100 rows,
  /// so with no radius set a 288-row catalog does not fit: the closest 100
  /// win, which is the right 100 for a browse surface.
  Future<List<Restaurant>> search({
    String? query,
    double? latitude,
    double? longitude,
    int? cuisineId,
    int limit = 100,
  }) async {
    final rows = await _client
        .rpc<dynamic>('search_restaurants', params: {
          if (query != null && query.trim().isNotEmpty)
            'p_query': query.trim(),
          'p_limit': limit,
          if (latitude != null) 'p_latitude': latitude,
          if (longitude != null) 'p_longitude': longitude,
          if (cuisineId != null) 'p_cuisine_id': cuisineId,
        })
        .select(_deckColumns)
        .timeout(_timeout);

    return rows.map(Restaurant.fromJson).toList();
  }

  /// The Visited segment: places with a `visited_at` stamp, latest visit
  /// first.
  Future<List<Restaurant>> visitedRestaurants({
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await _client
        .rpc<dynamic>('get_visited_restaurants', params: {
          'p_limit': limit,
          'p_offset': offset,
        })
        .select(_deckColumns)
        .timeout(_timeout);

    return rows.map(Restaurant.fromJson).toList();
  }

  /// The Reviewed segment: places the user has written a review for, most
  /// recently reviewed first.
  Future<List<Restaurant>> reviewedRestaurants({
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await _client
        .rpc<dynamic>('get_reviewed_restaurants', params: {
          'p_limit': limit,
          'p_offset': offset,
        })
        .select(_deckColumns)
        .timeout(_timeout);

    return rows.map(Restaurant.fromJson).toList();
  }

  /// Which liked rows carry the super-like flag — the Liked grid's star
  /// badges.
  Future<Set<int>> superLikedIds() async {
    final rows = await _client
        .rpc<dynamic>('get_super_liked_ids')
        .timeout(_timeout) as List<dynamic>;

    return {for (final id in rows) (id as num).toInt()};
  }

  /// Today's shortlist: the head of the deck ranking, unswiped rows only.
  /// The rail thins out as the user swipes, and reshuffles at midnight with
  /// the deck seed. No coordinates passed — the RPC resolves passport, then
  /// the stored fix, server-side. Server caps the limit at 20.
  Future<List<Restaurant>> topPicks({int limit = 10}) async {
    final rows = await _client
        .rpc<dynamic>('get_top_picks', params: {'p_limit': limit})
        .select(_deckColumns)
        .timeout(_timeout);

    return rows.map(Restaurant.fromJson).toList();
  }

  /// The daily-limit and streak chip.
  Future<SwipeStats> swipeStats() async {
    final response =
        await _client.rpc<dynamic>('get_swipe_stats').timeout(_timeout);

    return SwipeStats.fromJson(asSingleRow(response));
  }

  /// The Explore grid: every active cuisine, its restaurant count and a cover
  /// photo. Ordered by count descending server-side — the biggest categories
  /// lead, and the client must not re-sort.
  Future<List<CuisineCount>> cuisineCounts() async {
    final rows = await _client
        .rpc<dynamic>('get_cuisine_counts')
        .timeout(_timeout) as List<dynamic>;

    return rows
        .map((row) => CuisineCount.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
