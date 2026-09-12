import '../features/friends/data/friends_repository.dart';
import '../features/friends/models/friend.dart';

/// The prototype's cast, so the Friends screen and the two plan sheets can be
/// looked at without a friend graph behind them.
///
/// Enabled with `--dart-define=USE_DEV_FRIENDS=true`, and deliberately its own
/// flag: restaurants are real data and nothing here invents one. The only
/// restaurant this file touches is whichever id [whoLiked] is asked about —
/// it answers "these three of your friends have been", about a real place.
///
/// Every write is accepted and forgotten. Nothing here reaches Supabase, so a
/// build with this flag on cannot change anybody's real friend graph.
class DevFriendsRepository implements FriendsRepository {
  static const _aiman = FriendProfile(id: 'aiman', name: 'Aiman Zulkifli');
  static const _mei = FriendProfile(id: 'mei', name: 'Mei Kee Tan');
  static const _syafiq = FriendProfile(id: 'syafiq', name: 'Syafiq Rahman');
  static const _danial = FriendProfile(id: 'danial', name: 'Danial Ng');
  static const _priya = FriendProfile(id: 'priya', name: 'Priya Raj');
  static const _jiaWen = FriendProfile(id: 'jiawen', name: 'Jia Wen Lim');

  /// The ids the calendar's own dev plans put on their guest lists, so the two
  /// flags together draw one cast rather than two.
  @override
  Future<List<FriendProfile>> friends() async => const [
        _aiman,
        _mei,
        _syafiq,
        _danial,
        _priya,
      ];

  /// One of each, so both halves of the Requests section are visible: somebody
  /// asking, and somebody already asked.
  @override
  Future<List<FriendRequest>> requests() async => const [
        FriendRequest(profile: _jiaWen, incoming: true),
        FriendRequest(
          profile: FriendProfile(id: 'hana-sister', name: "Hana's sister"),
          incoming: false,
        ),
      ];

  /// The three faces the prototype draws on a restaurant, and the three the
  /// date sheet seeds "Who's coming" from.
  @override
  Future<List<FriendProfile>> whoLiked(int restaurantId) async => const [
        _aiman,
        _mei,
        _syafiq,
      ];

  @override
  Future<List<FriendProfile>> matchContacts(
    Iterable<String> rawNumbers, {
    String callingCode = '60',
  }) async =>
      const [_danial, _priya];

  @override
  Future<List<PlanPerson>> planPeople(Iterable<int> planIds) async => [
        for (final id in planIds) ...[
          PlanPerson(planId: id, profile: _aiman, status: 'going'),
          PlanPerson(planId: id, profile: _mei, status: 'going'),
          PlanPerson(planId: id, profile: _syafiq, status: 'invited'),
        ],
      ];

  @override
  Future<List<PlanVote>> votes(int planId) async => const [
        PlanVote(profile: _aiman, hour: 20, minute: 0),
        PlanVote(profile: _mei, hour: 21, minute: 30),
      ];

  // Writes: accepted, and dropped on the floor. A dev build is for looking at
  // screens, so none of these needs to be remembered between two openings.

  @override
  Future<void> act(String userId, FriendAction action) async {}

  @override
  Future<int> sendRequests(Iterable<String> userIds) async => userIds.length;

  @override
  Future<int> invite(int planId, Iterable<String> userIds) async =>
      userIds.length;

  @override
  Future<void> answerInvite(int planId, {required bool going}) async {}

  @override
  Future<void> askToJoin(int planId, DateTime today) async {}

  @override
  Future<bool> answerJoinRequest(
    int planId,
    String userId, {
    required bool accept,
  }) async =>
      accept;

  @override
  Future<void> vote(int planId, {String? time, String? timeLabel}) async {}
}
