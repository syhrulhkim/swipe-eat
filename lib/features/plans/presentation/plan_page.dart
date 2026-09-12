import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../friends/domain/friend_captions.dart';
import '../../friends/domain/vote_tally.dart';
import '../../friends/presentation/person_row.dart';
import '../../friends/state/friends_controller.dart';
import '../../profile/presentation/preference_controls.dart';
import '../domain/plan_labels.dart';
import '../models/plan.dart';
import '../models/plan_slot.dart';
import '../state/plans_controller.dart';

/// One plan: who is coming, when everybody wants to go, and — if it is yours —
/// the button that settles it (D133).
///
/// The design has no screen for this. It has "they'll get a vote on the time"
/// written on a switch (S4) and nowhere for that vote to be cast, so this is
/// the smallest surface that makes the promise true: the same five chips the
/// plan was made with, carrying counts, plus the roster the calendar card only
/// has room to draw as faces.
class PlanPage extends StatefulWidget {
  const PlanPage({
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
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  late final FriendsController _friends =
      widget.friends ?? FriendsController.instance;
  late final PlansController _plans = widget.plans ?? PlansController.instance;

  bool _busy = false;

  /// A push can land on a plan the calendar has never read — an invite sent
  /// while the app was closed, or a plan of somebody else's I have just been
  /// let into. One re-read, guarded, because "not on your calendar" is also
  /// the honest answer for a plan from last month and a retry loop would
  /// hammer the server over it.
  bool _refetched = false;

  @override
  void initState() {
    super.initState();
    _plans.ensureLoaded();
    _friends.ensureLoaded();
    // Neither of these needs the plan itself, only its id, so they start
    // before the calendar has answered rather than after.
    _friends.loadPlanPeople([widget.planId]);
    _friends.loadVotes(widget.planId);
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
              builder: (context, _) => _body(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final plan = _plans.planById(widget.planId);
    if (plan == null && _plans.isLoaded && !_refetched) {
      _refetched = true;
      unawaited(_plans.refresh());
    }
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
          _TopBar(
            subtitle: plan == null
                ? 'Your plan'
                : pickedSummary(plan.date, plan.timeText),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: plan == null
                ? _Missing(
                    loading: _plans.loading && !_plans.isLoaded,
                    waitingOn: _waitingOn(),
                  )
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    children: _sections(context, plan),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _sections(BuildContext context, Plan plan) {
    final votes = _friends.votesFor(plan.id);
    final counts = slotVoteCounts(votes);
    final mine = voteSlotOf(votes, _friends.myUserId);
    final leading = leadingSlot(votes);
    final people = _friends.peopleFor(plan.id);
    // The owner is not a `plan_members` row (D107), so they are counted in by
    // hand — and their absence from the roster is also how this screen knows
    // which of the two footers to draw. Everybody else is counted the way the
    // plan card counts them: somebody who said no is not at the dinner, and
    // waiting on their vote would leave the line up forever.
    final outstanding = votesOutstandingLine(
      voted: votes.length,
      asked: planHeadcount([for (final person in people) person.status]).guests + 1,
    );
    final myMembership = _myMembership(plan);
    final requests = [
      for (final person in people)
        if (person.status == 'requested') person,
    ];

    return [
      _RestaurantLink(plan: plan),
      const SizedBox(height: AppSpacing.lg),
      Text('When are we going?', style: appTitleStyle(context)),
      const SizedBox(height: AppSpacing.md),
      _VoteChips(
        counts: counts,
        chosen: mine,
        onVote: _busy ? null : _vote,
      ),
      const SizedBox(height: AppSpacing.sm),
      _Note(
        leading == null
            ? 'Nobody has picked a time yet.'
            : '${leading.label} has the most votes.',
      ),
      if (outstanding != null) _Note(outstanding),
      const SizedBox(height: AppSpacing.lg),
      if (myMembership == null)
        _LockRow(
          leading: leading,
          current: PlanSlot.forStored(
            hour: plan.hour,
            minute: plan.minute,
            timeLabel: plan.timeLabel,
          ),
          onLock: _busy ? null : _lock,
        )
      else
        _AnswerRow(
          status: myMembership.status,
          onAnswer: _busy ? null : _answer,
        ),
      if (requests.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        Text('Requests', style: appTitleStyle(context)),
        const SizedBox(height: AppSpacing.sm),
        for (final person in requests) ...[
          PersonRow(
            key: ValueKey('request-${person.profile.id}'),
            profile: person.profile,
            selected: false,
            subtitle: planStatusLabel(person.status),
            onTap: () {},
          ),
          _AnswerRow(
            status: person.status,
            yes: 'Accept',
            no: 'Decline',
            onAnswer: _busy
                ? null
                : (accept) => _answerRequest(person.profile.id, accept),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
      const SizedBox(height: AppSpacing.lg),
      Text('Who’s coming', style: appTitleStyle(context)),
      const SizedBox(height: AppSpacing.sm),
      if (people.length == requests.length)
        const _Note('Just you so far.')
      else
        for (final person in people)
          if (person.status != 'requested')
            PersonRow(
              key: ValueKey(person.profile.id),
              profile: person.profile,
              selected: false,
              subtitle: planStatusLabel(person.status),
              onTap: () {},
            ),
      // The owner's two controls sit under the roster, not over it: who is
      // coming is what the screen is for, and both of these are answers to
      // "and who else?".
      if (myMembership == null) ...[
        const SizedBox(height: AppSpacing.lg),
        PrefSwitchRow(
          title: 'Share with friends',
          subtitle: 'They can see it on their calendar and ask to join',
          value: plan.sharedWithFriends,
          onChanged: _busy ? (_) {} : (value) => _share(value),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSecondaryButton(
          label: 'Invite friends',
          expand: true,
          onPressed: _busy
              ? null
              : () => context.push('/plans/${widget.planId}/invite'),
        ),
      ],
    ];
  }

  /// My own row on this plan, or null when I own it.
  ///
  /// RLS only ever hands this screen a plan I own or belong to, so "not a
  /// member" and "owner" are the same answer — and the plan row carries the
  /// membership ids already, which saves asking who the owner is.
  PlanMember? _myMembership(Plan plan) {
    final me = _friends.myUserId;
    if (me == null) {
      return null;
    }
    for (final member in plan.members) {
      if (member.userId == me) {
        return member;
      }
    }
    return null;
  }

  Future<void> _vote(PlanSlot slot) => _run(
        () => _friends.vote(
          widget.planId,
          time: slot.wireTime,
          timeLabel: slot.wireLabel,
        ),
        'Could not save that vote.',
      );

  Future<void> _lock(PlanSlot slot) => _run(
        () async {
          await _plans.setTime(
            widget.planId,
            time: slot.wireTime,
            timeLabel: slot.wireLabel,
          );
        },
        'Could not lock that time in.',
      );

  /// Whose plan I am waiting on, or null when this plan is not one I asked to
  /// join.
  ///
  /// A request is not a membership (D153), so the plan itself is invisible to
  /// me until the owner says yes — the only thing I can see is the row the
  /// Calendar's Friends section reads, which carries the owner's name.
  String? _waitingOn() {
    for (final plan in _plans.friendsPlans) {
      if (plan.id == widget.planId && plan.asked) {
        return firstName(plan.owner.name);
      }
    }
    return null;
  }

  Future<void> _share(bool shared) => _run(
        () => _plans.setShared(widget.planId, shared),
        'Could not change who can see this.',
      );

  Future<void> _answerRequest(String userId, bool accept) => _run(
        () => _friends.answerJoinRequest(
          widget.planId,
          userId,
          accept: accept,
        ),
        'Could not answer that request.',
      );

  Future<void> _answer(bool going) => _run(
        () => _friends.answerInvite(widget.planId, going: going),
        'Could not send that answer.',
      );

  /// One place for "disable the screen, do the write, say so if it fails".
  Future<void> _run(Future<void> Function() write, String message) async {
    setState(() => _busy = true);
    try {
      await write();
    } on Object catch (error) {
      debugPrint('$message ($error)');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.subtitle});

  final String subtitle;

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
        const SizedBox(width: kUtilityButtonSize),
      ],
    );
  }
}

/// The place, and the way back to it. The calendar card used to open the
/// restaurant directly; this screen took that tap, so it has to give it back.
class _RestaurantLink extends StatelessWidget {
  const _RestaurantLink({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final where = [plan.tag, plan.neighbourhood]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(' · ');

    return Semantics(
      label: 'Open ${plan.restaurantName}',
      button: true,
      excludeSemantics: true,
      onTap: () => context.push('/restaurant/${plan.restaurantId}'),
      child: InkWell(
        onTap: () => context.push('/restaurant/${plan.restaurantId}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.restaurantName, style: appTitleStyle(context)),
                    if (where.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(where, style: _noteStyle),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: kCreamSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The five chips, each carrying its own tally.
class _VoteChips extends StatelessWidget {
  const _VoteChips({
    required this.counts,
    required this.chosen,
    required this.onVote,
  });

  final List<int> counts;
  final PlanSlot? chosen;
  final ValueChanged<PlanSlot>? onVote;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (var index = 0; index < PlanSlot.all.length; index++)
          // Same reason as `_SlotRow` on the pick-a-date screen: a Wrap hands
          // each child the whole line, and IntrinsicWidth gives the pill its
          // own width back.
          IntrinsicWidth(
            child: AppFilterChip(
              label: slotChipLabel(PlanSlot.all[index], counts[index]),
              semanticLabel: slotChipSemanticLabel(
                PlanSlot.all[index],
                counts[index],
              ),
              selected: identical(PlanSlot.all[index], chosen),
              onTap: onVote == null ? () {} : () => onVote!(PlanSlot.all[index]),
            ),
          ),
      ],
    );
  }
}

/// The owner's half of the footer. Locking copies the winning slot onto the
/// plan, which is the whole of "settling it" — there is no separate state.
class _LockRow extends StatelessWidget {
  const _LockRow({
    required this.leading,
    required this.current,
    required this.onLock,
  });

  final PlanSlot? leading;
  final PlanSlot? current;
  final ValueChanged<PlanSlot>? onLock;

  @override
  Widget build(BuildContext context) {
    final winner = leading;
    if (winner == null || identical(winner, current)) {
      // Nothing to settle: either nobody has voted, the vote is tied, or the
      // plan is already at the winning time. A button that did nothing would
      // still look like it was waiting to be pressed.
      return const SizedBox.shrink();
    }

    return AppPrimaryButton(
      label: 'Move it to ${winner.label}',
      expand: true,
      onPressed: onLock == null ? null : () => onLock!(winner),
    );
  }
}

/// A guest's half: the two answers, with the one already given held down.
class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
    required this.status,
    required this.onAnswer,
    this.yes = 'Going',
    this.no = "Can't",
  });

  final String status;
  final ValueChanged<bool>? onAnswer;

  /// The owner answering a join request is the same two buttons with the same
  /// two meanings, said the other way round: Accept / Decline.
  final String yes;
  final String no;

  @override
  Widget build(BuildContext context) {
    final going = status == 'going';
    final declined = status == 'declined';

    return Row(
      children: [
        Expanded(
          child: going
              ? AppPrimaryButton(
                  label: yes,
                  expand: true,
                  onPressed: null,
                )
              : AppSecondaryButton(
                  label: yes,
                  expand: true,
                  onPressed: onAnswer == null ? null : () => onAnswer!(true),
                ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AppSecondaryButton(
            label: no,
            expand: true,
            tint: declined ? kAccentEmber : null,
            onPressed: onAnswer == null ? null : () => onAnswer!(false),
          ),
        ),
      ],
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.loading, this.waitingOn});

  final bool loading;

  /// The owner's first name when I have asked to join this plan and nobody
  /// has answered yet — the plan is invisible to me until they do.
  final String? waitingOn;

  @override
  Widget build(BuildContext context) {
    final owner = waitingOn;

    return Center(
      child: Text(
        owner != null
            ? 'Waiting on $owner.'
            : loading
                ? 'Finding that plan…'
                : 'That plan is not on your calendar.',
        textAlign: TextAlign.center,
        style: _noteStyle,
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(text, style: _noteStyle),
    );
  }
}

const TextStyle _noteStyle = TextStyle(
  fontFamily: kTextFontFamily,
  fontSize: kFontSizeSmall,
  color: kCreamSecondary,
);
