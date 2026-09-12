import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/distance_label.dart';
import '../../../core/location/open_directions.dart';
import '../../../core/location/user_position_state.dart';
import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../friends/domain/friend_captions.dart';
import '../../friends/models/friend.dart';
import '../../friends/presentation/friend_avatar.dart';
import '../../friends/presentation/invite_page.dart';
import '../../friends/state/friends_controller.dart';
import '../../profile/presentation/preference_controls.dart';
import '../../restaurants/domain/opening_hours.dart';
import '../domain/plan_labels.dart';
import '../models/plan_slot.dart';
import '../state/plans_controller.dart';
import 'plan_calendar.dart';

/// What `/plans/new` is opened with. The detail screen pushes the restaurant
/// it is showing rather than an id alone, so the page can draw its title and
/// its thumbnail without a fetch.
///
/// Parsed defensively for the same reason `/restaurant/:id` is: a link, a
/// restored route or a future caller may hand over less than the tap did, and
/// a screen that throws on a thin payload is worse than one that shows a
/// placeholder.
class PlanDraft {
  const PlanDraft({
    required this.restaurantId,
    required this.title,
    this.coverUrl,
    this.neighbourhood,
    this.tag,
    this.latitude = 0,
    this.longitude = 0,
    this.hours = OpeningHours.unknown,
  });

