import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_config.dart';
import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../dashboard/presentation/dashboard_widgets.dart';
import '../../dashboard/state/dashboard_tab_request.dart';
import '../../plans/domain/plan_labels.dart';
import '../../plans/models/plan.dart';
import '../../plans/state/plans_controller.dart';
import '../data/contacts_reader.dart';
import '../data/friends_repository.dart';
import '../models/friend.dart';
import '../state/friends_controller.dart';
import 'find_friends_sheet.dart';
import 'person_row.dart';

/// S11 · Friends. Where the You tab's "Friends · 38" goes.
///
/// The design's shape, top to bottom: a titled bar with a way back and a way
/// to add somebody, a search, one row of single-select chips, then `.sepk`
/// headings over the three lists — requests, the friends you are eating with
/// this week, and everybody.
///
/// Every row here is `PersonRow` with something in its `trailing` slot, which
/// is the slot that widget was given for exactly this screen. A row with
/// buttons on it is not itself a button, so none of these rows tap.
class FriendsPage extends StatefulWidget {
  const FriendsPage({
    super.key,
    this.friends,
    this.plans,
    this.readContacts,
    this.onShare,
    this.tabRequests,
  });

  /// Injected by tests; in the app the shared instance is used.
  final FriendsController? friends;

  /// The calendar "Eating this week" is read out of. Injected by tests; in the
  /// app the one shared instance every other screen reads.
  final PlansController? plans;

  /// How the find-friends sheet reads the address book (D145). Injected for
  /// the same reason it is in onboarding: `flutter test` has no permission
  /// sheet to answer (D60).
  final ContactsReader? readContacts;

  /// Hands the invite to the OS share sheet. Constructor-injected with a
  /// default for the same reason the wishlist does it: `share_plus` is a
  /// platform channel and `flutter test` has no implementation for one.
  final Future<void> Function(String text)? onShare;

  /// How a row's calendar button asks for the Swipe tab. Injected by tests.
  final DashboardTabRequest? tabRequests;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  late final FriendsController _friends =
      widget.friends ?? FriendsController.instance;
  late final PlansController _plans = widget.plans ?? PlansController.instance;
  late final DashboardTabRequest _tabs =
      widget.tabRequests ?? DashboardTabRequest.instance;

  /// The people whose Accept, Decline or Remove is still in flight. Keyed by
  /// id rather than a single bool: two requests can be answered in the time
  /// one round trip takes, and a page-wide flag would grey out the second.
  final Set<String> _busy = {};

  String _query = '';

  /// The design's `[data-filters]` chips, which are single-select.
  bool _onlyThisWeek = false;

