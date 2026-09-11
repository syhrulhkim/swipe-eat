import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/design_tokens.dart';
import '../domain/plan_labels.dart';

/// What a day already has on it: the cover of the plan the ring shows, and a
/// pip for every person involved.
///
/// Ember pips are plans created by the current user; cream pips are friends
/// invited to those plans. The prototype draws them in two colours so a day
/// reads at a glance as "mine", "theirs" or "both".
class PlanDayMark {
  const PlanDayMark({
    this.coverUrl,
    this.planCount = 1,
    this.friendCount = 0,
    this.initials = '',
  });

  final String? coverUrl;

  /// How many plans fall on the day. One ember pip each, capped at three — past
  /// that the pips stop being countable and the row below the grid is the honest
  /// place to read the list.
  final int planCount;

  /// How many friends are involved in plans on this day. One cream pip each,
  /// sharing the same three-pip cap.
  final int friendCount;

  /// Drawn inside the ring when there is no cover photo, so a planned day
  /// still says *which* place rather than showing an empty hole.
  final String initials;
}

/// The month grid both plan screens draw — S4's picker and S6's overview.
///
/// One widget rather than two because they are the same grid with different
/// things switched on: the picker takes taps and refuses the past, the
/// overview takes none and shows every day the user has booked.
///
/// The week starts on Monday, which is the design's week and also Dart's
/// (`DateTime.monday == 1`), so the column a date lands in needs no arithmetic
/// beyond `weekday - 1`.
class PlanCalendar extends StatelessWidget {
  const PlanCalendar({
    super.key,
    required this.month,
    required this.today,
    this.selectedDay,
    this.onSelectDay,
    this.marks = const {},
    this.disablePast = false,
    this.semanticsLabel,
  });

  /// Any date inside the month to draw; only its year and month are read.
  final DateTime month;

  /// The day that gets the cream disc. Passed in rather than read off the
  /// clock so a test can say what "today" is.
  final DateTime today;

  final DateTime? selectedDay;

  /// Null makes every cell unselectable — the Calendar tab's grid is a
  /// picture, not a control.
  final ValueChanged<DateTime>? onSelectDay;

  /// Keyed by day of the month.
  final Map<int, PlanDayMark> marks;

  /// Whether days before [today] refuse the tap. The picker sets it; you
  /// cannot make a plan for last Tuesday.
  final bool disablePast;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final first = firstOfMonth(month);
    final total = daysInMonth(first);
    // Monday-first: how many blanks before the 1st.
    final leading = first.weekday - 1;
    final cells = leading + total;
    final rows = (cells / 7).ceil();

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WeekdayHeader(today: today, month: first),
          for (var row = 0; row < rows; row++) ...[
            if (row > 0) const SizedBox(height: kCalendarRowGap),
            Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kCalendarColumnGap / 2,
                      ),
                      child: _cellFor(first, row * 7 + column - leading, total),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cellFor(DateTime first, int dayIndex, int total) {
    final day = dayIndex + 1;
    if (day < 1 || day > total) {
      // The design's `.day.blank`: it holds its column open so the weeks stay
      // in line, and says nothing.
      return const SizedBox(height: _cellHeight);
    }

    final date = DateTime(first.year, first.month, day);
    final isToday = isSameDay(date, today);
    final isPast = date.isBefore(DateTime(today.year, today.month, today.day));
    final selected = selectedDay != null && isSameDay(date, selectedDay!);
    final mark = marks[day];
    final onSelect = onSelectDay;
    final enabled = onSelect != null && !(disablePast && isPast);

    return _DayCell(
      date: date,
      isToday: isToday,
      isPast: isPast,
      selected: selected,
      mark: mark,
      onTap: enabled ? () => onSelect(date) : null,
    );
  }
}

