import '../../restaurants/domain/meal_label.dart';
import '../models/plan.dart';

const List<String> _weekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The two-letter column headings, Monday first — the design's week starts on
/// Monday, not Sunday.
const List<String> weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// "September 2026" — the `.cal-head` month.
String monthTitle(DateTime month) =>
    '${_monthNames[month.month - 1]} ${month.year}';

/// "Sep" — the short form the month sheet lists.
String shortMonth(DateTime month) => _months[month.month - 1];

/// "Fri" for a date. Dart numbers Monday 1 … Sunday 7, which is already the
/// design's week order, so the lookup needs no rotation.
String weekdayShort(DateTime date) => _weekdays[date.weekday - 1];

/// Whether two dates fall on the same day, ignoring any time either carries.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Whether two dates fall in the same month of the same year.
bool isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

/// Midnight on the first of [date]'s month.
DateTime firstOfMonth(DateTime date) => DateTime(date.year, date.month);

/// [months] months on from [month], rolling the year over as needed.
DateTime addMonths(DateTime month, int months) =>
    DateTime(month.year, month.month + months);

/// How many days [month] has. Day zero of the next month is the last day of
/// this one, which is the trick that makes February behave.
int daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

/// The badge a bitten place carries once it has a day: "Today", "Tonight",
/// "Fri 4", or "Sat 12 Sep" once the day is outside the current month.
///
/// "Tonight" rather than "Today" from 18:00 on, because a plan for dinner
/// tonight is a different piece of news from lunch you have already had — and
/// it is the design's own word for it.
String plannedLabel(Plan plan, DateTime now) {
  if (isSameDay(plan.date, now)) {
    final hour = plan.hour;
    if (hour == null ? plan.timeLabel == 'late' : hour >= 18) {
      return 'Tonight';
    }
    return 'Today';
  }

  if (isSameMonth(plan.date, now)) {
    return '${weekdayShort(plan.date)} ${plan.date.day}';
  }

  return '${weekdayShort(plan.date)} ${plan.date.day} '
      '${shortMonth(plan.date)}';
}

/// The heading over a day's plans on the Calendar tab: "Today", "Tomorrow",
/// or "Fri 4".
String daySectionTitle(DateTime date, DateTime now) {
  if (isSameDay(date, now)) {
    return 'Today';
  }
  if (isSameDay(date, now.add(const Duration(days: 1)))) {
    return 'Tomorrow';
  }
  if (isSameMonth(date, now)) {
    return '${weekdayShort(date)} ${date.day}';
  }
  return '${weekdayShort(date)} ${date.day} ${shortMonth(date)}';
}

/// "Fri 4 Sep · 20:00" — the `.picked` summary's first line.
String pickedSummary(DateTime date, String timeText) {
  return '${weekdayShort(date)} ${date.day} ${shortMonth(date)} · $timeText';
}

/// "2 plans" / "1 plan".
String planCount(int count) => count == 1 ? '1 plan' : '$count plans';

/// Which meal a plan's time reads as — "Lunch", "Dinner", "Supper".
///
/// Delegates to the deck's own [mealLabel] so the two surfaces cannot end up
/// disagreeing about when dinner starts; only the capital is added here,
/// because the deck says "within 3 km · dinner" mid-sentence and this is the
/// start of one. "Late" has no hour, so it lands on supper, which is the whole
/// point of the word.
String planMealLabel(Plan plan) {
  final hour = plan.hour ?? 23;
  final label = mealLabel(DateTime(2026, 1, 1, hour, plan.minute ?? 0));
  return label[0].toUpperCase() + label.substring(1);
}
