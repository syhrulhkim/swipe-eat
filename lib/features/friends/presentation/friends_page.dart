import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../dashboard/presentation/dashboard_widgets.dart';
import '../data/friends_repository.dart';
import '../models/friend.dart';
import '../state/friends_controller.dart';
import 'person_row.dart';

/// Where the You tab's "Friends · 38" goes.
///
/// The prototype draws the button and stops, so this screen is the design's
/// vocabulary applied to the three lists the button implies: people waiting on
/// an answer from you, people you are waiting on, and the friends themselves.
///
/// Every row here is `PersonRow` with something in its `trailing` slot, which
/// is the slot that widget was given for exactly this screen. A row with
/// buttons on it is not itself a button, so none of these rows tap.
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key, this.friends});

  /// Injected by tests; in the app the shared instance is used.
  final FriendsController? friends;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  late final FriendsController _friends =
      widget.friends ?? FriendsController.instance;

  /// The people whose Accept, Decline or Remove is still in flight. Keyed by
  /// id rather than a single bool: two requests can be answered in the time
  /// one round trip takes, and a page-wide flag would grey out the second.
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    unawaited(_friends.ensureLoaded());
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
                12,
              ),
              child: AnimatedBuilder(
                animation: _friends,
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
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text('Friends', style: appTitleStyle(context))),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(child: _list(context)),
      ],
    );
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
            'Nobody yet. Friends turn up here when somebody in your contacts '
            'joins, or when a request you sent is accepted.',
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

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        if (incoming.isNotEmpty) ...[
          const _Heading('Wants to be friends'),
          for (final request in incoming)
            PersonRow(
              key: ValueKey('in:${request.profile.id}'),
              profile: request.profile,
              selected: false,
              onTap: () {},
              trailing: _AnswerButtons(
                name: request.profile.name,
                busy: _busy.contains(request.profile.id),
                onAccept: () => unawaited(
                  _act(request.profile.id, FriendAction.accept),
                ),
                onDecline: () => unawaited(
                  _act(request.profile.id, FriendAction.decline),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (outgoing.isNotEmpty) ...[
          const _Heading('Waiting to hear back'),
          for (final request in outgoing)
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
          const SizedBox(height: AppSpacing.md),
        ],
        if (friends.isNotEmpty) ...[
          _Heading('Your friends · ${friends.length}'),
          for (final friend in friends)
            PersonRow(
              key: ValueKey('friend:${friend.id}'),
              profile: friend,
              selected: false,
              onTap: () {},
              trailing: _RowAction(
                label: 'Remove',
                semanticLabel: 'Remove ${friend.name}',
                busy: _busy.contains(friend.id),
                onPressed: () => unawaited(_confirmRemove(friend)),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _confirmRemove(FriendProfile friend) async {
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

  /// Every button on this page ends here: the RPC takes one action word and
  /// the page's only job is to say when it did not work.
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

class _Heading extends StatelessWidget {
  const _Heading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: kTextFontFamily,
          fontSize: kFontSizeMicro,
          fontWeight: FontWeight.w600,
          color: kCreamSecondary,
        ),
      ),
    );
  }
}

/// Accept and Decline on one incoming request.
///
/// Both carry the person's name in their label. Two rows on this page can
/// offer the same two words, and "Accept" on its own tells a screen reader
/// which button it is but not whose.
class _AnswerButtons extends StatelessWidget {
  const _AnswerButtons({
    required this.name,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final String name;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final decline = _RowAction(
      label: 'Decline',
      semanticLabel: 'Decline $name',
      busy: busy,
      onPressed: onDecline,
    );
    final accept = _RowAction(
      label: 'Accept',
      semanticLabel: 'Accept $name',
      tint: kAccentEmber,
      busy: busy,
      onPressed: onAccept,
    );

    // Two words side by side outgrow the row they sit in once the text scale
    // is turned up — there is no width left for the name they refer to. The
    // trailing slot is measured by what it asks for, so nothing here can be
    // told to shrink; the pair stacks instead. Accept goes on top: it is the
    // answer most requests get.
    if (MediaQuery.textScalerOf(context).scale(kFontSizeSmall) >
        kRowActionsStackFontSize) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [accept, decline],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [decline, accept],
    );
  }
}

/// One word in a row's trailing slot, with a label that names the person.
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
