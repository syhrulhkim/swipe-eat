import 'package:swipe_eat/features/friends/data/friends_repository.dart';
import 'package:swipe_eat/features/friends/domain/phone_hash.dart';
import 'package:swipe_eat/features/friends/models/friend.dart';
import 'package:swipe_eat/features/plans/models/plan_slot.dart';

/// `implements`, never `extends` (D69): a signature change on
/// [FriendsRepository] must fail to compile here rather than quietly keep
/// working against an interface that has moved.
class FakeFriendsRepository implements FriendsRepository {
  FakeFriendsRepository({
    List<FriendProfile>? friends,
    List<FriendRequest>? requests,
    List<FriendProfile>? matches,
    List<PlanPerson>? planPeople,
    List<PlanVote>? votes,
    List<FriendProfile>? liked,
  })  : _friends = friends ?? const [],
        _requests = requests ?? const [],
        _matches = matches ?? const [],
        _planPeople = planPeople ?? const [],
        _votes = votes ?? const [],
        _liked = liked ?? const [];

  List<FriendProfile> _friends;
  List<FriendRequest> _requests;
  final List<FriendProfile> _matches;
  final List<PlanPerson> _planPeople;
  List<PlanVote> _votes;
  final List<FriendProfile> _liked;

  /// Every call, recorded, because most of what these tests assert is what was
  /// *not* sent — Skip's whole contract is an empty log.
  final List<String> calls = [];

  /// The raw numbers handed to [matchContacts]. A test that wants to prove a
  /// number never left the device asserts this is empty; a test that wants to
  /// prove hashing happened reads [sentHashes] instead.
  final List<List<String>> matchedNumbers = [];

  /// What would actually have gone over the wire.
  final List<List<String>> sentHashes = [];

  /// Swaps the address book between calls, for a test that retries a failed
  /// load and expects the second one to find something.
  void setFriends(List<FriendProfile> friends) => _friends = friends;

  final List<(String, FriendAction)> actions = [];
  final List<(int, List<String>)> invites = [];
  final List<(int, String?, String?)> castVotes = [];

  /// Set to throw from the next [friends] call.
  Object? failWith;

  /// Set to throw from [votes]. The tally fails silently in the controller, so
  /// a test that wants to prove that needs a way to make it fail.
  Object? failVotesWith;

  /// Set to throw from [requests] only, leaving the friends load intact.
  Object? failRequestsWith;

  /// Set to throw from [matchContacts] — the contacts call fails on its own
  /// often enough (no network at the permission sheet, a capped array) to be
  /// worth failing on its own here.
  Object? failMatchWith;

  /// Set to throw from [act], and so from [sendRequests] too.
  Object? failActWith;

  /// Set to throw from [planPeople].
  Object? failPlanPeopleWith;

  /// Set to throw from [invite].
  Object? failInviteWith;

  /// Set to throw from [whoLiked].
  Object? failWhoLikedWith;

  /// The restaurant ids [whoLiked] was asked about, in order.
  final List<int> likedAsked = [];

  /// The plan ids each [planPeople] call asked for, so a test can prove a
  /// month is fetched once rather than once per card.
  final List<List<int>> planPeopleAsked = [];

  @override
  Future<List<FriendProfile>> friends() async {
    calls.add('friends');
    final failure = failWith;
    if (failure != null) {
      throw failure;
    }
    return _friends;
  }

  @override
  Future<List<FriendRequest>> requests() async {
    calls.add('requests');
    final failure = failRequestsWith;
    if (failure != null) {
      throw failure;
    }
    return _requests;
  }

  @override
  Future<List<FriendProfile>> matchContacts(
    Iterable<String> rawNumbers, {
    String callingCode = kDefaultCallingCode,
  }) async {
    calls.add('matchContacts');
    final failure = failMatchWith;
    if (failure != null) {
      throw failure;
    }
    matchedNumbers.add(rawNumbers.toList());
    // The fake hashes exactly the way the real one does, so a test can assert
    // that what leaves is a hash without reaching into the repository.
    sentHashes.add(hashContacts(rawNumbers, callingCode: callingCode));
    return _matches;
  }

