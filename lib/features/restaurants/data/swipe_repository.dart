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

  /// Records the swipe, and nothing else.
  ///
  /// There is no `later` here any more. A Later is a like plus a **wishlist
  /// row**, and the row is written by [WishlistRepository]; this call only
  /// says the place was liked (D94, D95). `swipes.super_like` and
  /// `p_super_like` still exist server-side, untouched, so the historic data
  /// is intact — the client simply stops writing them.
  /// [dwellMs] and [unmuted] are the deck's two implicit signals (D149):
  /// how long the card sat on top, and whether its clip had sound on when the
  /// decision was made. Nothing reads them yet. Omitted from any surface that
  /// is not the deck, where neither has a meaning, and null there says so.
  Future<void> record({
    required int restaurantId,
    required bool liked,
    String source = 'deck',
    double? latitude,
    double? longitude,
    int? dwellMs,
    bool? unmuted,
  }) async {
    await _client.rpc<dynamic>('record_swipe', params: {
      'p_restaurant_id': restaurantId,
      'p_liked': liked,
      'p_source': source,
      if (latitude != null) 'p_latitude': latitude,
      if (longitude != null) 'p_longitude': longitude,
      if (dwellMs != null) 'p_dwell_ms': dwellMs,
      if (unmuted != null) 'p_unmuted': unmuted,
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
