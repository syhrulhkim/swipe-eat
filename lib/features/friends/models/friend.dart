/// A person, as far as anybody but themselves is allowed to know.
///
/// Three fields, and there is no fourth coming: every cross-user read in the
/// database returns exactly `id, name, avatar_url` (D129), so this class is
/// the shape of that promise in Dart. If a phone number or an email ever turns
/// up here, something has gone wrong a long way upstream.
class FriendProfile {
  const FriendProfile({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory FriendProfile.fromJson(Map<String, dynamic> json) {
    return FriendProfile(
      // `get_friends` names the column `id`; `get_plan_people` and
      // `get_plan_votes` name it `user_id`, because there it sits beside a
      // `plan_id` and "id" would be ambiguous. One factory reads both rather
      // than two classes that hold the same three values.
      id: (json['id'] ?? json['user_id']) as String? ?? '',
      name: json['name'] as String? ?? 'Someone',
      avatarUrl: _nonEmpty(json['avatar_url'] as String?),
    );
  }

  final String id;
  final String name;
  final String? avatarUrl;
}

/// A friendship that has not been answered yet.
class FriendRequest {
  const FriendRequest({required this.profile, required this.incoming});

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      profile: FriendProfile.fromJson(json),
      incoming: json['incoming'] as bool? ?? false,
    );
  }

  final FriendProfile profile;

  /// True when the other person asked. Only an incoming request carries Accept
  /// and Decline; an outgoing one carries nothing but the waiting.
  final bool incoming;
}

/// Somebody on a plan, with the face the id alone could not draw.
///
/// [PlanMember] on the plans side carries the id and the status and is what
/// the calendar loads; this is that row once a name has been found for it.
class PlanPerson {
  const PlanPerson({
    required this.planId,
    required this.profile,
    required this.status,
  });

  factory PlanPerson.fromJson(Map<String, dynamic> json) {
    return PlanPerson(
      planId: (json['plan_id'] as num?)?.toInt() ?? 0,
      profile: FriendProfile.fromJson(json),
      status: json['status'] as String? ?? 'invited',
    );
  }

  final int planId;
  final FriendProfile profile;

  /// `invited`, `going` or `declined`.
  final String status;

  bool get isGoing => status == 'going';
}

/// One person's answer to "when are we going?".
///
/// The same vocabulary as the plan itself (D110): a real clock time, or the
/// `late` label with no time at all.
class PlanVote {
  const PlanVote({
    required this.profile,
    this.hour,
    this.minute,
    this.timeLabel,
  });

  factory PlanVote.fromJson(Map<String, dynamic> json) {
    final parts = (json['plan_time'] as String?)?.split(':');
    return PlanVote(
      profile: FriendProfile.fromJson(json),
      hour: parts == null || parts.isEmpty ? null : int.tryParse(parts[0]),
      minute: parts == null || parts.length < 2 ? null : int.tryParse(parts[1]),
      timeLabel: json['time_label'] as String?,
    );
  }

  final FriendProfile profile;
  final int? hour;
  final int? minute;
  final String? timeLabel;

  /// What the tally groups on. Two people who both chose 20:00 must land in
  /// the same bucket, and "Late" must not collide with a real 00:00.
  String get slotKey => hour == null ? 'label:${timeLabel ?? 'none'}' : 'time:$hour:${minute ?? 0}';
}

String? _nonEmpty(String? value) =>
    value == null || value.isEmpty ? null : value;
