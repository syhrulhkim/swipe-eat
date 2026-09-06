/// The five times a plan can be set for (D110).
///
/// The design offers a fixed row of chips, not a time picker, and this is the
/// whole vocabulary: four clock readings and one word. "Late" is a *label*
/// rather than a time because "whenever we're done" has no hour — which is why
/// [hour] is nullable here and `plans.plan_time` is nullable in the database.
///
/// Fixed rather than free because a plan's time is a thing to agree on with
/// other people, and four options are agreed on faster than 1 440.
class PlanSlot {
  const PlanSlot._({required this.label, this.hour, this.minute, this.wireLabel});

  /// What the chip says, and what the summary line reads back.
  final String label;

  final int? hour;
  final int? minute;

  /// The value written to `plans.time_label`; null for a real clock time.
  final String? wireLabel;

  static const noon = PlanSlot._(label: '12:30', hour: 12, minute: 30);
  static const early = PlanSlot._(label: '18:30', hour: 18, minute: 30);
  static const dinner = PlanSlot._(label: '20:00', hour: 20, minute: 0);
  static const late = PlanSlot._(label: '21:30', hour: 21, minute: 30);
  static const supper = PlanSlot._(label: 'Late', wireLabel: 'late');

  /// In the order the design's chip row draws them.
  static const List<PlanSlot> all = [noon, early, dinner, late, supper];

  /// The chip that starts pressed. The prototype ships with 20:00 chosen, and
  /// a screen where nothing is chosen would make the user pick twice to get
  /// the answer most of them wanted.
  static const PlanSlot initial = dinner;

  /// `plans.plan_time`'s wire form ("20:00:00"), or null for "Late".
  String? get wireTime {
    final h = hour;
    if (h == null) {
      return null;
    }
    return '${_two(h)}:${_two(minute ?? 0)}:00';
  }

  /// The slot a stored plan came from, matched on the hour and minute. An hour
  /// that is not one of the five (a plan written by a future screen, or by
  /// hand) has no chip, so this returns null rather than guessing at one.
  static PlanSlot? forStored({int? hour, int? minute, String? timeLabel}) {
    if (timeLabel == 'late') {
      return supper;
    }
    if (hour == null) {
      return null;
    }
    for (final slot in all) {
      if (slot.hour == hour && (slot.minute ?? 0) == (minute ?? 0)) {
        return slot;
      }
    }
    return null;
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

/// "20:00" for a clock time, "Late" for the wordy one — the `.time` pill and
/// the `.picked` summary both read this.
String planTimeText({int? hour, int? minute, String? timeLabel}) {
  if (hour == null) {
    return timeLabel == 'late' ? 'Late' : 'Any time';
  }
  return '${_two(hour)}:${_two(minute ?? 0)}';
}