/// 36 px of disc, 5 px of gap, 4 px of dot. Two more than that so a cell can
/// never clip its own mark.
const double _cellHeight =
    kCalendarDaySize + kCalendarRowGap + kCalendarDotSize + 3;

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.today, required this.month});

  final DateTime today;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    // Only the column today falls in is lit, and only while today is actually
    // in the month on screen — a lit column in November would be pointing at
    // nothing.
    final highlight = isSameMonth(month, today) ? today.weekday - 1 : -1;

    return Padding(
      padding: const EdgeInsets.only(bottom: kCalendarRowGap),
      child: Row(
        children: [
          for (var column = 0; column < 7; column++)
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  weekdayInitials[column],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kFontSizeMicro,
                    fontWeight: FontWeight.w600,
                    color: column == highlight ? kAccentCream : kCreamSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isToday,
    required this.isPast,
    required this.selected,
    required this.mark,
    required this.onTap,
  });

  final DateTime date;
  final bool isToday;
  final bool isPast;
  final bool selected;
  final PlanDayMark? mark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final planned = mark != null;

    // Orange means chosen or actionable, in that order: a selected day wins
    // over today's cream disc, and today's disc wins over a plan's ring —
    // exactly the order the prototype's classes resolve in.
    final Color fill;
    final Color border;
    final Color text;
    if (selected) {
      fill = kAccentEmber;
      border = kAccentEmber;
      text = kOnAccent;
    } else if (isToday) {
      fill = kAccentCream;
      border = kAccentCream;
      text = kOnAccent;
    } else if (planned) {
      fill = kSurfaceDark;
      border = kAccentEmber;
      text = kTextOnPhoto;
    } else if (isPast) {
      fill = Colors.transparent;
      border = kHairline;
      text = kCreamMuted;
    } else {
      fill = Colors.transparent;
      border = kHairline;
      text = kTextOnPhoto;
    }

    final showCover = planned && !isToday && !selected;

    final Widget disc = Container(
      width: kCalendarDaySize,
      height: kCalendarDaySize,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.5),
      ),
      alignment: Alignment.center,
      child: showCover
          ? _PlannedThumb(mark: mark!)
          : FittedBox(
              // A day number is two digits in a circle that cannot grow. At a
              // large text scale it shrinks to fit rather than spilling over
              // the ring; the full date is on the semantics node either way,
              // so nothing is lost to a screen reader.
              fit: BoxFit.scaleDown,
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontFamily: kTextFontFamily,
                  fontSize: kFontSizeSmall,
                  fontWeight: FontWeight.w600,
                  color: text,
                  height: 1.1,
                ),
              ),
            ),
    );

    final mePips = mark?.planCount ?? 0;
    final friendPips = mark?.friendCount ?? 0;
    final totalPips = mePips + friendPips;

    Widget cell = SizedBox(
      height: _cellHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          disc,
          const SizedBox(height: kCalendarRowGap),
          SizedBox(
            height: kCalendarDotSize,
            child: totalPips > 0
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0;
                          i < (totalPips > 3 ? 3 : totalPips);
                          i++) ...[
                        if (i > 0) const SizedBox(width: 2),
                        _Dot(color: i < mePips ? kAccentEmber : kCreamMuted),
                      ],
                    ],
                  )
                : (isToday && !selected
                    ? const _Dot(color: kAccentEmber)
                    : null),
          ),
        ],
      ),
    );

    if (onTap != null) {
      // The whole 48 pt cell is the target, not the 36 pt disc inside it: a
      // finger landing in the gutter between two days used to do nothing.
      cell = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(kRadiusPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadiusPill),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap!();
          },
          child: cell,
        ),
      );
    }

    return Semantics(
      label: _label(),
      button: onTap != null,
      selected: selected,
      enabled: onTap != null,
      // The number inside would otherwise announce itself as a second node
      // called "4"; excluding it drops the InkWell's action too, so the tap is
      // re-declared here (D83).
      excludeSemantics: true,
      onTap: onTap,
      child: cell,
    );
  }

  String _label() {
    final parts = <String>[
      '${weekdayShort(date)} ${date.day} ${shortMonth(date)}',
      if (isToday) 'today',
      if (mark != null) planCount(mark!.planCount),
      if (onTap == null && isPast) 'past',
    ];
    return parts.join(', ');
  }
}

