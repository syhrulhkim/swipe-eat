/// How long ago something was saved, phrased for a staleness marker.
///
/// Deliberately coarse: the point is "this is not live", not the exact age.
String describeAge(DateTime savedAt, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(savedAt);

  if (elapsed.inMinutes < 1) {
    return 'just now';
  }

  if (elapsed.inMinutes < 60) {
    final minutes = elapsed.inMinutes;
    return '$minutes min ago';
  }

  if (elapsed.inHours < 24) {
    final hours = elapsed.inHours;
    return hours == 1 ? '1 hour ago' : '$hours hours ago';
  }

  final days = elapsed.inDays;
  return days == 1 ? 'yesterday' : '$days days ago';
}
