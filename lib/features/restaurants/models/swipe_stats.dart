/// One row from `get_swipe_stats`: how many swipes the user has spent today,
/// and how many consecutive days they have swiped at least once.
class SwipeStats {
  const SwipeStats({required this.swipesToday, required this.streakDays});

  final int swipesToday;
  final int streakDays;

  factory SwipeStats.fromJson(Map<String, dynamic> json) {
    return SwipeStats(
      swipesToday: (json['swipes_today'] as num?)?.toInt() ?? 0,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
    );
  }
}