class _PlannedThumb extends StatelessWidget {
  const _PlannedThumb({required this.mark});

  final PlanDayMark mark;

  @override
  Widget build(BuildContext context) {
    final cover = mark.coverUrl;

    return Padding(
      padding: const EdgeInsets.all(kCalendarRingInset),
      child: Container(
        decoration: BoxDecoration(
          color: kSurfacePanel,
          shape: BoxShape.circle,
          border: Border.all(color: kAccentEmber, width: kCalendarRingWidth),
          image: cover == null || cover.isEmpty
              ? null
              : DecorationImage(
                  image: ResizeImage(
                    NetworkImage(cover),
                    width: cachePx(context, kCalendarDaySize),
                  ),
                  fit: BoxFit.cover,
                ),
        ),
        alignment: Alignment.center,
        child: cover == null || cover.isEmpty
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  mark.initials,
                  style: const TextStyle(
                    fontFamily: kDisplayFontFamily,
                    fontSize: kFontSizeMicro,
                    fontWeight: FontWeight.w700,
                    color: kTextOnPhoto,
                    height: 1.1,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kCalendarDotSize,
      height: kCalendarDotSize,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// The `.cal-head` row: the month's name, and whatever steps or qualifies it.
class PlanCalendarHeader extends StatelessWidget {
  const PlanCalendarHeader({
    super.key,
    required this.month,
    this.onPrevious,
    this.onNext,
    this.trailing,
  });

  final DateTime month;

  /// Null leaves the arrow out altogether rather than drawing it dead. The
  /// picker passes null on the current month — there is no plan to be made in
  /// a week that has already happened, and an arrow that is always there but
  /// only sometimes works is a worse answer than one that is not there.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Replaces the arrows entirely — the Calendar tab puts its "This month ▾"
  /// chip here instead.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(
            child: Text(
              monthTitle(month),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: kTextFontFamily,
                fontSize: kFontSizeBody,
                fontWeight: FontWeight.w600,
                color: kTextOnPhoto,
              ),
            ),
          ),
          if (trailing != null)
            // A chip fills whatever width it is handed, so it is given its own
            // natural width up to half the row: flush right and unstretched at
            // any ordinary size, and at a doubled text scale it gives ground to
            // the month rather than pushing it off the screen.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
              child: IntrinsicWidth(child: trailing!),
            )
          else ...[
            if (onPrevious != null) ...[
              _MonthArrow(
                icon: Icons.chevron_left_rounded,
                semanticLabel: 'Previous month',
                onTap: onPrevious,
              ),
              const SizedBox(width: 8),
            ],
            _MonthArrow(
              icon: Icons.chevron_right_rounded,
              semanticLabel: 'Next month',
              onTap: onNext,
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Semantics(
      // Its own node, not an annotation on whatever encloses it: in a list
      // item the whole row collapses into one node, and the arrow's label
      // merged into the month's — a screen reader met one button called
      // "September 2026 Next month".
      container: true,
      label: semanticLabel,
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox(
        // Drawn 32 px, tapped at 44 — the arrow keeps the design's size and
        // the finger still gets its target.
        width: kMinTapTarget,
        height: kMinTapTarget,
        child: Center(
          child: Material(
            color: kGlass,
            shape: const CircleBorder(side: BorderSide(color: kHairline)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      onTap!();
                    }
                  : null,
              child: SizedBox(
                width: kCalendarArrowSize,
                height: kCalendarArrowSize,
                child: Icon(
                  icon,
                  size: 18,
                  color: enabled ? kTextOnPhoto : kCreamMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
