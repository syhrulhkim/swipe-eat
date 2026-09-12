import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/location/user_position_state.dart';
import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../dashboard/state/dashboard_tab_request.dart';
import '../../friends/domain/friend_captions.dart';
import '../../friends/models/friend.dart';
import '../../friends/presentation/friend_avatar.dart';
import '../../friends/state/friends_controller.dart';
import '../domain/plan_labels.dart';
import '../models/plan_slot.dart';
import 'plan_date_page.dart';

/// S5b · It's a plan. The receipt for what step two just saved.
///
/// It is handed everything it draws rather than reading the plan back: the
/// calendar refresh that follows a create has already happened by the time
/// this is pushed, and a screen that re-queried would show a spinner where the
/// answer already is.
class PlanConfirmedPage extends StatefulWidget {
  const PlanConfirmedPage({
    super.key,
    required this.planId,
    required this.draft,
    required this.date,
    required this.slot,
    required this.vote,
    required this.invited,
    this.friends,
    this.onExit,
    this.onShare,
  });

  final int planId;
  final PlanDraft draft;
  final DateTime date;
  final PlanSlot slot;

  /// Whether the guests get a vote on the time — the ticket's TIME field says
  /// so when they do.
  final bool vote;

  /// Who was asked. Empty for a table for one.
  final Set<String> invited;

  /// Injected by tests; in the app the shared instance is used.
  final FriendsController? friends;

  /// Where the two buttons go, by dashboard tab index. Injected so a test can
  /// watch them without driving a router.
  final ValueChanged<int>? onExit;

  /// Injected by tests; `share_plus` is a platform channel and `flutter test`
  /// has no host to answer it.
  final Future<void> Function(String text)? onShare;

  @override
  State<PlanConfirmedPage> createState() => _PlanConfirmedPageState();
}

