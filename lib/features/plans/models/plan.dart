import 'plan_slot.dart';

/// Where a plan is in its life. Past plans are flipped to [kept] server-side
/// unless they were cancelled first (D108) — there is no "did you go?" prompt,
/// because the calendar records intent and intent that survived to the day
/// counts.
enum PlanStatus {
  planned,
  kept,
  cancelled;

  static PlanStatus fromWire(String? value) {
    return switch (value) {
      'kept' => PlanStatus.kept,
      'cancelled' => PlanStatus.cancelled,
      _ => PlanStatus.planned,
    };
  }

  String get wire => name;
}

/// Somebody else on the plan.
///
/// Ids and statuses only. `profiles` is not selectable for anyone but its
/// owner, so a join for names would come back empty rather than come back
/// wrong; the Friends phase adds the read that can see them. Carrying the ids
/// now means the avatar stack has something real to count when it arrives.
class PlanMember {
  const PlanMember({required this.userId, required this.status});

  factory PlanMember.fromJson(Map<String, dynamic> json) {
    return PlanMember(
      userId: json['user_id'] as String? ?? '',
      status: json['status'] as String? ?? 'invited',
    );
  }

  final String userId;

  /// `invited`, `going` or `declined`.
  final String status;

  bool get isGoing => status == 'going';
}

/// One row of `plans`, with everything a calendar row draws joined onto it.
class Plan {
  const Plan({
    required this.id,
    required this.restaurantId,
    required this.date,
    required this.restaurantName,
    this.hour,
    this.minute,
    this.timeLabel,
    this.withFriends = false,
    this.sharedWithFriends = false,
    this.status = PlanStatus.planned,
    this.coverUrl,
    this.tag,
    this.neighbourhood,
    this.latitude,
    this.longitude,
    this.members = const [],
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    final restaurant = json['restaurants'] as Map<String, dynamic>?;

    final images = List<Map<String, dynamic>>.from(
      (restaurant?['restaurant_images'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>(),
    )..sort(
        (a, b) => ((a['position'] as num?) ?? 0)
            .compareTo((b['position'] as num?) ?? 0),
      );

    final cover = images
        .map((image) => image['url'] as String? ?? '')
        .where((url) => url.isNotEmpty)
        .firstOrNull;

    final time = parsePlanTime(json['plan_time'] as String?);

    return Plan(
      id: (json['id'] as num).toInt(),
      restaurantId: (json['restaurant_id'] as num).toInt(),
      date: parsePlanDate(json['plan_date'] as String?),
      hour: time?.$1,
      minute: time?.$2,
      timeLabel: json['time_label'] as String?,
      withFriends: json['with_friends'] as bool? ?? false,
      sharedWithFriends: json['shared_with_friends'] as bool? ?? false,
      status: PlanStatus.fromWire(json['status'] as String?),
      restaurantName: restaurant?['name'] as String? ?? 'A place',
      coverUrl: cover,
      tag: restaurant?['tag'] as String?,
      neighbourhood: restaurant?['neighbourhood'] as String?,
      latitude: (restaurant?['latitude'] as num?)?.toDouble(),
      longitude: (restaurant?['longitude'] as num?)?.toDouble(),
      members: (json['plan_members'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(PlanMember.fromJson)
          .toList(),
    );
  }

  final int id;
  final int restaurantId;

  /// Midnight local on the day of the plan. Date-only on the wire, so nothing
  /// here carries a time zone that could move it a day.
  final DateTime date;

  final int? hour;
  final int? minute;

  /// `late`, or null for a real clock time.
  final String? timeLabel;

  final bool withFriends;

  /// Whether friends can see this evening on their own calendar (D153). Per
  /// plan and off unless the owner said otherwise — the switch is on the
  /// pick-a-date screen and on the plan itself.
  final bool sharedWithFriends;

  final PlanStatus status;

  final String restaurantName;
  final String? coverUrl;
  final String? tag;
  final String? neighbourhood;
  final double? latitude;
  final double? longitude;
  final List<PlanMember> members;

  /// "20:00", or "Late".
  String get timeText =>
      planTimeText(hour: hour, minute: minute, timeLabel: timeLabel);

  /// Two letters for the logo when there is no cover photo. Two words give
  /// their initials ("Kak Ros" → "KR"); one word gives its first two letters.
  String get initials {
    final words = restaurantName
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return '??';
    }
    if (words.length == 1) {
      final word = words.first;
      return (word.length == 1 ? word : word.substring(0, 2)).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  /// Sorts a day's plans the way the design lists them: by the clock, with
  /// "Late" last because it is later than any hour that has a number.
  int get sortMinutes => hour == null ? 24 * 60 : hour! * 60 + (minute ?? 0);
}

/// `2026-09-04` → local midnight on that day. A malformed or missing value
/// becomes the epoch rather than throwing: a row the calendar cannot place is
/// better than a screen that will not open.
DateTime parsePlanDate(String? value) {
  if (value == null) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  final parts = value.split('-');
  if (parts.length < 3) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime(
    int.tryParse(parts[0]) ?? 1970,
    int.tryParse(parts[1]) ?? 1,
    int.tryParse(parts[2].split('T').first) ?? 1,
  );
}

/// The wire form `plans.plan_date` wants. Built from the local date's parts so
/// a phone east of UTC cannot post yesterday.
String formatPlanDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// `20:30:00` → `(20, 30)`, and null for a plan that only has a label. Public
/// because a friend's plan arrives on a different RPC and parses the same
/// column the same way.
(int, int)? parsePlanTime(String? value) {
  if (value == null) {
    return null;
  }
  final parts = value.split(':');
  if (parts.length < 2) {
    return null;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }
  return (hour, minute);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
