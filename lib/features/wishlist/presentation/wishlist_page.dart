import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/empty_state.dart';
import '../../friends/state/friends_controller.dart';
import '../../plans/state/plans_controller.dart';
import '../state/wishlist_controller.dart';
import 'wishlist_row.dart';

/// The design's S8: a checklist of places to try, crossed off once eaten.
///
/// Pushed from the Bites tab rather than being a tab of its own, so it keeps
/// its own scaffold and its own back button instead of borrowing
/// [DashboardTabShell]'s header.
class WishlistPage extends StatefulWidget {
  const WishlistPage({
    super.key,
    this.controller,
    this.onShare,
    this.plans,
    this.friends,
  });

  /// Injected by tests. Left null the page owns one, backed by the real
  /// repository.
  final WishlistController? controller;

  /// Hands the list to the OS share sheet. Constructor-injected with a default
  /// because `share_plus` is a platform channel, and `flutter test` has no
  /// implementation for one.
  final Future<void> Function(String text)? onShare;

  /// The calendar the rows' day badges read. Injected by tests; in the app the
  /// shared instance is used.
  final PlansController? plans;

  /// The address book a sent row's `From <name>` is read out of. Injected by
  /// tests; in the app the one shared cache every other screen reads.
  final FriendsController? friends;

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  late final WishlistController _controller =
      widget.controller ?? WishlistController();
  final TextEditingController _input = TextEditingController();

  late final PlansController _plans = widget.plans ?? PlansController.instance;

  late final FriendsController _friends =
      widget.friends ?? FriendsController.instance;

  /// True only when this page made the controller, so an injected one outlives
  /// the route the way its owner expects.
  late final bool _ownsController = widget.controller == null;

