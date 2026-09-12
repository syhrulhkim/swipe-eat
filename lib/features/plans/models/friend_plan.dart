import '../../friends/models/friend.dart';
import 'plan_slot.dart';
import 'plan.dart';

/// A friend's evening, as `get_friends_plans` hands it over.
///
/// Not a [Plan]: this is somebody else's row read through a definer RPC, so it
/// carries an owner and an `asked` flag and none of the things only an owner
/// may know — no status, no guest ids, no `with_friends`. The names in
/// [goingFriends] are people who are **your** friends too; strangers on the
/// plan are counted in [goingCount] and never named (D153).
class FriendPlan {
  const FriendPlan({
    required this.id,
    required this.owner,
    required this.restaurantId,
    required this.restaurantName,
    required this.date,
    this.hour,
    this.minute,
    this.timeLabel,
    this.coverUrl,
    this.goingCount = 0,
    this.goingFriends = const [],
    this.asked = false,
  });

  factory FriendPlan.fromJson(Map<String, dynamic> json) {
    final time = parsePlanTime(json['plan_time'] as String?);

    return FriendPlan(
      id: (json['plan_id'] as num).toInt(),
      owner: FriendProfile.fromJson(<String, dynamic>{
        'id': json['owner_id'],
        'name': json['owner_name'],
        'avatar_url': json['owner_avatar_url'],
      }),
      restaurantId: (json['restaurant_id'] as num?)?.toInt() ?? 0,
      restaurantName: json['restaurant_name'] as String? ?? 'A place',
      date: parsePlanDate(json['plan_date'] as String?),
      hour: time?.$1,
      minute: time?.$2,
      timeLabel: json['time_label'] as String?,
      coverUrl: json['cover_url'] as String?,
      goingCount: (json['going_count'] as num?)?.toInt() ?? 0,
      goingFriends: [
        for (final row in (json['going_friends'] as List<dynamic>? ?? const []))
          FriendProfile.fromJson(row as Map<String, dynamic>),
      ],
      asked: json['asked'] as bool? ?? false,
    );
  }

  final int id;
  final FriendProfile owner;
  final int restaurantId;
  final String restaurantName;
  final DateTime date;
  final int? hour;
  final int? minute;
  final String? timeLabel;
  final String? coverUrl;

  /// Everybody going, strangers included.
  final int goingCount;

  /// The ones you know, capped by the server at six.
  final List<FriendProfile> goingFriends;

  /// Whether you have already asked to join. The button reads "Asked" and
  /// stops taking taps once this is true — there is no un-asking in v1.
  final bool asked;

  /// "20:00", or "Late" — the same vocabulary a plan of your own uses.
  String get timeText =>
      planTimeText(hour: hour, minute: minute, timeLabel: timeLabel);

  int get sortMinutes => hour == null ? 24 * 60 : hour! * 60 + (minute ?? 0);
}