  static PlanDraft? fromPayload(Object? payload) {
    if (payload is! Map) {
      return null;
    }
    final id = payload['restaurantId'];
    final restaurantId = id is num ? id.toInt() : int.tryParse('$id');
    if (restaurantId == null) {
      return null;
    }
    final hours = payload['hours'];

    return PlanDraft(
      restaurantId: restaurantId,
      title: payload['title'] as String? ?? 'A place',
      coverUrl: payload['coverUrl'] as String?,
      neighbourhood: payload['neighbourhood'] as String?,
      tag: payload['tag'] as String?,
      latitude: (payload['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (payload['longitude'] as num?)?.toDouble() ?? 0,
      hours: hours is Map
          ? OpeningHours.fromJson(Map<String, dynamic>.from(hours))
          : OpeningHours.unknown,
    );
  }

  final int restaurantId;
  final String title;
  final String? coverUrl;
  final String? neighbourhood;
  final String? tag;
  final double latitude;
  final double longitude;
  final OpeningHours hours;

  /// The short name the summary line uses — "Warung Kak Ros" is the topbar's
  /// job, and the bar under it has a friends count to fit as well.
  String get shortName {
    final words = title.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.length > 2 ? words.skip(1).take(2).join(' ') : title;
  }

  /// "1.2 km from you", or null when there is no fix or no coordinates. The
  /// deck's wording without its verb, the way the detail screen's meta line
  /// does it — a number we cannot compute is a segment we drop, never a guess.
  String? distanceFrom(Position? position) {
    if (position == null || !hasMapFix(latitude, longitude)) {
      return null;
    }
    final label = distanceLabelFrom(
      position,
      latitude: latitude,
      longitude: longitude,
    );
    final trimmed = label.endsWith(' away')
        ? label.substring(0, label.length - ' away'.length)
        : label;
    return '$trimmed from you';
  }
}

/// The four chips the plan sheet offers, in the design's order.
///
/// A subset of [PlanSlot.all] rather than a new vocabulary: the five slots are
/// positionally wired into the vote tally and the plan page, so the sheet
/// picks from them instead of inventing a sixth. 12:30 is lunch and the sheet
/// is about an evening; the plan page still offers it to vote on.
const List<PlanSlot> kPlanSheetSlots = [
  PlanSlot.early,
  PlanSlot.dinner,
  PlanSlot.late,
  PlanSlot.supper,
];

/// "8:00" for a slot, "Late" for the wordy one — the design writes its times
/// on a twelve-hour clock while the database keeps them on a twenty-four hour
/// one, and only this half of the app reads them aloud.
String slotClockLabel(PlanSlot slot) {
  final hour = slot.hour;
  if (hour == null) {
    return slot.label;
  }
  final twelve = hour % 12 == 0 ? 12 : hour % 12;
  return '$twelve:${(slot.minute ?? 0).toString().padLeft(2, '0')}';
}

/// The time as the summary line reads it: "8:00 pm", or the bare word "late".
String planSummaryTime(PlanSlot slot) =>
    slot.hour == null ? 'late' : '${slotClockLabel(slot)} pm';

/// "Fri 18 · 8:00 pm" — the invite sheet's peek header, and what a plan is
/// called in one breath.
String planPeekWhen(DateTime date, PlanSlot slot) =>
    '${weekdayShort(date)} ${date.day} · ${planSummaryTime(slot)}';

/// "Sat 12 · 8:00 pm · 3 friends" — the `.summary` line.
String planSummaryLine(DateTime date, PlanSlot slot, int friends) {
  final tail = friends <= 0
      ? 'just you'
      : '$friends ${friends == 1 ? 'friend' : 'friends'}';
  return '${weekdayShort(date)} ${date.day} · ${planSummaryTime(slot)} · $tail';
}

/// S4 · When are we going? Step one of two.
///
/// Nothing is saved here. The sheet gathers a day, a time and a guest list and
/// hands all three to step two, which is where "Lock it in" lives — a plan
/// made before its guests were picked was a plan the user had to back out of
/// to change their mind about who was coming.
class PlanDatePage extends StatefulWidget {
  const PlanDatePage({
    super.key,
    required this.draft,
    this.controller,
    this.friends,
  });

  final PlanDraft draft;

  /// Injected by tests; in the app the shared instances are used.
  final PlansController? controller;
  final FriendsController? friends;

  @override
  State<PlanDatePage> createState() => _PlanDatePageState();
}

class _PlanDatePageState extends State<PlanDatePage>
    with UserPositionState<PlanDatePage> {
  late final PlansController _plans =
      widget.controller ?? PlansController.instance;
  late final FriendsController _friends =
      widget.friends ?? FriendsController.instance;

  /// Read once, in `initState`: a page that asked the clock on every build
  /// would redraw "today" mid-session, and every test would race it.
  late final DateTime _today = _startOfDay(_plans.now);

  /// The seven cells of the week strip, starting today.
  late final List<DateTime> _week = [
    for (var i = 0; i < 7; i++) _today.add(Duration(days: i)),
  ];

  /// Starts on the last day of the strip, with "This week" pressed — the
  /// prototype's own default. Never null: the design draws no waiting state
  /// for the primary button, so there is always an answer to carry forward.
  late DateTime _selected = _week.last;

  PlanSlot _slot = PlanSlot.dinner;
  bool _vote = true;

  /// Off unless the user says otherwise (D153). Where you are eating and who
  /// with is the most private thing this app holds, so the switch that lets
  /// other people see it cannot start switched on.
  bool _shared = false;

  /// Who the `+` has collected. Seeded from the friends who already liked this
  /// place, which is the design's own "Aiman, Mei Kee +1".
  Set<String> _invited = {};
  bool _seeded = false;

  /// "Just me" — the guest list is kept, so turning it back on restores it
  /// rather than making the user pick everybody again.
  bool _justMe = false;

  @override
  void initState() {
    super.initState();
    loadUserPosition();
    _friends.ensureLoaded();
    _plans.ensureLoaded();
    // Usually already answered: the detail screen this was pushed from asks
    // the same question for its `.friends` row.
    unawaited(_friends.loadWhoLiked(widget.draft.restaurantId));
  }

  List<FriendProfile> get _liked =>
      _friends.whoLiked(widget.draft.restaurantId);

  List<FriendProfile> get _coming {
    if (_justMe) {
      return const [];
    }
    final byId = {
      for (final person in _liked) person.id: person,
      for (final person in _friends.friends) person.id: person,
    };
    return [
      for (final id in _invited)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      body: Stack(
        children: [
          const ScreenGlow(),
          SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge([_friends, _plans]),
              builder: (context, _) => _sheet(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheet(BuildContext context) {
    // Seeded once the answer is in, and only once: re-seeding on every build
    // would undo a user who had just taken somebody off the list.
    if (!_seeded && _liked.isNotEmpty) {
      _seeded = true;
      _invited = {for (final person in _liked) person.id};
    }

    final coming = _coming;
    final closing = widget.draft.hours.closesAtMinutes;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        12,
        AppSpacing.screenPadding,
        22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PeekHeader(
            title: widget.draft.title,
            subtitle: _peekSubtitle(),
            icon: Icons.close_rounded,
            semanticLabel: 'Close',
            onTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  const SheetHeading(
                    title: 'When are we going?',
                    step: 'Step 1 of 2',
                  ),
                  const SizedBox(height: 14),
                  _QuickRow(
                    pressed: _quickPressed,
                    onPick: _pickQuick,
                  ),
                  const SizedBox(height: 10),
                  _WeekStrip(
                    week: _week,
                    today: _today,
                    selected: _selected,
                    busy: {
                      for (final day in _week)
                        if (_plans.plansOn(day).isNotEmpty) day.day,
                    },
                    onPick: _pickDay,
                  ),
                  const SizedBox(height: 4),
                  _TextButton(
                    label: 'Pick another date ›',
                    onTap: () => unawaited(_pickAnotherDate(context)),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    closing == null
                        ? 'Time'
                        : 'Time · they close at '
                            '${OpeningHours.formatClock(closing)}',
                    style: appSectionTitleStyle(context),
                  ),
                  const SizedBox(height: 10),
                  _SlotRow(
                    slot: _slot,
                    onSelect: (slot) => setState(() => _slot = slot),
                  ),
                  const SizedBox(height: 12),
                  // `.vote` is a label and a switch, with no second line —
                  // [PrefSwitchRow] insists on a subtitle, so the switch
                  // stands on its own here.
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Let friends vote on the time',
                          style: TextStyle(
                            fontFamily: kTextFontFamily,
                            fontSize: kFontSizeBody,
                            color: kAccentCream,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      PrefSwitch(
                        value: _vote,
                        semanticLabel: 'Let friends vote on the time',
                        onChanged: (value) => setState(() => _vote = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  PrefSwitchRow(
                    title: 'Share with friends',
                    subtitle:
                        'They can see it on their calendar and ask to join',
                    value: _shared,
                    onChanged: (value) => setState(() => _shared = value),
                  ),
                  const SizedBox(height: 18),
                  Text("Who's coming", style: appSectionTitleStyle(context)),
                  const SizedBox(height: 10),
                  _WhoRow(
                    people: coming,
                    dimmed: _justMe,
                    caption: _whoCaption(coming),
                    justMe: _justMe,
                    onAdd: () => unawaited(_openInvite(context)),
                    onToggleJustMe: () => setState(() => _justMe = !_justMe),
                  ),
                  const SizedBox(height: 16),
                  _SummaryCard(
                    date: _selected,
                    line: planSummaryLine(_selected, _slot, coming.length),
                    subtitle: _summarySubtitle(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          AppPrimaryButton(
            label: 'Next · invite friends',
            expand: true,
            onPressed: () => unawaited(_openInvite(context)),
          ),
        ],
      ),
    );
  }

  String _summarySubtitle() {
    final distance = widget.draft.distanceFrom(userPosition);
    return distance == null
        ? widget.draft.title
        : '${widget.draft.title} · $distance';
  }

  String _peekSubtitle() {
    final neighbourhood = widget.draft.neighbourhood?.trim();
    final open = widget.draft.hours.statusLabel(OpeningHours.kualaLumpurNow());
    return [
      if (neighbourhood != null && neighbourhood.isNotEmpty) neighbourhood,
      if (open != null) open.toLowerCase(),
    ].join(' · ');
  }

  /// The line under the names. Only what the data supports: these are the
  /// friends who have ngap'd the place, which is the one thing the server
  /// tells us about them.
  String? _whoCaption(List<FriendProfile> coming) {
    final likedIds = {for (final person in _liked) person.id};
    final names = [
      for (final person in coming)
        if (likedIds.contains(person.id)) person.name,
    ];
    return friendsBiteCaption(names);
  }

  /// Which quick chip is pressed, by the mockup's own rule: a day chosen off
  /// the strip presses "This week" unless it is today, which presses
  /// "Tonight". A day picked out of the full calendar presses none.
  String? get _quickPressed {
    if (!_week.any((day) => isSameDay(day, _selected))) {
      return null;
    }
    if (isSameDay(_selected, _today)) {
      return 'Tonight';
    }
    if (isSameDay(_selected, _week[1])) {
      return 'Tomorrow';
    }
    return 'This week';
  }

  void _pickDay(DateTime day) => setState(() => _selected = day);

  void _pickQuick(String label) {
    setState(() {
      _selected = switch (label) {
        'Tonight' => _week.first,
        'Tomorrow' => _week[1],
        _ => _week.last,
      };
    });
  }

  Future<void> _pickAnotherDate(BuildContext context) async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: kSurfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
      ),
      builder: (context) => _MonthSheet(today: _today, selected: _selected),
    );
    if (picked != null && mounted) {
      setState(() => _selected = picked);
    }
  }

  /// Step two. The selection travels there and back, so backing out of the
  /// guest list keeps what was picked in it rather than starting again.
  Future<void> _openInvite(BuildContext context) async {
    final back = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute<Set<String>>(
        builder: (context) => InvitePage.draft(
          draft: widget.draft,
          date: _selected,
          slot: _slot,
          vote: _vote,
          shared: _shared,
          preselected: _justMe ? const <String>{} : _invited,
          friends: widget.friends,
          plans: widget.controller,
        ),
      ),
    );
    if (back != null && mounted) {
      setState(() {
        _invited = back;
        _seeded = true;
        _justMe = back.isEmpty && _justMe;
      });
    }
  }

  static DateTime _startOfDay(DateTime at) =>
      DateTime(at.year, at.month, at.day);
}

/// The design's `.peek` — the thing this sheet is about, and a way out.
class _PeekHeader extends StatelessWidget {
  const _PeekHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: kTextFontFamily,
                  fontSize: kFontSizeBody,
                  fontWeight: FontWeight.w600,
                  color: kAccentCream,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kFontSizeSmall,
                    color: kCreamSecondary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        AppIconButton(
          icon: icon,
          size: kUtilityButtonSize,
          onPhoto: false,
          semanticLabel: semanticLabel,
          onTap: onTap,
        ),
      ],
    );
  }
}

/// `.sh` — the question and which of the two steps it is.
///
/// Shared with the invite sheet, which asks the second question. One copy,
/// because the squeeze it guards against is the same on both and was found on
/// only one of them.
class SheetHeading extends StatelessWidget {
  const SheetHeading({super.key, required this.title, this.step});

  final String title;

  /// Null on a sheet that is not one of a numbered pair.
  final String? step;

  @override
  Widget build(BuildContext context) {
    final heading = Text(title, style: appTitleStyle(context));
    final label = step;
    if (label == null) {
      return heading;
    }
    final counter = Text(
      label,
      style: const TextStyle(
        fontFamily: kTextFontFamily,
        fontSize: kFontSizeSmall,
        color: kCreamSecondary,
      ),
    );

    // The step counter takes its own width, so the title's Expanded is handed
    // whatever is left — and at a doubled text scale on a 320 px screen that
    // is less than nothing, by about three quarters of a pixel. The pair
    // stacks instead of ellipsing, because "Step 1 o…" tells the reader
    // neither which step they are on nor how many there are. Same threshold,
    // and the same reasoning, as the friends page's Accept/Decline pair.
    if (MediaQuery.textScalerOf(context).scale(kFontSizeSmall) >
        kRowActionsStackFontSize) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [heading, counter],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: heading),
        const SizedBox(width: 8),
        counter,
      ],
    );
  }
}

