import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/distance_label.dart';
import '../../../core/location/user_location.dart';
import '../../../dev/calendar_dev_data.dart';
import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_lottie.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../dashboard/presentation/dashboard_widgets.dart';
import '../../dashboard/state/dashboard_tab_request.dart';
import '../../friends/domain/friend_captions.dart';
import '../../friends/models/friend.dart';
import '../../friends/presentation/friend_avatar.dart';
import '../../friends/state/friends_controller.dart';
import '../domain/plan_labels.dart';
import '../models/plan.dart';
import '../state/plans_controller.dart';
import 'plan_calendar.dart';

/// S6 · Calendar. The month you are in, and the plans inside it.
///
/// Replaces the old `GroupTab` placeholder at nav index 3. The tab lives under
/// `features/plans` rather than under `features/dashboard` because it is the
/// plans feature's screen; the dashboard only decides where to hang it.
class CalendarTab extends StatefulWidget {
  const CalendarTab({
    super.key,
    this.controller,
    this.friends,
    this.tabRequests,
    this.resolvePosition,
  });

  /// Injected by tests; in the app the shared instances are used.
  final PlansController? controller;

  /// Where the faces on each card come from. `Plan.members` carries ids and
  /// statuses, which is enough to count people but not enough to draw them.
  final FriendsController? friends;
  final DashboardTabRequest? tabRequests;

  /// How the tab learns where the phone is, for the "· 6 km" on each row.
  /// Injected so a widget test never reaches a platform channel.
  final Future<Position> Function()? resolvePosition;

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  late final PlansController _plans =
      widget.controller ?? PlansController.instance;
  late final FriendsController _friends =
      widget.friends ?? FriendsController.instance;
  late final DashboardTabRequest _tabs =
      widget.tabRequests ?? DashboardTabRequest.instance;

  late final DateTime _today = _startOfDay(_plans.now);
  late DateTime _month = firstOfMonth(_today);

  /// Null until a fix lands, and left null when the only fix available is the
  /// fallback — a made-up distance on every row is worse than no distance.
  Position? _position;

  bool _searching = false;
  String _query = '';

  /// The plan ids the rosters were last asked for. Guards against the loop
  /// that would otherwise form: `loadPlanPeople` notifies, the notification
  /// rebuilds this tab, and a rebuild that asked again would notify again.
  /// Asking is driven by the plan list changing, never by a build.
  Set<int> _rosterAskedFor = const {};

  @override
  void initState() {
    super.initState();
    _plans.addListener(_onPlansChanged);
    _friends.addListener(_onFriendsChanged);
    unawaited(_plans.ensureLoaded());
    unawaited(_resolvePosition());
    // The shared controller may already hold this month, in which case the
    // load below never notifies and the rosters would never be asked for.
    _syncRosters();
  }

  @override
  void dispose() {
    _plans.removeListener(_onPlansChanged);
    _friends.removeListener(_onFriendsChanged);
    super.dispose();
  }

  void _onPlansChanged() {
    if (mounted) {
      setState(() {});
      _syncRosters();
    }
  }

  void _onFriendsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Asks for the rosters of every plan the controller holds, once per set.
  ///
  /// Every plan rather than only the month on screen: the controller holds
  /// this month onward and nothing else, stepping to another month does not
  /// reload anything, and one call for the lot is cheaper than one per month
  /// the user flicks past.
  void _syncRosters() {
    final ids = {for (final plan in _plans.plans) plan.id};
    if (ids.isEmpty || setEquals(ids, _rosterAskedFor)) {
      return;
    }
    _rosterAskedFor = ids;
    unawaited(_friends.loadPlanPeople(ids));
  }

  Future<void> _resolvePosition() async {
    final resolve = widget.resolvePosition ??
        (const bool.fromEnvironment('USE_DEV_PLANS')
            ? devUserPosition
            : resolveUserPosition);
    try {
      final position = await resolve();
      if (!mounted || isFallbackUserPosition(position)) {
        return;
      }
      setState(() => _position = position);
    } on Object catch (error) {
      debugPrint('Calendar could not resolve a position: $error');
    }
  }

