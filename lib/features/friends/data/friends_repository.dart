import 'package:supabase_flutter/supabase_flutter.dart';

import '../../plans/models/plan.dart' show formatPlanDate;
import '../domain/phone_hash.dart';
import '../models/friend.dart';

/// Everything the friend graph is reachable through.
///
/// Every read here is an RPC rather than a table select, and that is the
/// design rather than a preference: `profiles` is owner-only under RLS, so a
/// join for somebody else's name comes back empty. The RPCs are
/// `security definer` and hand back exactly three columns (D129), which is why
/// this class has no method that could return a phone number even by accident.
class FriendsRepository {
  FriendsRepository({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;

  /// Resolved per call rather than in the constructor, for the same reason
  /// [PlansRepository] does it: a page must be buildable in a test without an
  /// initialised `Supabase.instance`.
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  static const _timeout = Duration(seconds: 15);

  /// Accepted friends, by name.
  Future<List<FriendProfile>> friends() async {
    final rows = await _client.rpc<dynamic>('get_friends').timeout(_timeout);
    return _profiles(rows);
  }

  /// Requests waiting on somebody — mine to answer, and mine to wait on.
  Future<List<FriendRequest>> requests() async {
    final rows =
        await _client.rpc<dynamic>('get_friend_requests').timeout(_timeout);
    return [
      for (final row in (rows as List<dynamic>? ?? const []))
        FriendRequest.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// Who among the address book is already here.
  ///
  /// Takes **raw numbers** and hashes them on the way past, so no caller can
  /// forget to — the only argument this method will accept is the thing that
  /// must not be sent, which makes the mistake unwriteable.
  ///
  /// An empty result and an empty input are the same call: nothing goes to the
  /// server when there is nothing to match.
  Future<List<FriendProfile>> matchContacts(
    Iterable<String> rawNumbers, {
    String callingCode = kDefaultCallingCode,
  }) async {
    final hashes = hashContacts(rawNumbers, callingCode: callingCode);
    if (hashes.isEmpty) {
      return const [];
    }

    final rows = await _client.rpc<dynamic>(
      'match_contacts',
      params: {'p_hashes': hashes},
    ).timeout(_timeout);

    return _profiles(rows);
  }

  /// Send, accept, decline or remove — one verb per tap (D131).
  Future<void> act(String userId, FriendAction action) async {
    await _client.rpc<dynamic>(
      'friend_request',
      params: {'p_user_id': userId, 'p_action': action.wire},
    ).timeout(_timeout);
  }

  /// Sends as many requests as the onboarding step selected.
  ///
  /// Sequential rather than parallel: this runs on the last screen of the
  /// wizard, six requests is the realistic maximum, and a burst of parallel
  /// RPCs would only make the failure harder to describe. A request that fails
  /// does not stop the ones behind it — the user chose all of them, and
  /// getting five friends is better than getting none.
  Future<int> sendRequests(Iterable<String> userIds) async {
    var sent = 0;
    for (final id in userIds) {
      try {
        await act(id, FriendAction.send);
        sent += 1;
      } on Object catch (_) {
        continue;
      }
    }
    return sent;
  }

  /// Who has ngap'd this place, among people the caller actually knows.
  Future<List<FriendProfile>> whoLiked(int restaurantId) async {
    final rows = await _client.rpc<dynamic>(
      'friends_who_liked',
      params: {'p_restaurant_id': restaurantId},
    ).timeout(_timeout);

    return _profiles(rows);
  }

  /// The rosters for a whole month of plans in one call.
  Future<List<PlanPerson>> planPeople(Iterable<int> planIds) async {
    final ids = planIds.toList();
    if (ids.isEmpty) {
      return const [];
    }

    final rows = await _client.rpc<dynamic>(
      'get_plan_people',
      params: {'p_plan_ids': ids},
    ).timeout(_timeout);

    return [
      for (final row in (rows as List<dynamic>? ?? const []))
        PlanPerson.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// Puts people on a plan. Returns how many rows were actually added, which
  /// is not the same as how many were asked for — somebody already invited
  /// adds nothing.
  Future<int> invite(int planId, Iterable<String> userIds) async {
    final ids = userIds.toList();
    if (ids.isEmpty) {
      return 0;
    }

    final added = await _client.rpc<dynamic>(
      'invite_to_plan',
      params: {'p_plan_id': planId, 'p_user_ids': ids},
    ).timeout(_timeout);

    return (added as num?)?.toInt() ?? 0;
  }

  /// Yes or no to an invite.
  Future<void> answerInvite(int planId, {required bool going}) async {
    await _client.rpc<dynamic>(
      'answer_plan_invite',
      params: {'p_plan_id': planId, 'p_status': going ? 'going' : 'declined'},
    ).timeout(_timeout);
  }

  /// Asks the owner of a shared plan to be let in (D153).
  ///
  /// [today] is the *phone's* today, for the same reason `mark_plan_kept` takes
  /// it: the database clock is UTC and Kuala Lumpur is +8, so leaving the
  /// server to decide would close tonight's plan eight hours early. Raises when
  /// the plan is not open to the caller, and does not say which of the reasons
  /// it was.
  Future<void> askToJoin(int planId, DateTime today) async {
    await _client.rpc<dynamic>(
      'ask_to_join',
      params: {'p_plan_id': planId, 'p_today': formatPlanDate(today)},
    ).timeout(_timeout);
  }

  /// The owner's answer to one of those. True when a row actually moved —
  /// false means somebody else already answered it, or the asker withdrew.
  Future<bool> answerJoinRequest(
    int planId,
    String userId, {
    required bool accept,
  }) async {
    final answered = await _client.rpc<dynamic>(
      'answer_join_request',
      params: {
        'p_plan_id': planId,
        'p_user_id': userId,
        'p_accept': accept,
      },
    ).timeout(_timeout);

    return answered as bool? ?? false;
  }

  /// The time votes on one plan, with a face against each.
  Future<List<PlanVote>> votes(int planId) async {
    final rows = await _client.rpc<dynamic>(
      'get_plan_votes',
      params: {'p_plan_id': planId},
    ).timeout(_timeout);

    return [
      for (final row in (rows as List<dynamic>? ?? const []))
        PlanVote.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// Casts, or replaces, the caller's own vote.
  Future<void> vote(int planId, {String? time, String? timeLabel}) async {
    await _client.rpc<dynamic>(
      'set_plan_vote',
      params: {
        'p_plan_id': planId,
        'p_plan_time': time,
        'p_time_label': timeLabel,
      },
    ).timeout(_timeout);
  }

  List<FriendProfile> _profiles(dynamic rows) {
    return [
      for (final row in (rows as List<dynamic>? ?? const []))
        FriendProfile.fromJson(row as Map<String, dynamic>),
    ];
  }
}

/// The verbs `friend_request` understands (D131).
enum FriendAction {
  send,
  accept,
  decline,
  remove,
  block;

  String get wire => name;
}
