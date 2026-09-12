import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friend_plan.dart';
import '../models/plan.dart';

/// The two numbers the profile shows. Server-computed, because "consecutive
/// weeks" is a question about rows the client does not hold — the calendar
/// only ever loads from the first of this month forward, and the streak
/// reaches back through months it has never seen.
class PlanStats {
  const PlanStats({this.plansKept = 0, this.streakWeeks = 0});

  factory PlanStats.fromJson(Map<String, dynamic> json) {
    return PlanStats(
      plansKept: (json['plans_kept'] as num?)?.toInt() ?? 0,
      streakWeeks: (json['streak_weeks'] as num?)?.toInt() ?? 0,
    );
  }

  final int plansKept;
  final int streakWeeks;
}

/// Reads and writes `plans` — everything behind the Calendar tab and behind
/// "Lock it in".
///
/// Own-row RLS does the scoping, so nothing here filters by owner: a query
/// that forgot to would come back empty rather than come back with somebody
/// else's evening.
class PlansRepository {
  PlansRepository({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;

  /// Resolved per call rather than in the constructor, so a page can be built
  /// in a test without an initialised `Supabase.instance` — the failure
  /// belongs to the request, where it can be caught and retried.
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  /// Everything a plan row draws. `profiles` is deliberately absent from the
  /// members join: it is not selectable for anyone but its owner, so asking
  /// for names would return nulls that look like missing data rather than
  /// like a permission the app has not been granted yet.
  static const _columns = 'id, restaurant_id, plan_date, plan_time, '
      'time_label, with_friends, shared_with_friends, status, created_at, '
      'restaurants(id, name, tag, neighbourhood, latitude, longitude, '
      'restaurant_images(url, position)), '
      'plan_members(user_id, status)';

  // A stalled connection would otherwise never resolve; surface it as an error
  // so the calendar can offer a retry instead of spinning forever.
  static const _timeout = Duration(seconds: 15);

  /// This month and everything after it, in the order the calendar draws it.
  ///
  /// [from] is the first day to include — the controller passes the first of
  /// the current month, so the grid can show days already gone by that still
  /// have a plan on them, and the sections below it can start at today.
  Future<List<Plan>> list({required DateTime from, int limit = 300}) async {
    final rows = await _client
        .from('plans')
        .select(_columns)
        .gte('plan_date', formatPlanDate(from))
        .neq('status', 'cancelled')
        .order('plan_date', ascending: true)
        .order('plan_time', ascending: true, nullsFirst: false)
        .limit(limit)
        .timeout(_timeout);

    return rows.map(Plan.fromJson).toList();
  }

  /// "Lock it in". Returns the plan's id.
  ///
  /// The RPC upserts on owner + restaurant + day (D107), so picking the same
  /// place for the same day twice moves the time rather than stacking a second
  /// row the calendar would draw twice. It returns the bare `plans` row with
  /// no joins on it, which is not enough to draw with — the controller
  /// refreshes rather than this method faking a half-populated [Plan].
  Future<int> create({
    required int restaurantId,
    required DateTime date,
    String? time,
    String? timeLabel,
    bool withFriends = false,
    bool shared = false,
  }) async {
    final row = await _client.rpc<dynamic>(
      'create_plan',
      params: {
        'p_restaurant_id': restaurantId,
        'p_plan_date': formatPlanDate(date),
        'p_plan_time': time,
        'p_time_label': timeLabel,
        'p_with_friends': withFriends,
        'p_shared': shared,
      },
    ).timeout(_timeout);

    return ((row as Map<String, dynamic>)['id'] as num).toInt();
  }

  /// Cancels rather than deletes: a cancelled plan still counts as a day the
  /// user was thinking about, and un-cancelling is what re-picking the day
  /// does.
  Future<void> cancel(int planId) async {
    await _client
        .from('plans')
        .update({'status': PlanStatus.cancelled.wire})
        .eq('id', planId)
        .timeout(_timeout);
  }

  /// Flips "Share with friends" on a plan I own (D153). An owner `.update`,
  /// like [cancel] — `own plans all` carries it, so there is no RPC to write.
  Future<void> setShared(int planId, bool shared) async {
    await _client
        .from('plans')
        .update({'shared_with_friends': shared})
        .eq('id', planId)
        .timeout(_timeout);
  }

  /// The shared evenings of people I am friends with, from [from] forward.
  ///
  /// A definer RPC rather than a select: no policy on `plans` exposes a row to
  /// a non-member, and a third permissive select policy would widen every
  /// other read as well (D153).
  Future<List<FriendPlan>> friendsPlans({
    required DateTime from,
    int limit = 100,
  }) async {
    final rows = await _client.rpc<dynamic>(
      'get_friends_plans',
      params: {'p_from': formatPlanDate(from), 'p_limit': limit},
    ).timeout(_timeout);

    return [
      for (final row in (rows as List<dynamic>? ?? const []))
        FriendPlan.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// Moves a plan to another slot without moving the day.
  Future<void> setTime(
    int planId, {
    String? time,
    String? timeLabel,
  }) async {
    await _client
        .from('plans')
        .update({'plan_time': time, 'time_label': timeLabel})
        .eq('id', planId)
        .timeout(_timeout);
  }

  /// D108: flips the caller's past `planned` rows to `kept`.
  ///
  /// [today] is the *phone's* today. The database clock is UTC and Kuala
  /// Lumpur is +8, so leaving the server to decide would mark a 23:30 plan
  /// kept eight hours before the evening it belongs to.
  Future<int> markKept(DateTime today) async {
    final count = await _client.rpc<dynamic>(
      'mark_plan_kept',
      params: {'p_today': formatPlanDate(today)},
    ).timeout(_timeout);

    return (count as num?)?.toInt() ?? 0;
  }

  /// The profile's two figures. Same `p_today` reasoning as [markKept].
  Future<PlanStats> stats(DateTime today) async {
    final rows = await _client.rpc<dynamic>(
      'plan_stats',
      params: {'p_today': formatPlanDate(today)},
    ).timeout(_timeout);

    // A `returns table` RPC comes back as a list of one row.
    final list = rows as List<dynamic>? ?? const [];
    if (list.isEmpty) {
      return const PlanStats();
    }
    return PlanStats.fromJson(list.first as Map<String, dynamic>);
  }
}