  /// The last error already shown, so one failure raises one snackbar rather
  /// than a fresh one on every rebuild.
  String? _shownError;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    unawaited(_controller.ensureLoaded());
    // The names are wanted only by the rows somebody sent, but the list does
    // not know whether it holds one until it has loaded, and asking after that
    // would redraw the list a second time for a caption. One ask, up front,
    // shared with every other screen that has already asked.
    unawaited(_friends.ensureLoaded());
  }

  /// A write that failed after the list is on screen has nowhere to be seen —
  /// the error card only renders before the first load. Say it out loud
  /// instead, or the tick that snapped back and the row that came back look
  /// like the app losing track.
  void _onControllerChanged() {
    final error = _controller.error;
    if (error == null) {
      _shownError = null;
      return;
    }
    if (error == _shownError || !_controller.isLoaded || !mounted) {
      return;
    }
    _shownError = error;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _input.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _add() async {
    final text = _input.text;
    if (text.trim().isEmpty) {
      return;
    }
    // The field is cleared only once the row has landed. Clearing first loses
    // the user's typing on a failed write, which on a bad connection is the
    // most likely outcome.
    final added = await _controller.addManual(text);
    if (added && mounted) {
      _input.clear();
    }
  }

  Future<void> _share() async {
    final toGo = [
      for (final item in _controller.items)
        if (!item.isEaten) item,
    ];
    if (toGo.isEmpty) {
      return;
    }

    final text = [
      'Places to try:',
      for (final item in toGo)
        item.subtitle.isEmpty
            ? '• ${item.title}'
            : '• ${item.title} — ${item.subtitle}',
    ].join('\n');

    final share = widget.onShare ?? _shareWithOs;
    try {
      await share(text);
    } on Object catch (error) {
      debugPrint('Sharing the wishlist failed: $error');
    }
  }

  Future<void> _shareWithOs(String text) {
    return SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      // The add bar sits at the top, so the keyboard never covers it and the
      // page has no reason to shrink. The list adds the inset to its own
      // bottom padding instead, which keeps the header still.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const ScreenGlow(),
          SafeArea(
            bottom: false,
            child: AnimatedBuilder(
              // Two sources: the list itself, and the address book that turns
              // a sender's id into the name on the right of the row.
              animation: Listenable.merge([_controller, _friends]),
              builder: (context, _) => _buildBody(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            8,
            AppSpacing.screenPadding,
            16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppIconButton(
                icon: Icons.chevron_left_rounded,
                size: kUtilityButtonSize,
                onPhoto: false,
                background: kGlass,
                semanticLabel: 'Back',
                onTap: () => Navigator.of(context).maybePop(),
              ),
              AppIconButton(
                icon: Icons.ios_share_rounded,
                size: kUtilityButtonSize,
                iconSize: 20,
                onPhoto: false,
                background: kGlass,
                semanticLabel: 'Share wishlist',
                onTap: () => unawaited(_share()),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: _Header(
            toGo: _controller.toGoCount,
            eaten: _controller.eatenCount,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: _AddBar(
            controller: _input,
            onSubmit: _add,
          ),
        ),
        if (_controller.isLoaded && _controller.items.isNotEmpty)
          const _ListHint(),
        Expanded(child: _buildList(context)),
        if (_controller.isLoaded && _controller.items.isNotEmpty)
          _Footer(
            canClear: _controller.eatenCount > 0,
            onClear: () => unawaited(_controller.clearEaten()),
          ),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    final error = _controller.error;
    if (!_controller.isLoaded) {
      if (error != null) {
        return AppEmptyState(
          eyebrow: 'Wishlist unavailable',
          title: 'Something went wrong',
          message: error,
          actionLabel: 'Try again',
          onAction: () => unawaited(_controller.refresh()),
        );
      }
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: kAccentEmber),
        ),
      );
    }

    if (_controller.items.isEmpty) {
      return const AppEmptyState(
        eyebrow: 'Nothing on the list',
        title: 'No places to try yet',
        message: 'Swipe up on the deck to save a place for later, or type one '
            'in above.',
      );
    }

    final items = _controller.items;

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        0,
        AppSpacing.screenPadding,
        12 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        final restaurantId = item.restaurantId;

        return WishlistRow(
          key: ValueKey(item.id),
          // The row draws whatever name it is handed and says "From a friend"
          // when handed none — which is what a sender who is not (or is no
          // longer) a friend of mine resolves to, since the friends cache is
          // the only place a name could come from.
          item: item.copyWith(fromUserName: _friends.nameFor(item.fromUserId)),
          // A manual row has no restaurant, so it can never carry a day.
          plannedLabel: restaurantId == null
              ? null
              : _plans.plannedLabelFor(restaurantId),
          onTap: () => unawaited(_controller.toggleEaten(item.id)),
        );
      },
    );
  }
}

/// "Places to / try", and the two counts beside it.
class _Header extends StatelessWidget {
  const _Header({required this.toGo, required this.eaten});

  final int toGo;
  final int eaten;

