import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/radius_options.dart';
import '../../auth/models/app_user.dart';
import '../../auth/state/auth_controller.dart';
import '../../friends/state/friends_controller.dart';
import '../../onboarding/models/onboarding_draft.dart';
import '../../restaurants/state/likes_controller.dart';
import '../data/profile_repository.dart';
import 'preference_controls.dart';
import '../models/autoplay_setting.dart';
import '../state/autoplay_controller.dart';

/// The three counts on the You tab.
///
/// Only [bites] is real today: plans and the eating-out streak are computed
/// from a calendar this phase does not build. They are a value object rather
/// than two more nullable fields on the page so that the phase which does
/// build them has one thing to fill in, and so the tab reads 0 rather than
/// hiding a tile and changing shape the day it starts counting.
class ProfileStats {
  const ProfileStats({this.plansKept = 0, this.streakWeeks = 0});

  final int plansKept;
  final int streakWeeks;
}

/// The design's S10. Who is signed in, what they have collected, and the diet
/// and budget rules that shape their deck.
///
/// This tab does not use `DashboardTabShell`: the design puts a notifications
/// button on the same line as the title, and the shell's header is a title
/// column with nothing beside it. The chrome below is the shell's — background,
/// glow, safe area — laid out for a topbar with two ends.
class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    required this.authController,
    this.likes,
    this.friends,
    this.repository,
    this.autoplay,
    this.stats = const ProfileStats(),
    this.notificationCount = 0,
  });

  final AuthController authController;

  /// Injected by tests; in the app the tab builds its own.
  final LikesController? likes;
  final FriendsController? friends;
  final ProfileRepository? repository;

  /// The autoplay setting (D146). Injected by tests; the app shares one.
  final AutoplayController? autoplay;

  /// Filled by a later phase. Zero is an honest answer, not a placeholder:
  /// nobody has kept a plan in an app that cannot yet make one.
  final ProfileStats stats;

  /// Nothing feeds this yet, so the dot is hidden at 0 rather than drawn empty.
  final int notificationCount;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late final LikesController _likes = widget.likes ?? LikesController.instance;
  late final FriendsController _friends =
      widget.friends ?? FriendsController.instance;
  late final ProfileRepository _repository =
      widget.repository ?? ProfileRepository();
  late final AutoplayController _autoplay =
      widget.autoplay ?? AutoplayController.instance;

  @override
  void initState() {
    super.initState();
    // The counts come from the shared likes cache, which another tab may have
    // filled already; ensureLoaded is deduplicated, so this is free when it has.
    unawaited(_autoplay.ensureLoaded());
    unawaited(_likes.ensureLoaded().catchError((Object error) {
      debugPrint('Profile likes load failed: $error');
    }));
    // The count on the ghost button. `ensureLoaded` swallows its own failures
    // and leaves the count at zero, which is the same shape a new account has.
    unawaited(_friends.ensureLoaded());
  }

  /// Applies a preference change to the session first and writes it after.
  ///
  /// Optimistic because these are one-tap answers to questions the user has
  /// already thought about: waiting on a round trip to move a switch makes the
  /// switch feel broken. A failed write puts the old value back and says so —
  /// silently keeping the optimistic value would be a lie about the deck.
  Future<void> _save(
    AppUser optimistic,
    Future<AppUser> Function() write,
  ) async {
    final previous = widget.authController.user;
    widget.authController.applyUser(optimistic);

    try {
      widget.authController.applyUser(await write());
    } on Object catch (error) {
      debugPrint('Preference save failed: $error');
      if (previous != null) {
        widget.authController.applyUser(previous);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that preference.')),
      );
    }
  }

  Future<void> _editHalal(AppUser user) async {
    final value = await _sheet<bool>(
      title: 'Halal only',
      builder: (context, close) => PrefSwitchRow(
        title: 'Halal only',
        subtitle: 'Only places we know are certified',
        value: user.halalOnly,
        onChanged: close,
      ),
    );
    if (value == null) {
      return;
    }
    await _save(
      user.copyWith(halalOnly: value),
      () => _repository.updatePreferences(halalOnly: value),
    );
  }

  Future<void> _editSpice(AppUser user) async {
    final value = await _sheet<SpiceLevel>(
      title: 'Spice',
      builder: (context, close) => PrefSpiceRow(
        value: SpiceLevel.fromLevel(user.spiceLevel),
        onChanged: close,
      ),
    );
    if (value == null) {
      return;
    }
    await _save(
      user.copyWith(spiceLevel: value.level),
      () => _repository.updatePreferences(spiceLevel: value.level),
    );
  }

  /// A device setting, not a taste one, so it is written to the device and
  /// never to `profiles` (D146).
  Future<void> _editAutoplay() async {
    final value = await _sheet<AutoplaySetting>(
      title: 'Autoplay',
      builder: (context, close) => PrefAutoplayRow(
        value: _autoplay.setting,
        onChanged: close,
      ),
    );
    if (value == null) {
      return;
    }
    await _autoplay.select(value);
  }

  Future<void> _editBudget(AppUser user) async {
    // The range reports on every drag, so the sheet keeps the pair locally and
    // writes once, when it closes — otherwise a single drag would fire a dozen
    // round trips. [touched] is why a dismissed sheet writes nothing: the
    // control has to show *some* range, and showing one is not choosing it.
    var min = user.budgetMin ?? kBudgetDefaultMin;
    int? max = user.hasBudget ? user.budgetMax : kBudgetDefaultMax;
    var touched = false;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: kBackgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
      ),
      builder: (sheetContext) => _Sheet(
        title: 'Budget per person',
        child: StatefulBuilder(
          builder: (context, setSheetState) => PrefBudgetRow(
            min: min,
            max: max,
            onChanged: (newMin, newMax) => setSheetState(() {
              min = newMin;
              max = newMax;
              touched = true;
            }),
          ),
        ),
      ),
    );

    if (!touched || !mounted) {
      return;
    }
    final upper = max;
    await _save(
      user.copyWith(budgetMin: min, budgetMax: upper),
      () => _repository.updatePreferences(budgetMin: min, budgetMax: upper),
    );
  }

  Future<void> _editRadius(AppUser user) async {
    // Wrapped, because null is a real answer here ("Any distance") and a
    // bare `int?` could not tell it apart from a dismissed sheet.
    final choice = await _sheet<_RadiusChoice>(
      title: 'Default radius',
      // Ten stops at a 44 pt target is taller than a sheet on a short phone,
      // so the list scrolls rather than overflowing off the bottom.
      builder: (context, close) => Flexible(
        child: SingleChildScrollView(
          child: PrefRow(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final stop in kRadiusStops)
                  _RadiusOption(
                    label: radiusLabel(stop),
                    selected: stop == user.searchRadiusKm,
                    onTap: () => close(_RadiusChoice(stop)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (choice == null || !mounted) {
      return;
    }
    final km = choice.km;
    await _save(
      user.copyWith(searchRadiusKm: km, clearRadius: km == null),
      () => _repository.updateSearchRadius(km),
    );
  }

  /// Opens one edit control in a sheet and returns the value it produced, or
  /// null when the sheet was dismissed without an answer.
  Future<T?> _sheet<T>({
    required String title,
    required Widget Function(BuildContext context, ValueChanged<T> close)
        builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: kBackgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
      ),
      builder: (sheetContext) => _Sheet(
        title: title,
        child: builder(
          sheetContext,
          (value) => Navigator.of(sheetContext).pop(value),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // Three sources: the profile row (name, rules, radius), the likes cache
      // (the bites count) and the friends cache (the ghost button's count).
      animation: Listenable.merge([
        widget.authController,
        _likes,
        _friends,
        _autoplay,
      ]),
      builder: (context, _) {
        final user = widget.authController.user;

        return DecoratedBox(
          decoration: const BoxDecoration(color: kBackgroundDark),
          child: Stack(
            children: [
              const ScreenGlow(),
              SafeArea(
                bottom: false,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    18,
                    AppSpacing.screenPadding,
                    24,
                  ),
                  children: [
                    _TopBar(count: widget.notificationCount),
                    const SizedBox(height: 18),
                    _MeRow(user: user),
                    const SizedBox(height: 20),
                    _Stats(
                      bites: _likes.liked.length,
                      bitesCapped: _likes.liked.length >= _likedFetchLimit,
                      stats: widget.stats,
                    ),
                    if (user != null) ...[
                      const SizedBox(height: 24),
                      Text('Your taste', style: appSectionTitleStyle(context)),
                      const SizedBox(height: 8),
                      _PrefRow(
                        label: 'Halal only',
                        value: user.halalOnly ? 'On' : 'Off',
                        onTap: () => _editHalal(user),
                      ),
                      _PrefRow(
                        label: 'Spice',
                        // The pips are the value, so there is no text one —
                        // and a screen reader needs the words back.
                        semanticValue:
                            SpiceLevel.fromLevel(user.spiceLevel)?.label ??
                                'Not set',
                        trailing: _SpicePips(level: user.spiceLevel),
                        onTap: () => _editSpice(user),
                      ),
                      _PrefRow(
                        label: 'Budget per person',
                        value: budgetRangeLabel(user.budgetMin, user.budgetMax),
                        onTap: () => _editBudget(user),
                      ),
                      _PrefRow(
                        label: 'Default radius',
                        value: radiusLabel(user.searchRadiusKm),
                        last: true,
                        onTap: () => _editRadius(user),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Its own section, and above the signed-in rules on
                    // purpose: this one is about the phone, not the palate,
                    // and it is the only row here a signed-out browse session
                    // would also have (D146).
                    Text('Playback', style: appSectionTitleStyle(context)),
                    const SizedBox(height: 8),
                    _PrefRow(
                      label: 'Autoplay',
                      value: _autoplay.setting.label,
                      last: true,
                      onTap: () => unawaited(_editAutoplay()),
                    ),
                    const SizedBox(height: 28),
                    // The design's `.settings` grid: two ghost buttons side by
                    // side. They stack below [kSettingsGridStackWidth] rather
                    // than squeezing, because "Friends · 38" and "Settings"
                    // both grow with the text scale and a pill does not.
                    _SettingsGrid(
                      friendCount: _friends.count,
                      onFriends: () => context.push('/friends'),
                      onSettings: () => context.push('/settings'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Mirrors the default page size of `RestaurantRepository.likedRestaurants`. A
/// list that comes back exactly this long is a page, not a total, so the tile
/// reports it as "200+" rather than claiming an exact count it cannot know.
const int _likedFetchLimit = 200;

/// The design's `.settings` — two ghost buttons, Friends and Settings.
///
/// Side by side down to [kSettingsGridStackWidth] and stacked below it. Two
/// pills that cannot shrink, sharing a row that can, is the one arrangement
/// that overflows on a 320 pt phone at a doubled text scale.
class _SettingsGrid extends StatelessWidget {
  const _SettingsGrid({
    required this.friendCount,
    required this.onFriends,
    required this.onSettings,
  });

  /// Drawn even at zero. "Friends · 0" is the truth about a new account, and a
  /// button that appeared once you had friends would be a button nobody could
  /// find in order to get any.
  final int friendCount;
  final VoidCallback onFriends;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final friends = AppSecondaryButton(
      label: 'Friends · $friendCount',
      expand: true,
      onPressed: onFriends,
    );
    final settings = AppSecondaryButton(
      label: 'Settings',
      expand: true,
      onPressed: onSettings,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kSettingsGridStackWidth) {
          return Column(
            children: [
              friends,
              const SizedBox(height: AppSpacing.sm),
              settings,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: friends),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: settings),
          ],
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('You', style: appTitleStyle(context))),
        _NotificationsButton(count: count),
      ],
    );
  }
}

/// The bell, with the design's cream count dot rather than the red badge the
/// shared icon button draws: red is not in this palette, and a red dot on a
/// dark screen reads as an error rather than as "one thing waiting".
class _NotificationsButton extends StatelessWidget {
  const _NotificationsButton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    // A container of its own, or the bell's label lands on the same semantics
    // node as the title beside it and the screen is announced as
    // "You Notifications, button" — one control where there are two things.
    return Semantics(
      container: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AppIconButton(
            icon: Icons.notifications_none_rounded,
            size: kUtilityButtonSize,
            background: kGlass,
            semanticLabel:
                count > 0 ? 'Notifications, $count waiting' : 'Notifications',
            onTap: () {},
          ),
          if (count > 0)
            Positioned(
              top: -2,
              right: -2,
              // The dot repeats what the label already says; announcing the
              // digit again would read as a second control.
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kAccentCream,
                      borderRadius: BorderRadius.circular(kRadiusPill),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontFamily: kTextFontFamily,
                        fontSize: kFontSizeMicro,
                        fontWeight: FontWeight.w700,
                        color: kOnAccent,
                        height: 1.2,
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

/// `.me-row` — the portrait, the name, and the one line that says where and
/// since when.
class _MeRow extends StatelessWidget {
  const _MeRow({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final account = user;
    final name = account?.name ?? 'Guest';

    return Row(
      children: [
        _Avatar(url: account?.avatarUrl, name: name),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontFamily: kDisplayFontFamily,
                  fontSize: kFontSizeProfileName,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: kTextOnPhoto,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                account == null
                    ? 'Not signed in'
                    : _sinceLine(account.lastPlaceName, account.createdAt),
                style: const TextStyle(
                  fontFamily: kTextFontFamily,
                  fontSize: kFontSizeSmall,
                  color: kCreamSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Bangsar · eating out since Mar 2026". The place is dropped when there has
/// never been a fix — a leading separator would read as a missing word.
String _sinceLine(String? place, DateTime? since) {
  final parts = <String>[
    if (place != null && place.isNotEmpty) place,
    if (since != null) 'eating out since ${_monthYear(since)}',
  ];
  return parts.isEmpty ? 'New here' : parts.join(' · ');
}

/// Hand-rolled rather than `intl`: the app bundles no localisation package,
/// and one three-letter month is not a reason to add one.
const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _monthYear(DateTime date) => '${_months[date.month - 1]} ${date.year}';

/// The one round ember border in the app. Initials until the photo lands, and
/// in place of it when there is none — a generic person glyph tells you less
/// about whose account this is than two letters do.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final photo = url;

    return Container(
      width: kProfileAvatarSize,
      height: kProfileAvatarSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kSurfacePanel,
        shape: BoxShape.circle,
        border: Border.all(color: kAccentEmber, width: 2),
        image: photo == null
            ? null
            : DecorationImage(
                image: ResizeImage(
                  NetworkImage(photo),
                  width: cachePx(context, kProfileAvatarSize),
                ),
                fit: BoxFit.cover,
              ),
      ),
      child: photo != null
          ? null
          : Text(
              _initials(name),
              style: const TextStyle(
                fontFamily: kDisplayFontFamily,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: kTextOnPhoto,
              ),
            ),
    );
  }
}

String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+'))
    ..removeWhere((word) => word.isEmpty);
  if (words.isEmpty) {
    return '?';
  }
  if (words.length == 1) {
    return words.first.characters.first.toUpperCase();
  }
  return (words.first.characters.first + words.last.characters.first)
      .toUpperCase();
}

/// `.stats` — three glass tiles. Equal width whatever they hold, so the row
/// does not reflow the day the last two start counting.
class _Stats extends StatelessWidget {
  const _Stats({
    required this.bites,
    required this.bitesCapped,
    required this.stats,
  });

  final int bites;
  final bool bitesCapped;
  final ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight, so the three tiles are as tall as the tallest of them.
    // "eating-out streak" wraps to two lines on a narrow screen and the others
    // do not; without this the row would be a staircase.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatTile(
              value: '$bites${bitesCapped ? '+' : ''}',
              label: 'bites',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(value: '${stats.plansKept}', label: 'plans kept'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              value: '${stats.streakWeeks} wk',
              label: 'eating-out streak',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kSurfaceDark,
          borderRadius: BorderRadius.circular(kRadiusPanel),
          border: Border.all(color: kHairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: kDisplayFontFamily,
                  fontSize: kFontSizeStatValue,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1,
                  color: kTextOnPhoto,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Left to wrap: "eating-out streak" does not fit on one line in a
            // third of a 320 px screen, and an ellipsis there would hide which
            // number this is.
            Text(
              label,
              style: const TextStyle(
                fontFamily: kTextFontFamily,
                fontSize: kFontSizeMicro,
                color: kCreamSecondary,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One `.pref` row: a label, its current value, a chevron, and a hairline
/// under everything but the last.
class _PrefRow extends StatelessWidget {
  const _PrefRow({
    required this.label,
    required this.onTap,
    this.value,
    this.trailing,
    this.semanticValue,
    this.last = false,
  });

  final String label;
  final VoidCallback onTap;

  /// The text value. Rows that draw their value instead pass [trailing] and
  /// spell it out in [semanticValue].
  final String? value;
  final Widget? trailing;
  final String? semanticValue;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: semanticValue ?? value,
      button: true,
      // See D83: excluding the children also drops the InkWell's tap action,
      // so it is re-declared here.
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: kUtilityButtonSize),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: last
                  ? null
                  : const Border(bottom: BorderSide(color: kHairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: kTextFontFamily,
                      fontSize: kFontSizeBody,
                      fontWeight: FontWeight.w500,
                      color: kTextOnPhoto,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (trailing != null)
                  trailing!
                else
                  Text(
                    value ?? '',
                    style: const TextStyle(
                      fontFamily: kTextFontFamily,
                      fontSize: kFontSizeSmall,
                      color: kCreamSecondary,
                    ),
                  ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: kCreamSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Five pips, of which the answer lights the first N.
///
/// Five for four levels, exactly as the prototype draws it: "Bring it" still
/// leaves one dark, so the scale never reads as maxed out and the row keeps
/// looking like something you could still change.
class _SpicePips extends StatelessWidget {
  const _SpicePips({required this.level});

  final int? level;

  static const int _pipCount = 5;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < _pipCount; index++) ...[
          if (index > 0) const SizedBox(width: 4),
          Container(
            width: kSpicePipSize,
            height: kSpicePipSize,
            decoration: BoxDecoration(
              color: index < (level ?? 0) ? kAccentEmber : kSurfacePanel,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

/// The chrome every edit sheet shares: a title, the control, and enough room
/// under it for the home indicator.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          20,
          AppSpacing.screenPadding,
          24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: appSectionTitleStyle(context)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Carries a radius answer out of the sheet, null included.
class _RadiusChoice {
  const _RadiusChoice(this.km);

  final int? km;
}

class _RadiusOption extends StatelessWidget {
  const _RadiusOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: kUtilityButtonSize,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kFontSizeBody,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? kAccentEmber : kTextOnPhoto,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, size: 18, color: kAccentEmber),
            ],
          ),
        ),
      ),
    );
  }
}
