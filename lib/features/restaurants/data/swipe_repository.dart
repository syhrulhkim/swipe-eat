import 'package:supabase_flutter/supabase_flutter.dart';

import '../../plans/models/plan.dart' show formatPlanDate, parsePlanDate;
import 'visit_prompt_cache.dart';

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

  /// D147: the whole visit prompt in one call. "I didn't go" cancels the plan
  /// D108 assumed was kept; "I went" stamps `visited_at`; stars and a line, if
  /// the user left any, become the review.
  ///
  /// [rating] is 1–5 or null. A null [body] and an empty one mean the same
  /// thing to the server, so the sheet does not have to decide which it sends.
  Future<void> recordVisitAnswer({
    required int restaurantId,
    required bool went,
    int? rating,
    String? body,
    int? planId,
  }) async {
    await _client.rpc<dynamic>('record_visit_answer', params: {
      'p_restaurant_id': restaurantId,
      'p_went': went,
      if (rating != null) 'p_rating': rating,
      if (body != null) 'p_body': body,
      if (planId != null) 'p_plan_id': planId,
    }).timeout(_timeout);
  }

  /// The plan worth asking about — the caller's most recent past plan they
  /// have not rated — or null when there is none.
  ///
  /// [today] is the *phone's* today, for the same reason `mark_plan_kept`
  /// takes one: the database clock is UTC and Kuala Lumpur is +8.
  Future<PendingVisit?> nextVisitPrompt({
    required String userId,
    required DateTime today,
  }) async {
    final rows = await _client.rpc<dynamic>(
      'next_visit_prompt',
      params: {'p_today': formatPlanDate(today)},
    ).timeout(_timeout);

    if (rows is! List || rows.isEmpty) {
      return null;
    }
    final row = rows.first as Map<String, dynamic>;
    final restaurantId = (row['restaurant_id'] as num?)?.toInt();
    if (restaurantId == null) {
      return null;
    }

    return PendingVisit(
      userId: userId,
      restaurantId: restaurantId,
      name: row['name'] as String? ?? 'that place',
      openedAt: parsePlanDate(row['plan_date'] as String? ?? ''),
      planId: (row['plan_id'] as num?)?.toInt(),
    );
  }
}
