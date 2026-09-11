import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../profile/presentation/preference_controls.dart';
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

    return PlanDraft(
      restaurantId: restaurantId,
      title: payload['title'] as String? ?? 'A place',
      coverUrl: payload['coverUrl'] as String?,
      neighbourhood: payload['neighbourhood'] as String?,
      tag: payload['tag'] as String?,
    );
  }

  final int restaurantId;
  final String title;
  final String? coverUrl;
  final String? neighbourhood;
  final String? tag;

  /// The short name the summary line uses — "Warung Kak Ros" is the topbar's
  /// job, and the bar under it has a friends count to fit as well.
  String get shortName {
    final words = title.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.length > 2 ? words.skip(1).take(2).join(' ') : title;
  }
}

/// S4 · Pick a date. A month, five times, and one switch.
///
/// Everything above the summary bar is a question; the bar is the answer read
/// back. "Lock it in" stays disabled until a day is chosen — a day is the one
/// thing the screen cannot supply a sensible default for, and the design has
/// no count to put in the label, so the button simply waits.
class PlanDatePage extends StatefulWidget {
  const PlanDatePage({
    super.key,
    required this.draft,
    this.controller,
    this.onCreated,
  });

  final PlanDraft draft;

  /// Injected by tests; in the app the shared instance is used.
  final PlansController? controller;

  /// Where the screen goes once the plan exists. Injected so a test can watch
  /// what it was handed without driving a router.
  final void Function(BuildContext context, int planId, bool withFriends)?
      onCreated;

  @override
  State<PlanDatePage> createState() => _PlanDatePageState();
}

class _PlanDatePageState extends State<PlanDatePage> {
  late final PlansController _plans =
      widget.controller ?? PlansController.instance;

  /// Read once, in `initState`: a page that asked the clock on every build
  /// would redraw "today" mid-session, and every test would race it.
  late final DateTime _today = _startOfDay(_plans.now);

  late DateTime _month = firstOfMonth(_today);
  DateTime? _selected;
  PlanSlot _slot = PlanSlot.initial;
  bool _withFriends = true;
  bool _saving = false;

  bool get _canLockIn => _selected != null && !_saving;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      body: Stack(
        children: [
          const ScreenGlow(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                12,
                AppSpacing.screenPadding,
                22,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopBar(title: widget.draft.title),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            'When are we going?',
                            style: appTitleStyle(context),
                          ),
                          const SizedBox(height: 16),
                          PlanCalendarHeader(
                            month: _month,
                            // No arrow back past the month you are standing
                            // in: there is no plan to be made in a week that
                            // has already happened.
                            onPrevious: isSameMonth(_month, _today)
                                ? null
                                : () => _stepMonth(-1),
                            onNext: () => _stepMonth(1),
                          ),
                          const SizedBox(height: 12),
                          PlanCalendar(
                            month: _month,
                            today: _today,
                            selectedDay: _selected,
                            disablePast: true,
                            semanticsLabel: 'Choose a day',
                            onSelectDay: (date) =>
                                setState(() => _selected = date),
                          ),
                          const SizedBox(height: 24),
                          Text('Time', style: appSectionTitleStyle(context)),
                          const SizedBox(height: 10),
                          _SlotRow(
                            slot: _slot,
                            onSelect: (slot) => setState(() => _slot = slot),
                          ),
                          const SizedBox(height: 14),
                          PrefSwitchRow(
                            title: 'Bring friends',
                            subtitle:
                                "Optional — they'll get a vote on the time",
                            value: _withFriends,
                            onChanged: (value) =>
                                setState(() => _withFriends = value),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  _PickedBar(
                    draft: widget.draft,
                    selected: _selected,
                    timeText: _slot.label,
                    withFriends: _withFriends,
                    saving: _saving,
                    onLockIn: _canLockIn ? _lockIn : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _stepMonth(int delta) {
    setState(() => _month = addMonths(_month, delta));
  }

  Future<void> _lockIn() async {
    final date = _selected;
    if (date == null) {
      return;
    }

    setState(() => _saving = true);
    try {
      final planId = await _plans.create(
        restaurantId: widget.draft.restaurantId,
        date: date,
        time: _slot.wireTime,
        timeLabel: _slot.wireLabel,
        withFriends: _withFriends,
      );
      if (!mounted) {
        return;
      }
      widget.onCreated?.call(context, planId, _withFriends);
    } on Object catch (error) {
      debugPrint('Locking in a plan failed: $error');
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that plan.')),
      );
    }
  }

  static DateTime _startOfDay(DateTime at) =>
      DateTime(at.year, at.month, at.day);
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIconButton(
          icon: Icons.chevron_left_rounded,
          size: kUtilityButtonSize,
          onPhoto: false,
          semanticLabel: 'Back',
          onTap: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: kTextFontFamily,
              fontSize: kFontSizeSmall,
              color: kCreamSecondary,
            ),
          ),
        ),
        // Balances the back button so the name sits on the screen's centre
        // line rather than on the centre of what is left over.
        const SizedBox(width: kUtilityButtonSize),
      ],
    );
  }
}