/// `.quick` — Tonight, Tomorrow, This week.
class _QuickRow extends StatelessWidget {
  const _QuickRow({required this.pressed, required this.onPick});

  final String? pressed;
  final ValueChanged<String> onPick;

  static const List<String> labels = ['Tonight', 'Tomorrow', 'This week'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final label in labels)
          IntrinsicWidth(
            child: AppFilterChip(
              label: label,
              selected: label == pressed,
              onTap: () => onPick(label),
            ),
          ),
      ],
    );
  }
}

/// `.week` — seven days from today, the one you are standing on marked and the
/// ones you already have plans on dotted.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.week,
    required this.today,
    required this.selected,
    required this.busy,
    required this.onPick,
  });

  final List<DateTime> week;
  final DateTime today;
  final DateTime selected;
  final Set<int> busy;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final day in week) ...[
            _WeekDay(
              date: day,
              isToday: isSameDay(day, today),
              selected: isSameDay(day, selected),
              busy: busy.contains(day.day),
              onTap: () => onPick(day),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.date,
    required this.isToday,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final DateTime date;
  final bool isToday;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: [
        '${weekdayShort(date)} ${date.day} ${shortMonth(date)}',
        if (isToday) 'today',
        if (busy) 'you have a plan',
      ].join(', '),
      button: true,
      selected: selected,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? kAccentEmber : kSurfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusThumb),
          side: BorderSide(
            color: isToday && !selected ? kAccentEmber : kHairline,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadiusThumb),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: kMinTapTarget),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  weekdayShort(date),
                  style: TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kFontSizeMicro,
                    color: selected ? kOnAccent : kCreamSecondary,
                  ),
                ),
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kFontSizeBody,
                    fontWeight: FontWeight.w700,
                    color: selected ? kOnAccent : kAccentCream,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: kCalendarDotSize,
                  height: kCalendarDotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: busy
                        ? (selected ? kOnAccent : kAccentEmber)
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.more-dates` — the way out of the seven days on offer.
class _TextButton extends StatelessWidget {
  const _TextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, kMinTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        foregroundColor: kCreamSecondary,
        textStyle: const TextStyle(
          fontFamily: kTextFontFamily,
          fontSize: kFontSizeSmall,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label),
    );
  }
}

/// The full month, in the bottom sheet "Pick another date ›" opens.
class _MonthSheet extends StatefulWidget {
  const _MonthSheet({required this.today, required this.selected});

  final DateTime today;
  final DateTime selected;

  @override
  State<_MonthSheet> createState() => _MonthSheetState();
}

class _MonthSheetState extends State<_MonthSheet> {
  late DateTime _month = firstOfMonth(widget.selected);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlanCalendarHeader(
              month: _month,
              // No arrow back past the month you are standing in: there is no
              // plan to be made in a week that has already happened.
              onPrevious: isSameMonth(_month, widget.today)
                  ? null
                  : () => setState(() => _month = addMonths(_month, -1)),
              onNext: () => setState(() => _month = addMonths(_month, 1)),
            ),
            const SizedBox(height: 12),
            PlanCalendar(
              month: _month,
              today: widget.today,
              selectedDay: widget.selected,
              disablePast: true,
              semanticsLabel: 'Choose a day',
              onSelectDay: (date) => Navigator.of(context).pop(date),
            ),
          ],
        ),
      ),
    );
  }
}

/// The design's `.slots`: four chips, one pressed.
class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.slot, required this.onSelect});

  final PlanSlot slot;
  final ValueChanged<PlanSlot> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final option in kPlanSheetSlots)
          // [AppFilterChip] is built for a row with room to spare, where its
          // width comes from its label. A [Wrap] hands its children the whole
          // line instead, which would stack the chips one per row;
          // [IntrinsicWidth] gives each one back the width of its own pill.
          IntrinsicWidth(
            child: AppFilterChip(
              label: slotClockLabel(option),
              selected: identical(option, slot),
              // No "tap the pressed one to clear it": a plan without a time is
              // not a state this screen can be in, so there is nothing to
              // return to.
              onTap: () => onSelect(option),
            ),
          ),
      ],
    );
  }
}

/// `.who` — the faces, the `+`, who they are, and the way to drop all of them.
class _WhoRow extends StatelessWidget {
  const _WhoRow({
    required this.people,
    required this.dimmed,
    required this.caption,
    required this.justMe,
    required this.onAdd,
    required this.onToggleJustMe,
  });

  final List<FriendProfile> people;
  final bool dimmed;
  final String? caption;
  final bool justMe;
  final VoidCallback onAdd;
  final VoidCallback onToggleJustMe;

  @override
  Widget build(BuildContext context) {
    final names = friendNamesLine(people.map((p) => p.name).toList());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(kRadiusPanel),
        border: Border.all(color: kHairline),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (people.isNotEmpty)
            Opacity(
              opacity: dimmed ? 0.3 : 1,
              child: FriendAvatarStack(people: people),
            ),
          AppIconButton(
            icon: Icons.add_rounded,
            size: kRoundActionSize,
            iconSize: 18,
            onPhoto: false,
            semanticLabel: 'Add friends',
            onTap: onAdd,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  names,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kFontSizeSmall,
                    fontWeight: FontWeight.w600,
                    color: kAccentCream,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: kTextFontFamily,
                      fontSize: kFontSizeMicro,
                      color: kCreamSecondary,
                    ),
                  ),
              ],
            ),
          ),
          _TextButton(
            label: justMe ? 'Add friends back' : 'Just me',
            onTap: onToggleJustMe,
          ),
        ],
      ),
    );
  }
}

/// "Aiman, Mei Kee +1", or "Just you" when nobody is coming.
String friendNamesLine(List<String> names) {
  final firsts = [
    for (final name in names)
      if (name.trim().isNotEmpty) firstName(name),
  ];
  if (firsts.isEmpty) {
    return 'Just you';
  }
  if (firsts.length <= 2) {
    return firsts.join(', ');
  }
  return '${firsts.take(2).join(', ')} +${firsts.length - 2}';
}

/// `.summary` — the little calendar block and the answer read back.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.date,
    required this.line,
    required this.subtitle,
  });

  final DateTime date;
  final String line;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(kRadiusPanel),
        border: Border.all(color: kHairline),
      ),
      child: Row(
        children: [
          Container(
            width: kWishThumbSize,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: kSurfacePanel,
              borderRadius: BorderRadius.circular(kRadiusWishThumb),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shortMonth(date),
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kFontSizeMicro,
                    color: kAccentEmber,
                  ),
                ),
                Text(
                  '${date.day}',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kFontSizeBody,
                    fontWeight: FontWeight.w700,
                    color: kAccentCream,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kPickedTitleFontSize,
                    fontWeight: FontWeight.w600,
                    color: kTextOnPhoto,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kFontSizeSmall,
                    color: kCreamSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
