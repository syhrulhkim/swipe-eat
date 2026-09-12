import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../plans/domain/plan_labels.dart';
import '../../plans/models/plan.dart';
import '../../plans/models/plan_slot.dart';
import '../../plans/presentation/plan_confirmed_page.dart';
import '../../plans/presentation/plan_date_page.dart';
import '../../plans/state/plans_controller.dart';
import '../domain/friend_captions.dart';
import '../domain/invite_ordering.dart';
import '../models/friend.dart';
import '../state/friends_controller.dart';
import 'friend_avatar.dart';
import 'person_row.dart';

/// S5 · Who's hungry? The screen has two lives.
///
/// **Draft** — step two of making a plan. Nothing is saved until "Lock it in"
/// here, which creates the plan *and* sends the invites, then shows the
/// confirmation. A guest list picked before the plan existed is a guest list
/// the user could change their mind about without losing anything.
///
/// **Plan** — `/plans/:id/invite`, opened from a plan that already exists to
/// ask more people. That one still says "Send invites" and still offers Skip,
/// because "Lock it in" on something already locked in would be a lie.
class InvitePage extends StatefulWidget {
  const InvitePage({
    super.key,
    required this.planId,
    this.friends,
    this.plans,
  })  : draft = null,
        date = null,
        slot = null,
        vote = false,
        shared = false,
        preselected = const {},
        onConfirmedExit = null;

  const InvitePage.draft({
    super.key,
    required PlanDraft this.draft,
    required DateTime this.date,
    required PlanSlot this.slot,
    required this.vote,
    required this.shared,
    this.preselected = const {},
    this.friends,
    this.plans,
    this.onConfirmedExit,
  }) : planId = null;

  /// Null in draft mode; set when the plan already exists.
  final int? planId;

  final PlanDraft? draft;
  final DateTime? date;
  final PlanSlot? slot;

  /// Whether the guests get a vote on the time — the design's switch on step
  /// one, and what the plan's `withFriends` flag has always meant.
  final bool vote;

  /// D153's "Share with friends", carried through from step one.
  final bool shared;

  final Set<String> preselected;

  /// Injected by tests; in the app the shared instances are used.
  final FriendsController? friends;
  final PlansController? plans;

  /// Handed straight to [PlanConfirmedPage]; injected so a test can watch the
  /// two exits without driving a router.
  final ValueChanged<int>? onConfirmedExit;

  bool get isDraft => draft != null;

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  late final FriendsController _friends =
      widget.friends ?? FriendsController.instance;
  late final PlansController _plans = widget.plans ?? PlansController.instance;