class _PlanConfirmedPageState extends State<PlanConfirmedPage>
    with UserPositionState<PlanConfirmedPage> {
  late final FriendsController _friends =
      widget.friends ?? FriendsController.instance;

  @override
  void initState() {
    super.initState();
    loadUserPosition();
    if (widget.invited.isNotEmpty) {
      // The roster is what turns "You + 3" into "1 confirmed"; nobody has
      // answered yet, but the read is what makes the dots true a moment later.
      unawaited(_friends.loadPlanPeople([widget.planId]));
    }
  }

  @override
  Widget build(BuildContext context) {
    // No way back: the two sheets that made this plan are still on the stack
    // below, and returning to them would offer to make it a second time. The
    // design gives this screen an X and two exits and no back arrow.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: kBackgroundDark,
        body: Stack(
          children: [
            const ScreenGlow(),
            SafeArea(
              child: AnimatedBuilder(
                animation: _friends,
                builder: (context, _) => _body(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final people = _friends.peopleFor(widget.planId);
    final faces = people.isEmpty
        ? [
            for (final id in widget.invited)
              if (_friends.profileFor(id) != null) _friends.profileFor(id)!,
          ]
        : [for (final person in people) person.profile];
    final head = planHeadcount([for (final person in people) person.status]);
    final going = people.isEmpty ? widget.invited.length : head.guests;

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
          Align(
            alignment: Alignment.centerRight,
            child: AppIconButton(
              icon: Icons.close_rounded,
              size: kUtilityButtonSize,
              onPhoto: false,
              semanticLabel: 'Close',
              onTap: () => _exit(context, 3),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text("It's a plan.", style: appTitleStyle(context)),
                  if (widget.invited.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      "Invites sent. You'll get a nudge when everyone's in.",
                      style: TextStyle(
                        fontFamily: kTextFontFamily,
                        fontSize: kFontSizeBody,
                        color: kCreamSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _Ticket(
                    draft: widget.draft,
                    date: widget.date,
                    slot: widget.slot,
                    vote: widget.vote,
                    distance: widget.draft.distanceFrom(userPosition),
                    faces: faces,
                    going: going,
                    confirmed: head.confirmed,
                  ),
                  const SizedBox(height: 16),
                  _Actions(onShare: () => unawaited(_share())),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          AppPrimaryButton(
            label: 'See it on your calendar',
            expand: true,
            onPressed: () => _exit(context, 3),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppSecondaryButton(
            label: 'Keep swiping',
            expand: true,
            onPressed: () => _exit(context, 0),
          ),
        ],
      ),
    );
  }

  /// The old `onCreated` chain, now owned by the screen that ends the flow:
  /// replace the stack with the dashboard, then ask it for a tab. `go` rather
  /// than a pop, so the two sheets behind this one do not come back.
  void _exit(BuildContext context, int tab) {
    final onExit = widget.onExit;
    if (onExit != null) {
      onExit(tab);
      return;
    }
    context.go('/dashboard');
    DashboardTabRequest.instance.show(tab);
  }

  /// No link: a plan has no public URL, so what goes out is the plan in words.
  Future<void> _share() async {
    final text = 'Ngap at ${widget.draft.title} — '
        '${weekdayShort(widget.date)} ${widget.date.day} '
        '${shortMonth(widget.date)} · ${planSummaryTime(widget.slot)}';
    final share = widget.onShare ?? _shareWithOs;
    try {
      await share(text);
    } on Object catch (error) {
      debugPrint('Sharing a plan failed: $error');
    }
  }

  Future<void> _shareWithOs(String text) =>
      SharePlus.instance.share(ShareParams(text: text));
}

/// `.ticket` — the cover, the name, and the three things to know.
class _Ticket extends StatelessWidget {
  const _Ticket({
    required this.draft,
    required this.date,
    required this.slot,
    required this.vote,
    required this.distance,
    required this.faces,
    required this.going,
    required this.confirmed,
  });

  final PlanDraft draft;
  final DateTime date;
  final PlanSlot slot;
  final bool vote;
  final String? distance;
  final List<FriendProfile> faces;
  final int going;
  final int confirmed;

  @override
  Widget build(BuildContext context) {
    final cover = draft.coverUrl;

    return Container(
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(kRadiusPanel),
        border: Border.all(color: kHairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cover != null && cover.isNotEmpty)
            SizedBox(
              height: 120,
              width: double.infinity,
              child: Image.network(
                cover,
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: appPanelTitleStyle(context),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 10,
                  children: [
                    _Field(
                      label: 'DATE',
                      value: '${weekdayShort(date)} ${date.day} '
                          '${shortMonth(date)}',
                    ),
                    _Field(
                      label: vote ? 'TIME · VOTING' : 'TIME',
                      value: planSummaryTime(slot),
                    ),
                    // Hidden rather than guessed: no fix, or a restaurant with
                    // no coordinates, has no distance to state.
                    if (distance != null)
                      _Field(label: 'FROM YOU', value: distance!),
                  ],
                ),
                if (going > 0) ...[
                  const SizedBox(height: 14),
                  _PeopleRow(
                    faces: faces,
                    going: going,
                    confirmed: confirmed,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: kTextFontFamily,
            fontSize: kFontSizeMicro,
            letterSpacing: 0.6,
            color: kCreamMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: kTextFontFamily,
            fontSize: kFontSizeBody,
            fontWeight: FontWeight.w600,
            color: kAccentCream,
          ),
        ),
      ],
    );
  }
}

/// `.ticket .row` — the faces, the count, and one dot per guest.
class _PeopleRow extends StatelessWidget {
  const _PeopleRow({
    required this.faces,
    required this.going,
    required this.confirmed,
  });

  final List<FriendProfile> faces;
  final int going;
  final int confirmed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (faces.isNotEmpty) FriendAvatarStack(people: faces),
        Text(
          'You + $going · $confirmed confirmed',
          style: const TextStyle(
            fontFamily: kTextFontFamily,
            fontSize: kFontSizeSmall,
            color: kCreamSecondary,
          ),
        ),
        Semantics(
          label: '$confirmed of $going confirmed',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < going; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    width: kSpicePipSize,
                    height: kSpicePipSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < confirmed ? kFresh : kHairline,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// `.acts` — one action, because one is all the app can do.
///
/// "Add to calendar" and "Remind me" are drawn in the design and omitted here:
/// there is no calendar-integration or local-notification package in the
/// project, and a button that did nothing would be worse than no button.
class _Actions extends StatelessWidget {
  const _Actions({required this.onShare});

  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: AppSecondaryButton(
        label: 'Share link',
        icon: Icons.ios_share_rounded,
        onPressed: onShare,
      ),
    );
  }
}
