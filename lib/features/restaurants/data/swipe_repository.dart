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
    bool superLike = false,
    String source = 'deck',
    double? latitude,
    double? longitude,
  }) async {
    await _client.rpc<dynamic>('record_swipe', params: {
      'p_restaurant_id': restaurantId,
      'p_liked': liked,
      'p_source': source,
      // The backend only stores a super like on a liked row, so sending it on
      // a pass is harmless — but only sent at all when set, to keep the
      // payload identical to before for every ordinary swipe.
      if (superLike) 'p_super_like': true,
      if (latitude != null) 'p_latitude': latitude,
      if (longitude != null) 'p_longitude': longitude,
    }).timeout(_timeout);
  }

  /// Deletes the swipe row outright. This is rewind, not unlike: an unlike
  /// keeps the row (still "seen", never re-dealt), while an undo makes the
  /// restaurant swipeable again as if it had never been served.
  Future<void> undo({required int restaurantId}) async {
    await _client.rpc<dynamic>('undo_swipe', params: {
      'p_restaurant_id': restaurantId,
    }).timeout(_timeout);
  }
}