  late final Set<String> _selected = {...widget.preselected};
  String _query = '';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Both loads are already-loaded no-ops in the common case: the calendar
    // that pushed this screen has the plans, and the You tab usually has the
    // friends.
    _friends.ensureLoaded();
    _plans.ensureLoaded();
  }

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
              child: AnimatedBuilder(
                animation: Listenable.merge([_friends, _plans]),
                builder: (context, _) => _body(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final sections = _sections();
    final total = sections.fold<int>(0, (sum, s) => sum + s.people.length);
    final recent = widget.isDraft && _query.trim().isEmpty
        ? _recent()
        : const <FriendProfile>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isDraft)
          _DraftHeader(
            when: planPeekWhen(widget.date!, widget.slot!),
            place: widget.draft!.title,
            onBack: _sending ? null : () => _popWithSelection(context),
          )
        else
          _TopBar(
            subtitle: _planSubtitle(),
            onSkip: _sending ? null : () => Navigator.of(context).maybePop(),
          ),
        const SizedBox(height: 8),
        SheetHeading(
          title: "Who's hungry?",
          step: widget.isDraft ? 'Step 2 of 2' : null,
        ),
        const SizedBox(height: AppSpacing.md),
        _SearchField(
          // The design says "or groups"; there are no groups yet, so the
          // plan-mode field says only what it can do.
          hint: widget.isDraft ? 'Search friends or groups' : 'Search friends',
          onChanged: (value) => setState(() => _query = value),
        ),
        Expanded(
          child: total == 0 && recent.isEmpty
              ? _EmptyList(
                  searching: _query.trim().isNotEmpty,
                  loading: _friends.loading && !_friends.isLoaded,
                )
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 8),
                  children: [
                    if (recent.isNotEmpty) ...[
                      Text('Recent', style: _sectionStyle()),
                      const SizedBox(height: 6),
                      _RecentRow(
                        people: recent,
                        selected: _selected,
                        onToggle: _toggle,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    for (final section in sections) ...[
                      if (section.title != null) ...[
                        Text(section.title!, style: _sectionStyle()),
                        const SizedBox(height: 4),
                      ],
                      for (final person in section.people)
                        PersonRow(
                          key: ValueKey(person.id),
                          profile: person,
                          selected: _selected.contains(person.id),
                          onTap: () => _toggle(person.id),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
        ),
        if (widget.isDraft)
          _DraftFoot(
            people: _selectedProfiles(),
            count: _selected.length,
            vote: widget.vote,
            sending: _sending,
            onLockIn: _sending ? null : _lockIn,
          )
        else
          _InviteFoot(
            count: _selected.length,
            sending: _sending,
            onSend: _selected.isEmpty || _sending ? null : _send,
          ),
      ],
    );
  }

  TextStyle _sectionStyle() => const TextStyle(
        fontFamily: kTextFontFamily,
        fontSize: kFontSizeMicro,
        fontWeight: FontWeight.w600,
        color: kCreamSecondary,
      );

  String _planSubtitle() {
    final plan = _planOrNull();
    return plan == null ? 'Your plan' : pickedSummary(plan.date, plan.timeText);
  }

  Plan? _planOrNull() {
    for (final plan in _plans.plans) {
      if (plan.id == widget.planId) {
        return plan;
      }
    }
    return null;
  }

  Map<String, FriendProfile> get _byId =>
      {for (final friend in _friends.friends) friend.id: friend};

  List<FriendProfile> _selectedProfiles() {
    final byId = _byId;
    return [
      for (final id in _selected)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// The design's `.recent` strip — the people you last ate with, as chips.
  /// Empty on an account with no history, and then the strip is not drawn:
  /// "Recent" over your whole address book is a claim, not a heading.
  List<FriendProfile> _recent() {
    final byId = _byId;
    final ids = recentCompanionIds(
      plans: [
        for (final plan in _plans.plans)
          (plan.date, [for (final member in plan.members) member.userId]),
      ],
      among: byId.keys.toSet(),
      now: _plans.now,
    );
    return [for (final id in ids) byId[id]!];
  }

  /// The list, split the way the design draws it.
  ///
  /// Searching collapses the sections into one unheaded list: a heading over
  /// three results answers a question nobody asked, and "Ate with recently"
  /// over a name you typed would be wrong as often as it was right.
  List<_Section> _sections() {
    final query = _query;
    final all = [
      for (final friend in _friends.friends)
        if (matchesQuery(friend.name, query)) friend,
    ];
    if (query.trim().isNotEmpty) {
      return [_Section(null, all)];
    }

    // Step two heads the whole list with the day it is for; the recent strip
    // above it is the "who first" half the plan-mode headings do in words.
    if (widget.isDraft) {
      return [
        _Section(
          all.isEmpty ? null : 'Suggested for ${weekdayName(widget.date!)}',
          all,
        ),
      ];
    }

    // The window is whatever the calendar holds, which starts at the first of
    // the current month — so early in a month this section is short or absent.
    // Widening it would mean a second query for history no other screen wants,
    // and the fallback heading below is honest about having nothing to show.
    final byId = {for (final friend in all) friend.id: friend};
    final recentIds = recentCompanionIds(
      plans: [
        for (final plan in _plans.plans)
          (plan.date, [for (final member in plan.members) member.userId]),
      ],
      among: byId.keys.toSet(),
      now: _plans.now,
    );
    if (recentIds.isEmpty) {
      // Nobody to put under "Ate with recently" — a new account, or one whose
      // dinners have all been alone. The heading changes rather than sitting
      // over the whole address book, which would be a claim the screen has no
      // evidence for.
      return [_Section(all.isEmpty ? null : 'Your friends', all)];
    }

    final recent = [for (final id in recentIds) byId[id]!];
    final rest = [
      for (final friend in all)
        if (!recentIds.contains(friend.id)) friend,
    ];
    return [
      _Section('Ate with recently', recent),
      if (rest.isNotEmpty) _Section('Your friends', rest),
    ];
  }

  void _toggle(String userId) {
    setState(() {
      if (!_selected.remove(userId)) {
        _selected.add(userId);
      }
    });
  }

  void _popWithSelection(BuildContext context) {
    Navigator.of(context).pop<Set<String>>({..._selected});
  }

  /// Draft mode. The plan is made here, then the invites go out, then the
  /// confirmation. If the invites fail the plan still stands — losing a saved
  /// evening to a dropped connection is the one outcome this screen may not
  /// produce — so the confirmation is shown anyway and the failure is said out
  /// loud on top of it.
  Future<void> _lockIn() async {
    final draft = widget.draft!;
    setState(() => _sending = true);

    final int planId;
    try {
      planId = await _plans.create(
        restaurantId: draft.restaurantId,
        date: widget.date!,
        time: widget.slot!.wireTime,
        timeLabel: widget.slot!.wireLabel,
        withFriends: widget.vote,
        shared: widget.shared,
      );
    } on Object catch (error) {
      debugPrint('Locking in a plan failed: $error');
      if (!mounted) {
        return;
      }
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that plan.')),
      );
      return;
    }

    var invitesFailed = false;
    if (_selected.isNotEmpty) {
      try {
        await _friends.invite(planId, _selected);
      } on Object catch (error) {
        debugPrint('Sending invites failed: $error');
        invitesFailed = true;
      }
    }

    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    // Not awaited: this future settles when the confirmation is *popped*, and
    // the failure below has to be said now, on top of it.
    unawaited(Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => PlanConfirmedPage(
          planId: planId,
          draft: draft,
          date: widget.date!,
          slot: widget.slot!,
          vote: widget.vote,
          invited: {..._selected},
          friends: widget.friends,
          onExit: widget.onConfirmedExit,
        ),
      ),
    ));
    if (invitesFailed) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not send those invites.')),
      );
    }
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await _friends.invite(widget.planId!, _selected);
      // The calendar behind this screen draws its member counts off the plans
      // list, so it has to be re-read before the pop lands on it.
      await _plans.refresh();
      if (!mounted) {
        return;
      }
      await Navigator.of(context).maybePop();
    } on Object catch (error) {
      debugPrint('Sending invites failed: $error');
      if (!mounted) {
        return;
      }
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send those invites.')),
      );
    }
  }
}

