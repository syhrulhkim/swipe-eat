/// Who to put at the top of the invite list.
///
/// Pure and tested on its own, because the alternative is a screen that sorts
/// people in its build method and a bug nobody can reproduce without a
/// calendar.
library;

/// The design's "Ate with recently" — friend ids, most recently eaten with
/// first.
///
/// [plans] is every plan the calendar holds, as a date and the ids on it.
/// [among] is the caller's own friends: a stranger who was on a plan with you
/// is not somebody you can invite, so they are not offered. [now] decides what
/// counts as past — a plan on today or later has not been eaten yet, and
/// "Ate with recently" is past tense or it is nothing.
///
/// The order is by the most recent plan each person appears on, so somebody
/// you ate with last week sits above somebody you ate with in March even if
/// March was three dinners.
///
/// Returns ids rather than profiles: the caller already holds the map, and a
/// function that took profiles would have to decide what to do with an id it
/// could not name.
List<String> recentCompanionIds({
  required Iterable<(DateTime date, Iterable<String> memberIds)> plans,
  required Set<String> among,
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final lastSeen = <String, DateTime>{};

  for (final (date, memberIds) in plans) {
    if (!date.isBefore(today)) {
      continue;
    }
    for (final id in memberIds) {
      if (!among.contains(id)) {
        continue;
      }
      final seen = lastSeen[id];
      if (seen == null || date.isAfter(seen)) {
        lastSeen[id] = date;
      }
    }
  }

  final ids = lastSeen.keys.toList()
    ..sort((a, b) {
      final byDate = lastSeen[b]!.compareTo(lastSeen[a]!);
      // Two people from the same dinner keep a stable order rather than
      // whatever the map happened to hand back, so the list does not shuffle
      // itself between builds.
      return byDate != 0 ? byDate : a.compareTo(b);
    });
  return ids;
}

/// Whether a person's name matches what has been typed into the search field.
///
/// Case-folded and trimmed, matching anywhere in the name rather than only at
/// the start: people search for the half of a name they can spell, and
/// "Zulkifli" should find Aiman.
bool matchesQuery(String name, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }
  return name.toLowerCase().contains(needle);
}
