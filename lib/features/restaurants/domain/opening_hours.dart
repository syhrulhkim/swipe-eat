import 'json_field.dart';

/// A restaurant's daily opening span, and whether it is open at a moment.
///
/// Mirrors the database's `is_open_at` so a card painted from the offline
/// cache says the same thing the server would. One span per day is all the
/// captions carry: an opening time, a closing time, and the weekdays the
/// place is shut. A closing time earlier than the opening time runs past
/// midnight; equal times mean 24 hours.
///
/// Pure Dart, no I/O: times come in as the row's `HH:MM:SS` strings and the
/// "now" is a parameter, so every branch is a one-line test.
class OpeningHours {
  const OpeningHours({
    required this.opensAtMinutes,
    required this.closesAtMinutes,
    this.closedWeekdays = const {},
    this.text,
  });

  /// From the row's columns. Either time missing — or of a type no clock ever
  /// had — means the hours are unknown and every question below answers null.
  factory OpeningHours.fromJson(Map<String, dynamic> json) {
    return OpeningHours(
      opensAtMinutes: parseClockMinutes(jsonString(json['opens_at'])),
      closesAtMinutes: parseClockMinutes(jsonString(json['closes_at'])),
      closedWeekdays: {
        for (final day in jsonList(json['closed_dow']))
          if (day is num) day.toInt(),
      },
      text: jsonString(json['hours_text']),
    );
  }

  static const OpeningHours unknown =
      OpeningHours(opensAtMinutes: null, closesAtMinutes: null);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'opens_at': clockString(opensAtMinutes),
      'closes_at': clockString(closesAtMinutes),
      'closed_dow': closedWeekdays.toList()..sort(),
      'hours_text': text,
    };
  }

  /// Minutes after midnight, local time. Null when the caption gave none.
  final int? opensAtMinutes;
  final int? closesAtMinutes;

  /// ISO weekdays (1 = Monday … 7 = Sunday) the place is closed.
  final Set<int> closedWeekdays;

  /// The line as the caption wrote it, for when the parse is not enough.
  final String? text;

  bool get isKnown => opensAtMinutes != null && closesAtMinutes != null;

  bool get isAllDay => isKnown && opensAtMinutes == closesAtMinutes;

  /// Closes after midnight, e.g. 17:30 → 02:00.
  bool get isOvernight => isKnown && closesAtMinutes! < opensAtMinutes!;

  /// True, false, or null when the hours are unknown — the caller hides the
  /// chip rather than guessing.
  bool? isOpenAt(DateTime now) {
    final opens = opensAtMinutes;
    final closes = closesAtMinutes;
    if (opens == null || closes == null) {
      return null;
    }

    final minute = now.hour * 60 + now.minute;
    final today = now.weekday;
    final yesterday = today == DateTime.monday ? DateTime.sunday : today - 1;
    final openToday = !closedWeekdays.contains(today);

    if (opens == closes) {
      return openToday;
    }
    if (closes > opens) {
      return openToday && minute >= opens && minute < closes;
    }
    // Overnight: before midnight it is today's opening, after midnight it is
    // yesterday's.
    return (minute >= opens && openToday) ||
        (minute < closes && !closedWeekdays.contains(yesterday));
  }

  /// What the card says: "Open till 2 am", "Open 24 h", "Opens 5:30 pm",
  /// "Closed today". Null when the hours are unknown.
  String? statusLabel(DateTime now) {
    final open = isOpenAt(now);
    if (open == null) {
      return null;
    }
    if (isAllDay) {
      return 'Open 24 h';
    }
    if (open) {
      return 'Open till ${formatClock(closesAtMinutes!)}';
    }
    final minute = now.hour * 60 + now.minute;
    final opensLaterToday =
        !closedWeekdays.contains(now.weekday) && minute < opensAtMinutes!;
    if (opensLaterToday) {
      return 'Opens ${formatClock(opensAtMinutes!)}';
    }
    return 'Closed today';
  }

  /// "9:30 pm" style — the short form the design uses in chips and captions.
  static String formatClock(int minutes) {
    final hour24 = (minutes ~/ 60) % 24;
    final minute = minutes % 60;
    final suffix = hour24 < 12 ? 'am' : 'pm';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    if (minute == 0) {
      return '$hour12 $suffix';
    }
    return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
  }

  /// `HH:MM` or `HH:MM:SS` → minutes after midnight. Anything else is null.
  static int? parseClockMinutes(String? value) {
    if (value == null) {
      return null;
    }
    final parts = value.split(':');
    if (parts.length < 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 24 || minute > 59) {
      return null;
    }
    return (hour % 24) * 60 + minute;
  }

  static String? clockString(int? minutes) {
    if (minutes == null) {
      return null;
    }
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }
}