class _Section {
  const _Section(this.title, this.people);

  final String? title;
  final List<FriendProfile> people;
}

/// "Friday" — the design heads the suggested list with the day in full, and
/// nothing else in the app spells a weekday out.
String weekdayName(DateTime date) => const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][date.weekday - 1];

/// `.peek` on step two: what is being planned, and the way back to step one.
class _DraftHeader extends StatelessWidget {
  const _DraftHeader({
    required this.when,
    required this.place,
    required this.onBack,
  });

  final String when;
  final String place;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIconButton(
          icon: Icons.chevron_left_rounded,
          size: kUtilityButtonSize,
          onPhoto: false,
          semanticLabel: 'Back',
          onTap: onBack ?? () {},
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                when,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: kTextFontFamily,
                  fontSize: kFontSizeBody,
                  fontWeight: FontWeight.w600,
                  color: kAccentCream,
                ),
              ),
              Text(
                place,
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.subtitle, required this.onSkip});

  final String subtitle;
  final VoidCallback? onSkip;

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
            subtitle,
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
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            minimumSize: const Size(kUtilityButtonSize, kUtilityButtonSize),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            foregroundColor: kCreamSecondary,
            textStyle: const TextStyle(
              fontFamily: kTextFontFamily,
              fontSize: kFontSizeSmall,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Skip'),
        ),
      ],
    );
  }
}