  @override
  void initState() {
    super.initState();
    unawaited(_friends.ensureLoaded());
    // The plans are a nicety on this screen — they only decide whether a name
    // also appears under "Eating this week" — so a failure stays quiet.
    unawaited(_plans.ensureLoaded().catchError((Object error) {
      debugPrint('Friends page plans load failed: $error');
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const ScreenGlow(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                12,
                AppSpacing.screenPadding,
                12,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                'Friends · ${_friends.count}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appPanelTitleStyle(context),
              ),
            ),
            // Onboarding tells a user who matched nobody that they can add
            // friends later from the You tab. This is later (D145).
            AppIconButton(
              icon: Icons.person_add_alt_1_rounded,
              size: kUtilityButtonSize,
              onPhoto: false,
              semanticLabel: 'Add friend',
              onTap: () => unawaited(showFindFriendsSheet(
                context,
                friends: _friends,
                readContacts: widget.readContacts,
              )),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _SearchField(onChanged: (value) => setState(() => _query = value)),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              AppFilterChip(
                label: 'All',
                selected: !_onlyThisWeek,
                onTap: () => setState(() => _onlyThisWeek = false),
              ),
              const SizedBox(width: 8),
              AppFilterChip(
                label: 'Eating this week',
                selected: _onlyThisWeek,
                onTap: () => setState(() => _onlyThisWeek = true),
              ),
            ],
          ),
        ),
        Expanded(child: _list(context)),
        AppSecondaryButton(
          label: 'Invite friends with a link',
          expand: true,
          onPressed: () => unawaited(_invite()),
        ),
      ],
    );
  }

  bool _matches(String name) {
    final needle = _query.trim().toLowerCase();
    return needle.isEmpty || name.toLowerCase().contains(needle);
  }

  /// Friends who share a plan with you in the next seven days, each with the
  /// soonest of those plans.
  ///
  /// `upcoming` is already sorted soonest first, so the first plan a person
  /// turns up on is the one their row talks about. Somebody who said no is not
  /// eating with you and does not count.
  ///
  /// `friendsPlans` is deliberately not read here: `get_friends_plans` returns
  /// only the shared evenings you are **not** on (D153), which is the opposite
  /// of what this section says.
  ///
  // ponytail: a plan a friend owns and invited you to names its other guests
  // but not the host — `Plan` carries no owner id and the owner has no
  // `plan_members` row. `FriendsController.loadPlanPeople` would fill it in at
  // the cost of one more RPC per page opening; do that if hosts start going
  // missing from this list.
  List<(FriendProfile, Plan)> _eatingThisWeek() {
    final now = _plans.now;
    final until = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 7));

    final soonest = <String, Plan>{};
    for (final plan in _plans.upcoming) {
      if (!plan.date.isBefore(until)) {
        continue;
      }
      for (final member in plan.members) {
        if (member.status == 'declined') {
          continue;
        }
        soonest.putIfAbsent(member.userId, () => plan);
      }
    }

    return [
      for (final friend in _friends.friends)
        if (soonest[friend.id] != null) (friend, soonest[friend.id]!),
    ];
  }

  Widget _list(BuildContext context) {
    final error = _friends.error;
    if (error != null && !_friends.isLoaded) {
      return ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          EmptyTabMessage(
            title: 'Something went wrong',
            subtitle: error,
            actionLabel: 'Try again',
            onAction: () => unawaited(_friends.refresh()),
          ),
        ],
      );
    }

    if (!_friends.isLoaded && _friends.loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final incoming = _friends.incomingRequests;
    final outgoing = _friends.outgoingRequests;
    final friends = _friends.friends;

    if (incoming.isEmpty && outgoing.isEmpty && friends.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            // Not "when somebody in your contacts joins": nothing re-scans
            // the address book on its own, then or now. Since D145 there is
            // a third way a name lands here — the add-friend button above,
            // which checks contacts when the user asks it to — so the
            // sentence says that instead of implying names arrive by
            // themselves.
            'Nobody yet. Add somebody with the button above, or wait for a '
            'request to come in.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kTextFontFamily,
              fontSize: kFontSizeSmall,
              color: kCreamSecondary,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    final shownIncoming =
        _onlyThisWeek ? const <FriendRequest>[] : [
            for (final r in incoming) if (_matches(r.profile.name)) r,
          ];
    final thisWeek = [
      for (final pair in _eatingThisWeek())
        if (_matches(pair.$1.name)) pair,
    ];
    final shownFriends =
        _onlyThisWeek ? const <FriendProfile>[] : [
            for (final f in friends) if (_matches(f.name)) f,
          ];
    final shownOutgoing =
        _onlyThisWeek ? const <FriendRequest>[] : [
            for (final r in outgoing) if (_matches(r.profile.name)) r,
          ];

    if (shownIncoming.isEmpty &&
        thisWeek.isEmpty &&
        shownFriends.isEmpty &&
        shownOutgoing.isEmpty) {
      return const Center(
        child: Text(
          'Nobody here.',
          style: TextStyle(
            fontFamily: kTextFontFamily,
            fontSize: kFontSizeSmall,
            color: kCreamSecondary,
          ),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      children: [
        if (shownIncoming.isNotEmpty) ...[
          // The unfiltered count, like the title's: the heading says how many
          // requests there are, not how many the search left.
          _Heading('Requests · ${incoming.length}'),
          for (final request in shownIncoming)
            PersonRow(
              key: ValueKey('in:${request.profile.id}'),
              profile: request.profile,
              selected: false,
              onTap: () {},
              trailing: _TrailingPair(
                // Accept goes first: it is the answer most requests get.
                first: _RowAction(
                  label: 'Accept',
                  semanticLabel: 'Accept ${request.profile.name}',
                  tint: kAccentEmber,
                  busy: _busy.contains(request.profile.id),
                  onPressed: () => unawaited(
                    _act(request.profile.id, FriendAction.accept),
                  ),
                ),
                second: _RowAction(
                  label: 'Decline',
                  semanticLabel: 'Decline ${request.profile.name}',
                  busy: _busy.contains(request.profile.id),
                  onPressed: () => unawaited(
                    _act(request.profile.id, FriendAction.decline),
                  ),
                ),
              ),
            ),
        ],
        if (thisWeek.isNotEmpty) ...[
          const _Heading('Eating this week'),
          for (final (friend, plan) in thisWeek)
            PersonRow(
              key: ValueKey('week:${friend.id}'),
              profile: friend,
              selected: false,
              onTap: () {},
              // "Fri 18 · Warung Kak Ros with you". Every plan on this list is
              // one of yours, so "with you" is true of all of them.
              subtitle: '${plannedLabel(plan, _plans.now)} · '
                  '${plan.restaurantName} with you',
              trailing: _PlanButton(name: friend.name, onPressed: _goToSwipe),
            ),
        ],
        if (shownFriends.isNotEmpty || shownOutgoing.isNotEmpty) ...[
          const _Heading('Everyone'),
          for (final friend in shownFriends)
            PersonRow(
              key: ValueKey('friend:${friend.id}'),
              profile: friend,
              selected: false,
              onTap: () {},
              trailing: _TrailingPair(
                first: _RowAction(
                  label: 'Remove',
                  semanticLabel: 'Remove ${friend.name}',
                  busy: _busy.contains(friend.id),
                  onPressed: () => unawaited(_confirmRemove(friend)),
                ),
                second: _PlanButton(name: friend.name, onPressed: _goToSwipe),
              ),
            ),
          // The design has no section for a request you sent, and losing the
          // only way to cancel one would be worse than following it. They sit
          // at the foot of Everyone, still saying "Asked", with no calendar
          // button because there is nothing to plan with somebody who has not
          // said yes.
          for (final request in shownOutgoing)
            PersonRow(
              key: ValueKey('out:${request.profile.id}'),
              profile: request.profile,
              selected: false,
              onTap: () {},
              subtitle: 'Asked',
              trailing: _RowAction(
                label: 'Cancel',
                semanticLabel: 'Cancel the request to ${request.profile.name}',
                busy: _busy.contains(request.profile.id),
                // The same `decline` the other side would send: the row is a
                // pending friendship either way and deleting it is the whole
                // of both actions.
                onPressed: () => unawaited(
                  _act(request.profile.id, FriendAction.decline),
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// The mockup's `data-go="swipe"` — the deck is where a plan starts.
  void _goToSwipe() {
    _tabs.show(0);
    unawaited(Navigator.of(context).maybePop());
  }

  /// There is no invite-link service, so the share carries no URL rather than
  /// a made-up one that would 404. The sentence is the honest half of the
  /// button's promise; a real link replaces the text the day there is one.
  Future<void> _invite() async {
    final share = widget.onShare ?? _shareWithOs;
    try {
      await share('Come and eat with me on ${AppConfig.appName}.');
    } on Object catch (error) {
      debugPrint('Sharing an invite failed: $error');
    }
  }

  Future<void> _shareWithOs(String text) {
    return SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _confirmRemove(FriendProfile friend) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: kSurfaceDark,
      // A default sheet is capped at nine sixteenths of the screen and cannot
      // scroll. Two sentences and two pills fit that on a phone at the normal
      // text size and do not fit it on a 320 px screen at twice the text size,
      // where they want about 260 px more than the cap allows. Scroll
      // controlled plus a scroll view means the cap is the whole screen and
      // whatever still does not fit can be reached rather than clipped.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Remove ${friend.name}?',
                style: appPanelTitleStyle(sheetContext),
              ),
              const SizedBox(height: 6),
              Text(
                'They stop showing up when you invite people to a plan. '
                'Either of you can ask again.',
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
                      label: 'Keep them',
                      expand: true,
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppSecondaryButton(
                      label: 'Remove',
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
    await _act(friend.id, FriendAction.remove);
  }

  /// Every answer button on this page ends here: the RPC takes one action word
  /// and the page's only job is to say when it did not work.
  Future<void> _act(String userId, FriendAction action) async {
    if (_busy.contains(userId)) {
      return;
    }
    setState(() => _busy.add(userId));
    try {
      await _friends.act(userId, action);
    } on Object catch (error) {
      debugPrint('A friend action failed: $error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That did not go through.')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy.remove(userId));
      }
    }
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

/// `.sepk` — the small caps-ish heading over each list.
class _Heading extends StatelessWidget {
  const _Heading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: kTextFontFamily,
          fontSize: kFontSizeMicro,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: kCreamSecondary,
        ),
      ),
    );
  }
}

/// `.frow .plan` — the round calendar button on a friend's row, which takes
/// you to the deck the way the mockup's `data-go="swipe"` does.
class _PlanButton extends StatelessWidget {
  const _PlanButton({required this.name, required this.onPressed});

  final String name;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // A node of its own, for the reason [_RowAction] gives: an annotation that
    // is not a container folds into the row around it, and the label a screen
    // reader hears becomes the name, the subtitle and this button read as one
    // sentence with nothing in it to press.
    return Semantics(
      label: 'Plan with $name',
      button: true,
      container: true,
      excludeSemantics: true,
      onTap: onPressed,
      child: AppIconButton(
        icon: Icons.calendar_month_rounded,
        size: kUtilityButtonSize,
        iconSize: 18,
        onPhoto: false,
        onTap: onPressed,
      ),
    );
  }
}

/// Two controls in a row's trailing slot.
///
/// Two words side by side outgrow the row they sit in once the text scale is
/// turned up — there is no width left for the name they refer to. The trailing
/// slot is measured by what it asks for, so nothing here can be told to shrink;
/// the pair stacks instead.
class _TrailingPair extends StatelessWidget {
  const _TrailingPair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(kFontSizeSmall) >
        kRowActionsStackFontSize) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [first, second],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [first, second],
    );
  }
}

/// One word in a row's trailing slot, with a label that names the person.
///
/// Both carry the person's name in their label. Two rows on this page can
/// offer the same two words, and "Accept" on its own tells a screen reader
/// which button it is but not whose.
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.label,
    required this.semanticLabel,
    required this.busy,
    required this.onPressed,
    this.tint,
  });

  final String label;
  final String semanticLabel;
  final bool busy;
  final VoidCallback onPressed;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final enabled = !busy;

    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: enabled,
      // A node of its own. Left to merge, a lone action in a row's trailing
      // slot folds into the row's node and the name, the subtitle and the
      // button become one unpressable sentence — which is what happens with
      // one button and, confusingly, not with two, because two tap actions
      // cannot share a node and are forced apart.
      container: true,
      // The word inside would otherwise be read instead of the name; excluding
      // it drops the button's own tap action, so it is re-declared (D83).
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, kMinTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          foregroundColor: tint ?? kCreamSecondary,
          textStyle: const TextStyle(
            fontFamily: kTextFontFamily,
            fontSize: kFontSizeSmall,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
