import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../plans/domain/plan_labels.dart';
import '../../plans/models/plan.dart';
import '../../plans/state/plans_controller.dart';
import '../domain/friend_captions.dart';
import '../domain/invite_ordering.dart';
import '../models/friend.dart';
import '../state/friends_controller.dart';
import 'person_row.dart';

/// S5 · Invite friends. A search, two lists of people and a count.
///
/// Pushed after a plan is saved, never before: everything on this screen is
/// optional, and a plan that only existed once its guest list did would be
/// lost every time somebody backed out of the guest list.
///
/// Which is also why the topbar carries Skip rather than only Back — Back
/// suggests the plan is not made yet, and it is.
class InvitePage extends StatefulWidget {
  const InvitePage({
    super.key,
    required this.planId,
    this.friends,
    this.plans,
  });

  final int planId;

  /// Injected by tests; in the app the shared instances are used.
  final FriendsController? friends;
  final PlansController? plans;

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  late final FriendsController _friends =
      widget.friends ?? FriendsController.instance;
  late final PlansController _plans = widget.plans ?? PlansController.instance;

  final Set<String> _selected = {};
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
    final plan = _planOrNull();
    final sections = _sections();
    final total = sections.fold<int>(0, (sum, s) => sum + s.people.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TopBar(
          subtitle: plan == null
              ? 'Your plan'
              : pickedSummary(plan.date, plan.timeText),
          onSkip: _sending ? null : () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(height: 8),
        Text("Who's hungry?", style: appTitleStyle(context)),
        const SizedBox(height: AppSpacing.md),
        _SearchField(onChanged: (value) => setState(() => _query = value)),
        Expanded(
          child: total == 0
              ? _EmptyList(
                  searching: _query.trim().isNotEmpty,
                  loading: _friends.loading && !_friends.isLoaded,
                )
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 8),
                  children: [
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

  Plan? _planOrNull() {
    for (final plan in _plans.plans) {
      if (plan.id == widget.planId) {
        return plan;
      }
    }
    return null;
  }

  /// The list, split the way the design draws it.
  ///
  /// Searching collapses both sections into one unheaded list: a heading over
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

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await _friends.invite(widget.planId, _selected);
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

/// The design's `.search`. A real field rather than the prototype's static
/// pill, because a list of friends is only searchable if it can be typed into.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

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
          hintText: 'Search friends',
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

/// `.invite-foot` — the running count and the one button.
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