/// The design's `.recent` — faces you can tap, sideways.
class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.people,
    required this.selected,
    required this.onToggle,
  });

  final List<FriendProfile> people;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final person in people) ...[
            _RecentChip(
              profile: person,
              selected: selected.contains(person.id),
              onTap: () => onToggle(person.id),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final FriendProfile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: profile.name,
      button: true,
      selected: selected,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusThumb),
        onTap: onTap,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  FriendAvatar(profile: profile, size: kAvatarSizeRow),
                  if (selected)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: kAccentEmber,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 11,
                          color: kOnAccent,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                firstName(profile.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kTextFontFamily,
                  fontSize: kFontSizeMicro,
                  color: selected ? kAccentCream : kCreamSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The design's `.search`. A real field rather than the prototype's static
/// pill, because a list of friends is only searchable if it can be typed into.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kSearchBarHeight),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          fontFamily: kTextFontFamily,
          fontSize: kFontSizeBody,
          color: kTextOnPhoto,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(
            fontFamily: kTextFontFamily,
            fontSize: kFontSizeBody,
            color: kCreamSecondary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 18,
            color: kCreamSecondary,
          ),
          filled: true,
          fillColor: kSurfaceDark,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.searching, required this.loading});

  final bool searching;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Text(
          searching
              ? 'Nobody by that name.'
              : 'Nobody here yet. Add friends from the You tab and they will '
                  'show up on this screen.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: kTextFontFamily,
            fontSize: kFontSizeSmall,
            color: kCreamSecondary,
          ),
        ),
      ),
    );
  }
}

/// `.sheet-foot` — the faces, the count, and the button that makes the plan.
///
/// "Lock it in" is live with nobody ticked: a table for one is a plan, and the
/// step-one sheet has a "Just me" button that means exactly this.
class _DraftFoot extends StatelessWidget {
  const _DraftFoot({
    required this.people,
    required this.count,
    required this.vote,
    required this.sending,
    required this.onLockIn,
  });

  final List<FriendProfile> people;
  final int count;
  final bool vote;
  final bool sending;
  final VoidCallback? onLockIn;

  @override
  Widget build(BuildContext context) {
    final line = vote ? '$count going · they vote on time' : '$count going';
    final counter = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (people.isNotEmpty) ...[
          FriendAvatarStack(people: people),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            line,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: kTextFontFamily,
              fontSize: kFontSizeSmall,
              color: kCreamSecondary,
            ),
          ),
        ),
      ],
    );

    final button = AppPrimaryButton(
      label: 'Lock it in',
      busy: sending,
      onPressed: onLockIn,
      expand: true,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kInviteFootStackWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              counter,
              const SizedBox(height: AppSpacing.xs),
              button,
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: counter),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: kInviteButtonMaxWidth),
                child: button,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// `.invite-foot` — the running count and the one button, on a plan that is
/// already made.
///
/// Stacks below [kInviteFootStackWidth] for the same reason the plan screen's
/// picked bar does: a pill that will not shrink beside a figure that grows
/// with the text scale.
class _InviteFoot extends StatelessWidget {
  const _InviteFoot({
    required this.count,
    required this.sending,
    required this.onSend,
  });

  final int count;
  final bool sending;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final counter = Semantics(
      label: selectedCountLabel(count),
      liveRegion: true,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              fontFamily: kDisplayFontFamily,
              fontSize: kInviteCountFontSize,
              fontWeight: FontWeight.w700,
              color: kAccentCream,
            ),
          ),
          const Text(
            'selected',
            style: TextStyle(
              fontFamily: kTextFontFamily,
              fontSize: kFontSizeSmall,
              color: kCreamSecondary,
            ),
          ),
        ],
      ),
    );

    final button = AppPrimaryButton(
      label: 'Send invites',
      busy: sending,
      onPressed: onSend,
      expand: true,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kInviteFootStackWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              counter,
              const SizedBox(height: AppSpacing.xs),
              button,
            ],
          );
        }
        // `justify-content:space-between` with the design's own cap on the
        // button. `Flexible` rather than `Expanded`: an expanded child gets a
        // tight width, which would make the cap inert.
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            counter,
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: kInviteButtonMaxWidth),
                child: button,
              ),
            ),
          ],
        );
      },
    );
  }
}