/// The design's `.slots`: five chips, one pressed. A [Wrap] rather than a
/// [Row] because at a large text scale five pills do not fit on one line, and
/// the prototype's own `flex-wrap:wrap` says what should happen then.
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
        for (final option in PlanSlot.all)
          // [AppFilterChip] is built for a row with room to spare, where its
          // width comes from its label. A [Wrap] hands its children the whole
          // line instead, which would stack the five chips one per row;
          // [IntrinsicWidth] gives each one back the width of its own pill.
          IntrinsicWidth(
            child: AppFilterChip(
              label: option.label,
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

/// The `.picked` bar: the thumbnail, the answer read back, and the button that
/// commits it.
class _PickedBar extends StatelessWidget {
  const _PickedBar({
    required this.draft,
    required this.selected,
    required this.timeText,
    required this.withFriends,
    required this.saving,
    required this.onLockIn,
  });

  final PlanDraft draft;
  final DateTime? selected;
  final String timeText;
  final bool withFriends;
  final bool saving;
  final VoidCallback? onLockIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(kRadiusPanel),
        border: Border.all(color: kHairline),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // "Lock it in" is a pill that cannot shrink, and at a doubled text
          // scale it alone is most of a 320 pt screen. Below the width where
          // the summary would ellipsize down to nothing, the bar stacks
          // instead — the answer read back stays legible and the button spans
          // the row under it.
          final stacked = constraints.maxWidth < kPickedBarStackWidth;
          final summary = _PickedSummary(
            draft: draft,
            selected: selected,
            timeText: timeText,
            withFriends: withFriends,
          );
          final button = AppPrimaryButton(
            label: 'Lock it in',
            busy: saving,
            onPressed: onLockIn,
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                summary,
                const SizedBox(height: 10),
                Row(children: [Expanded(child: button)]),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: summary),
              const SizedBox(width: 12),
              button,
            ],
          );
        },
      ),
    );
  }
}

/// The thumbnail and the two lines beside it — shared by both arrangements of
/// [_PickedBar].
class _PickedSummary extends StatelessWidget {
  const _PickedSummary({
    required this.draft,
    required this.selected,
    required this.timeText,
    required this.withFriends,
  });

  final PlanDraft draft;
  final DateTime? selected;
  final String timeText;
  final bool withFriends;

  @override
  Widget build(BuildContext context) {
    final day = selected;
    final cover = draft.coverUrl;

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(kRadiusWishThumb),
          child: Container(
            width: kWishThumbSize,
            height: kWishThumbSize,
            color: kSurfacePanel,
            child: cover == null || cover.isEmpty
                ? null
                : Image.network(
                    cover,
                    cacheWidth: cachePx(context, kWishThumbSize),
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, __) => const SizedBox.shrink(),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                day == null ? 'Pick a day' : pickedSummary(day, timeText),
                // The CSS says `white-space:nowrap`; in Flutter that has to
                // be spelled out or the line wraps the bar taller at a large
                // text scale.
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
                '${draft.shortName} · ${withFriends ? 'With friends' : 'Just you'}',
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
    );
  }
}