  @override
  Widget build(BuildContext context) {
    // A Wrap rather than a Row, for the reason the footer is one: at twice
    // the text size the two counts alone are wider than a 320 px phone, and a
    // Row would either stripe the edge or squeeze the title down to a column
    // of single letters. This drops the counts onto their own line instead,
    // and lays them out exactly as the design does whenever they fit.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      // The design's gap between the title and the counts, kept as a minimum
      // for the width where the two only just fit side by side.
      spacing: 12,
      runSpacing: 8,
      children: [
        // Two lines, as the design's `<br>`. Hard-wrapped rather than left to
        // the width, because where it breaks is part of the composition.
        //
        // Scaled down rather than reflowed when the text size outgrows the
        // phone: letting it reflow would break "Places to" across a third
        // line, which is both the wrong composition and 60-odd pixels the
        // list needs. Everything else on the screen still scales in full.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Places to\ntry',
            style: appTitleStyle(context).copyWith(height: 1.0),
          ),
        ),
        // The pair wraps for the same reason, one level down: at twice the
        // text size "3 to go 12 eaten" is itself wider than the phone, so the
        // second count drops under the first rather than off the edge.
        Wrap(
          spacing: 16,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _Count(value: toGo, label: 'to go'),
            _Count(value: eaten, label: 'eaten'),
          ],
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('$value', style: appCountStyle(context)),
          const SizedBox(width: 4),
          Text(
            label,
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

/// The design's `.wl-add`: a pill-shaped field with the add button living
/// inside it, so the two read as one control rather than a field next to a
/// button.
class _AddBar extends StatelessWidget {
  const _AddBar({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kInputBarHeight,
      padding: const EdgeInsets.only(left: 16, right: 7),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: kHairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSubmit(),
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                fontFamily: kTextFontFamily,
                fontSize: kFontSizeBody,
                color: kTextOnPhoto,
              ),
              cursorColor: kAccentEmber,
              decoration: const InputDecoration(
                hintText: 'Add a place…',
                hintStyle: TextStyle(
                  fontFamily: kTextFontFamily,
                  fontSize: kFontSizeBody,
                  color: kCreamMuted,
                ),
                // The pill around it is the field's whole chrome; the theme's
                // filled box would draw a second one inside the first.
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'Add',
            button: true,
            excludeSemantics: true,
            // Excluding drops the InkWell's tap action, so it is re-declared
            // here (D83).
            onTap: onSubmit,
            child: SizedBox(
              // Drawn 36 px, tapped at 44 — the design's size, a finger's
              // target.
              width: kMinTapTarget,
              height: kMinTapTarget,
              // The InkWell takes the whole 44, and the ember disc is painted
              // inside it. The other way round — a 36 px InkWell centred in a
              // 44 px box — leaves the outer ring hit-testing to nothing, so
              // the target would be 44 only for a screen reader.
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSubmit();
                  },
                  child: const Center(
                    child: SizedBox(
                      width: kRoundActionSize,
                      height: kRoundActionSize,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: kAccentEmber,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: kOnAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The design's `.wl-sep`: the quiet instruction that sits above the list,
/// not inside it, so it stays visible while the user scrolls.
///
/// On very small phones at huge text scales the fixed chrome leaves no room
/// for the list, so the hint is dropped rather than forcing an overflow.
class _ListHint extends StatelessWidget {
  const _ListHint();

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).height < 600) {
      return const SizedBox.shrink();
    }

    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenPadding + 4,
        12,
        AppSpacing.screenPadding,
        4,
      ),
      child: Text(
        "Tap a place once you've eaten there",
        style: TextStyle(
          fontFamily: kTextFontFamily,
          fontSize: kFontSizeMicro,
          fontWeight: FontWeight.w600,
          color: kCreamMuted,
          letterSpacing: 0.22,
        ),
      ),
    );
  }
}

/// The design's `.wl-foot`: what the list does with an eaten row, and the one
/// way to empty that half.
class _Footer extends StatelessWidget {
  const _Footer({required this.canClear, required this.onClear});

  final bool canClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding + 4,
          8,
          AppSpacing.screenPadding,
          4,
        ),
        // A Wrap rather than a Row: at a large text scale "Clear eaten" alone
        // is wider than half the phone, and a Row would crush the note beside
        // it into a column of single words. This lets the button drop onto its
        // own line instead, and spaces the two out whenever they do fit.
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 4,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Eaten ones sink to the bottom',
                style: TextStyle(
                  fontFamily: kTextFontFamily,
                  fontSize: kFontSizeSmall,
                  color: kCreamSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: canClear ? onClear : null,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, kMinTapTarget),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                foregroundColor: kAccentEmber,
                disabledForegroundColor: kCreamMuted,
              ),
              child: const Text(
                'Clear eaten',
                style: TextStyle(
                  fontFamily: kTextFontFamily,
                  fontSize: kFontSizeSmall,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