  /// The plans the sections list: the shown month, from today onward when that
  /// month is this one. A month already chosen from the sheet lists all of it —
  /// there is nothing "upcoming" about October when you are looking at October.
  List<Plan> get _visiblePlans {
    final inMonth = [
      for (final plan in _plans.plans)
        if (isSameMonth(plan.date, _month) &&
            (!isSameMonth(_month, _today) || !plan.date.isBefore(_today)))
          plan,
    ]..sort((a, b) {
        final byDay = a.date.compareTo(b.date);
        return byDay != 0 ? byDay : a.sortMinutes.compareTo(b.sortMinutes);
      });

    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return inMonth;
    }
    return [
      for (final plan in inMonth)
        if (plan.restaurantName.toLowerCase().contains(query)) plan,
    ];
  }

  Map<int, PlanDayMark> get _marks {
    final byDay = <int, List<Plan>>{};
    for (final plan in _plans.plans) {
      if (isSameMonth(plan.date, _month)) {
        byDay.putIfAbsent(plan.date.day, () => []).add(plan);
      }
    }

    return {
      for (final entry in byDay.entries)
        entry.key: PlanDayMark(
          // The earliest plan's cover is the one the ring wears — the same
          // "next thing happening" rule the Bites badge follows.
          coverUrl: entry.value.first.coverUrl,
          planCount: entry.value.length,
          // Each plan can bring friends; the grid shows one cream pip per
          // unique friend still coming that day. Declined guests are left out,
          // the same rule the row's avatar stack applies.
          friendCount: {
            for (final plan in entry.value)
              for (final member in plan.members)
                if (member.status != 'declined') member.userId,
          }.length,
          initials: entry.value.first.initials,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: kBackgroundDark),
      child: Stack(
        children: [
          const ScreenGlow(),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding + 2,
                    18,
                    AppSpacing.screenPadding + 2,
                    12,
                  ),
                  child: _TopBar(
                    searching: _searching,
                    query: _query,
                    onToggleSearch: _toggleSearch,
                    onQueryChanged: (value) => setState(() => _query = value),
                    onNewPlan: () => _tabs.show(0),
                  ),
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_plans.isLoaded) {
      final error = _plans.error;
      if (error == null) {
        return const Center(
            child: AppLottie(motion: AppMotion.heart, size: 88));
      }
      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          EmptyTabMessage(
            title: 'Something went wrong',
            subtitle: error,
            actionLabel: 'Try again',
            onAction: () => unawaited(_plans.refresh()),
          ),
        ],
      );
    }

    final rows = _visiblePlans;
    final sections = _groupByDay(rows);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        0,
        AppSpacing.screenPadding,
        AppSpacing.screenPadding,
      ),
      children: [
        // Header and grid sit on the page itself, exactly as the date picker
        // draws them. They used to be boxed in a SimpleCard, and the card's
        // border and padding made the same widget read as a different
        // calendar on the two screens the user moves between.
        PlanCalendarHeader(
          month: _month,
          // No stepping back past the month you are standing in — the tab
          // only ever lists from today forward, so an earlier month would be
          // a grid that can hold nothing. Same rule the picker uses.
          onPrevious: isSameMonth(_month, _today) ? null : () => _stepMonth(-1),
          onNext: () => _stepMonth(1),
        ),
        const SizedBox(height: 12),
        PlanCalendar(
          month: _month,
          today: _today,
          marks: _marks,
          semanticsLabel: 'Your plans this month',
        ),
        if (_plans.plans.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: EmptyTabMessage(
              title: 'No plans yet',
              subtitle: 'Bite something, then pick a day.',
              actionLabel: 'Start swiping',
              onAction: () => _tabs.show(0),
            ),
          )
        else if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: EmptyTabMessage(
              title: _query.isEmpty
                  ? 'Nothing this month'
                  : 'Nothing matches that',
              subtitle: _query.isEmpty
                  ? 'Pick another month, or bite something new.'
                  : 'Try a different name.',
            ),
          ),
        for (final section in sections) ...[
          _SectionHead(
            title: daySectionTitle(section.key, _today),
            count: section.value.length,
          ),
          for (final plan in section.value)
            _PlanRow(
              plan: plan,
              people: _friends.peopleFor(plan.id),
              position: _position,
              onTap: () => _openPlan(plan),
              onCancel: () => unawaited(_confirmCancel(plan)),
            ),
        ],
      ],
    );
  }

  List<MapEntry<DateTime, List<Plan>>> _groupByDay(List<Plan> rows) {
    final grouped = <DateTime, List<Plan>>{};
    for (final plan in rows) {
      grouped.putIfAbsent(plan.date, () => []).add(plan);
    }
    final keys = grouped.keys.toList()..sort();

    return [for (final key in keys) MapEntry(key, grouped[key]!)];
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
      }
    });
  }

  /// The card opens the plan, not the place. It used to open the place, which
  /// was the only thing a plan could show before it had guests — now the plan
  /// has a time to vote on and a roster to answer, and the restaurant is one
  /// tap further in, from the plan's own header.
  void _openPlan(Plan plan) {
    context.push('/plans/${plan.id}');
  }

  /// Walks the grid a month at a time, the way the picker's arrows do.
  ///
  /// Replaces a bottom sheet listing six months. The design puts arrows on
  /// this header, and two taps to reach next month beats a sheet — the tab
  /// only ever looks a few months ahead.
  void _stepMonth(int delta) {
    setState(() => _month = addMonths(_month, delta));
  }

  /// A sheet, not a dialog: cancelling is a decision about a row on this
  /// screen, and a sheet keeps that row on screen behind it.
  Future<void> _confirmCancel(Plan plan) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: kSurfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cancel ${plan.restaurantName}?',
                style: appPanelTitleStyle(sheetContext),
              ),
              const SizedBox(height: 6),
              Text(
                'It comes off your calendar. You can pick the day again any '
                'time.',
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: kTextOnPhotoMuted,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppSecondaryButton(
                      label: 'Keep it',
                      expand: true,
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppSecondaryButton(
                      label: 'Cancel plan',
                      expand: true,
                      tint: kAccentEmber,
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _plans.cancel(plan.id);
    } on Object catch (error) {
      debugPrint('Cancelling a plan failed: $error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not cancel that plan.')),
      );
    }
  }

  static DateTime _startOfDay(DateTime at) =>
      DateTime(at.year, at.month, at.day);
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.searching,
    required this.query,
    required this.onToggleSearch,
    required this.onQueryChanged,
    required this.onNewPlan,
  });

  final bool searching;
  final String query;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onNewPlan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Calendar', style: appTitleStyle(context)),
            ),
            AppIconButton(
              icon: searching ? Icons.close_rounded : Icons.search_rounded,
              size: kUtilityButtonSize,
              onPhoto: false,
              semanticLabel: searching ? 'Close search' : 'Search plans',
              onTap: onToggleSearch,
            ),
            const SizedBox(width: 8),
            AppIconButton(
              icon: Icons.add_rounded,
              size: kUtilityButtonSize,
              onPhoto: false,
              semanticLabel: 'New plan',
              onTap: onNewPlan,
            ),
          ],
        ),
        if (searching) ...[
          const SizedBox(height: 10),
          TextField(
            autofocus: true,
            onChanged: onQueryChanged,
            style: const TextStyle(
              fontFamily: kTextFontFamily,
              fontSize: kFontSizeBody,
              color: kTextOnPhoto,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search your plans',
              hintStyle: const TextStyle(
                fontFamily: kTextFontFamily,
                fontSize: kFontSizeBody,
                color: kCreamMuted,
              ),
              filled: true,
              fillColor: kSurfaceDark,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kRadiusPill),
                borderSide: const BorderSide(color: kHairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kRadiusPill),
                borderSide: const BorderSide(color: kHairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kRadiusPill),
                borderSide: const BorderSide(color: kAccentEmber),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(title, style: appSectionTitleStyle(context)),
          ),
          const SizedBox(width: 8),
          Text(
            planCount(count),
            style: const TextStyle(
              fontFamily: kTextFontFamily,
              fontSize: kFontSizeSmall,
              color: kCreamSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The design's `.plan` row: logo, name over a detail line, and the ember time
/// pill.
class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.plan,
    required this.people,
    required this.position,
    required this.onTap,
    required this.onCancel,
  });

  final Plan plan;

  /// The guests, once their names have been found. Empty until the roster
  /// lands, which is why the count on the subtitle is read off `plan.members`
  /// instead: the line is right the moment the plan is, and the faces appear
  /// under it a beat later without moving anything.
  final List<PlanPerson> people;
  final Position? position;
  final VoidCallback onTap;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitle();
    final faces = [
      for (final person in people)
        if (person.status != 'declined') person.profile,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        label: '${plan.restaurantName}, $subtitle, ${plan.timeText}',
        button: true,
        // Excluding the children keeps the announcement one sentence; that
        // also drops the InkWell's actions, so both are re-declared here (D83)
        // — including the long press, which is the only way to cancel.
        excludeSemantics: true,
        onTap: onTap,
        onLongPress: onCancel,
        child: Material(
          color: kGlass,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusPanel),
            side: const BorderSide(color: kHairline),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(kRadiusPanel),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              onCancel();
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _PlanLogo(plan: plan),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          plan.restaurantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: kTextFontFamily,
                            fontSize: kFontSizeBody,
                            fontWeight: FontWeight.w600,
                            color: kTextOnPhoto,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // `.plan .t .sub{display:flex;align-items:center;
                        // gap:6px}` — the faces sit on the subtitle line, not
                        // beside the logo.
                        Row(
                          children: [
                            if (faces.isNotEmpty) ...[
                              FriendAvatarStack(
                                people: faces,
                                size: kAvatarSizeCompact,
                                borderWidth: kAvatarBorderCompact,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: kTextFontFamily,
                                  fontSize: kFontSizeSmall,
                                  color: kCreamSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _TimePill(label: plan.timeText),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "3 friends · 2 confirmed · Kepong · 6 km", or "Just you · Kajang · 22 km"
  /// on a plan nobody was invited to. Every part after the first is dropped
  /// when it is not known, rather than filled with a guess — a distance the
  /// app invented is worse than a line that is one item shorter.
  ///
  /// Who is coming leads, always. The design's three plan cards do not agree
  /// on this — one of them draws two faces beside "Lunch · Kepong · 6 km" —
  /// but the other two are the people line, `planPeopleLine` has a "Just you"
  /// branch that exists for one of them, and a meal label sitting next to the
  /// time pill that implies it is the least this line can say. One rule for
  /// all three cards beats reproducing a disagreement.
  String _subtitle() {
    final counts = planHeadcount([
      for (final member in plan.members) member.status,
    ]);
    final parts = <String>[
      planPeopleLine(guests: counts.guests, confirmed: counts.confirmed),
    ];

    final neighbourhood = plan.neighbourhood;
    if (neighbourhood != null && neighbourhood.isNotEmpty) {
      parts.add(neighbourhood);
    }

    final distance = _distance();
    if (distance != null) {
      parts.add(distance);
    }

    return parts.join(' · ');
  }

  String? _distance() {
    final at = position;
    final latitude = plan.latitude;
    final longitude = plan.longitude;
    if (at == null || latitude == null || longitude == null) {
      return null;
    }
    final label = distanceLabelFrom(
      at,
      latitude: latitude,
      longitude: longitude,
    );
    // The shared helper says "6.2 km away" mid-sentence and falls back to the
    // city name when it cannot tell. This row has a city on it already and no
    // room for "away", so the city fallback is dropped and the suffix trimmed
    // — the number itself still comes from the one place that computes it.
    if (!label.contains('km') && !label.contains(' m')) {
      return null;
    }
    return label.replaceAll(' away', '');
  }
}

class _PlanLogo extends StatelessWidget {
  const _PlanLogo({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final cover = plan.coverUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusPlanLogo),
      child: Container(
        width: kPlanLogoSize,
        height: kPlanLogoSize,
        color: kSurfacePanel,
        alignment: Alignment.center,
        child: cover == null || cover.isEmpty
            ? Text(
                plan.initials,
                style: const TextStyle(
                  fontFamily: kDisplayFontFamily,
                  fontSize: kPlanInitialsFontSize,
                  fontWeight: FontWeight.w800,
                  color: kTextOnPhoto,
                ),
              )
            : Image.network(
                cover,
                fit: BoxFit.cover,
                width: kPlanLogoSize,
                height: kPlanLogoSize,
                errorBuilder: (context, _, __) => Text(
                  plan.initials,
                  style: const TextStyle(
                    fontFamily: kDisplayFontFamily,
                    fontSize: kPlanInitialsFontSize,
                    fontWeight: FontWeight.w800,
                    color: kTextOnPhoto,
                  ),
                ),
              ),
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kAccentEmber,
        borderRadius: BorderRadius.circular(kRadiusPill),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          fontFamily: kTextFontFamily,
          fontSize: kFontSizeSmall,
          fontWeight: FontWeight.w700,
          color: kOnAccent,
        ),
      ),
    );
  }
}
