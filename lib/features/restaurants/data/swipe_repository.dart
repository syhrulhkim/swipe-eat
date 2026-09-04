import 'package:supabase_flutter/supabase_flutter.dart';

/// Writes swipes to the backend. A swipe row is both signals at once: `liked`
/// feeds the Like tab, and the row's existence is "seen" — `get_deck` will not
/// re-serve it. Re-swiping the same restaurant upserts, so every call is safe
/// to retry.
class SwipeRepository {
  SwipeRepository({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;

  /// Lazy for the same reason as [RestaurantRepository]: construction must
  /// not assert on an uninitialised `Supabase.instance`.
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  static const _timeout = Duration(seconds: 15);

  Future<void> record({
    required int restaurantId,
    required bool liked,
    bool later = false,
    String source = 'deck',
    double? latitude,
    double? longitude,
  }) async {
    await _client.rpc<dynamic>('record_swipe', params: {
      'p_restaurant_id': restaurantId,
      'p_liked': liked,
      'p_source': source,
      // `p_super_like` is the wire name for "save for later". The design
      // retired the super like and rebound the up gesture to Later, so the
      // client speaks of `later` everywhere and this is the one place the old
      // column name survives. Renaming `swipes.super_like` to `later` is a
      // migration against the live database, so it is deliberately not
      // bundled with a client change — see docs/Redesign/GAP-ANALYSIS.md §2.
      //
      // Only sent when set, so an ordinary swipe's payload is unchanged.
      if (later) 'p_super_like': true,
      if (latitude != null) 'p_latitude': latitude,
      if (longitude != null) 'p_longitude': longitude,
    }).timeout(_timeout);
  }

  /// Stamps (or clears) `visited_at` on the swipe row; the backend inserts a
  /// non-deck row if the place was never swiped, so this works from any
  /// surface.
  Future<void> markVisited({
    required int restaurantId,
    bool visited = true,
  }) async {
    await _client.rpc<dynamic>('mark_visited', params: {
      'p_restaurant_id': restaurantId,
      'p_visited': visited,
    }).timeout(_timeout);
  }
}