  @override
  Future<void> act(String userId, FriendAction action) async {
    calls.add('act');
    final failure = failActWith;
    if (failure != null) {
      throw failure;
    }
    actions.add((userId, action));

    switch (action) {
      case FriendAction.accept:
        final accepted = _requests
            .where((request) => request.profile.id == userId)
            .map((request) => request.profile)
            .toList();
        _friends = [..._friends, ...accepted];
        _requests = [
          for (final request in _requests)
            if (request.profile.id != userId) request,
        ];
      case FriendAction.decline:
      case FriendAction.remove:
      case FriendAction.block:
        _friends = [
          for (final friend in _friends)
            if (friend.id != userId) friend,
        ];
        _requests = [
          for (final request in _requests)
            if (request.profile.id != userId) request,
        ];
      case FriendAction.send:
        break;
    }
  }

  @override
  Future<int> sendRequests(Iterable<String> userIds) async {
    calls.add('sendRequests');
    var sent = 0;
    for (final id in userIds) {
      await act(id, FriendAction.send);
      sent += 1;
    }
    return sent;
  }

  @override
  Future<List<FriendProfile>> whoLiked(int restaurantId) async {
    calls.add('whoLiked');
    final failure = failWhoLikedWith;
    if (failure != null) {
      throw failure;
    }
    likedAsked.add(restaurantId);
    return _liked;
  }

  @override
  Future<List<PlanPerson>> planPeople(Iterable<int> planIds) async {
    calls.add('planPeople');
    final failure = failPlanPeopleWith;
    if (failure != null) {
      throw failure;
    }
    final ids = planIds.toSet();
    planPeopleAsked.add(ids.toList());
    return [
      for (final person in _planPeople)
        if (ids.contains(person.planId)) person,
    ];
  }

  @override
  Future<int> invite(int planId, Iterable<String> userIds) async {
    calls.add('invite');
    final failure = failInviteWith;
    if (failure != null) {
      throw failure;
    }
    final ids = userIds.toList();
    invites.add((planId, ids));
    return ids.length;
  }

  @override
  Future<void> answerInvite(int planId, {required bool going}) async {
    calls.add('answerInvite');
  }

  @override
  Future<List<PlanVote>> votes(int planId) async {
    calls.add('votes');
    final failure = failVotesWith;
    if (failure != null) {
      throw failure;
    }
    return _votes;
  }

  @override
  Future<void> vote(int planId, {String? time, String? timeLabel}) async {
    calls.add('vote');
    castVotes.add((planId, time, timeLabel));
  }

  /// Lets a test replace the tally between reads, the way a second person
  /// voting would.
  void setVotes(List<PlanVote> votes) => _votes = votes;
}

/// A minimal but real [FriendProfile], so no test hand-assembles a model.
FriendProfile testFriend(String id, {String? name, String? avatarUrl}) {
  return FriendProfile(
    id: id,
    name: name ?? 'Friend $id',
    avatarUrl: avatarUrl,
  );
}

FriendRequest testRequest(String id, {String? name, bool incoming = true}) {
  return FriendRequest(
    profile: testFriend(id, name: name),
    incoming: incoming,
  );
}

PlanPerson testPlanPerson(
  int planId,
  String id, {
  String? name,
  String status = 'invited',
}) {
  return PlanPerson(
    planId: planId,
    profile: testFriend(id, name: name),
    status: status,
  );
}

/// A vote built the way the server sends one, so a test cannot accidentally
/// key a vote differently from the chip it belongs to.
PlanVote testPlanVote(PlanSlot slot, String id, {String? name}) {
  return PlanVote.fromJson({
    'id': id,
    'name': name ?? 'Friend $id',
    'plan_time': slot.wireTime,
    'time_label': slot.wireLabel,
  });
}
