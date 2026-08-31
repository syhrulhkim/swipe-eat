import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/radius_options.dart';
import '../../auth/models/app_user.dart';
import '../../auth/state/auth_controller.dart';
import '../../restaurants/data/restaurant_repository.dart';
import '../../restaurants/models/swipe_stats.dart';
import '../../restaurants/state/likes_controller.dart';
import '../data/profile_repository.dart';
import '../models/passport_destination.dart';

/// Who is signed in, what they have collected, and the switches that shape
/// their deck.
///
/// Laid out as an editorial page rather than a settings list: a masthead that
/// gives the name the largest type in the app, a band of oversized counts, and
/// numbered hairline rows instead of stacked cards. The page carries very few
/// controls, so the space goes to the two things it can actually say — who you
/// are and what you have collected.
class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    required this.authController,
    this.repository,
    this.restaurants,
    this.likes,
  });

  final AuthController authController;

  /// Injected by tests; in the app the tab builds its own.
  final ProfileRepository? repository;
  final RestaurantRepository? restaurants;
  final LikesController? likes;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab>
    with SingleTickerProviderStateMixin {
  late final ProfileRepository _profiles =
      widget.repository ?? ProfileRepository();
  late final RestaurantRepository _restaurants =
      widget.restaurants ?? RestaurantRepository();
  late final LikesController _likes = widget.likes ?? LikesController.instance;

  /// Drives the one-shot entrance. Deliberately finite: the dashboard mounts
  /// every tab at once, so anything looping here would keep a resting screen
  /// permanently animating.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  SwipeStats? _stats;
  bool _savingPassport = false;

  @override
  void initState() {
    super.initState();
    _entrance.forward();
    unawaited(_loadStats());
    // The counts come from the shared likes cache, which another tab may have
    // filled already; ensureLoaded is deduplicated, so this is free when it has.
    unawaited(_likes.ensureLoaded().catchError((Object error) {
      debugPrint('Profile likes load failed: $error');
    }));
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// Best-effort: the band shows a dash rather than taking the page down when
  /// the stats RPC is unreachable.
  Future<void> _loadStats() async {
    try {
      final stats = await _restaurants.swipeStats();
      if (!mounted) {
        return;
      }
      setState(() {
        _stats = stats;
      });
    } on Object catch (error) {
      debugPrint('Swipe stats fetch failed: $error');
    }
  }

  Future<void> _pickPassport() async {
    final user = widget.authController.user;
    if (user == null || _savingPassport) {
      return;
    }

    final choice = await showModalBottomSheet<PassportDestination?>(
      context: context,
      backgroundColor: kSurfacePanel,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
      ),
      builder: (sheetContext) => _PassportSheet(user: user),
    );
    // Null = dismissed. The clear option returns a sentinel with NaN
    // coordinates so it survives the nullable result type.
    if (choice == null || !mounted) {
      return;
    }

    final clearing = choice.latitude.isNaN;
    if (clearing && !user.hasPassport) {
      return;
    }

    setState(() {
      _savingPassport = true;
    });

    try {
      final updated = clearing
          ? await _profiles.setPassport()
          : await _profiles.setPassport(
              latitude: choice.latitude,
              longitude: choice.longitude,
              placeName: choice.name,
            );
      widget.authController.applyUser(updated);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            clearing
                ? 'Passport off — back to your real location.'
                : 'Deck pinned to ${choice.name}.',
          ),
        ),
      );
    } on Object catch (error) {
      debugPrint('Passport write failed: $error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update your passport.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingPassport = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: kBackgroundDark),
      child: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          // Two sources: the profile row (name, passport, radius) and the
          // likes cache (the counts).
          animation: Listenable.merge([widget.authController, _likes]),
          builder: (context, _) => _buildPage(context),
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    final user = widget.authController.user;
    final signedIn = user != null;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        20,
        AppSpacing.screenPadding,
        32,
      ),
      children: [
        _Reveal(
          controller: _entrance,
          order: 0,
          child: _Masthead(user: user),
        ),
        const SizedBox(height: 28),
        _Reveal(
          controller: _entrance,
          order: 1,
          child: _CountBand(
            likedCount: signedIn ? _likes.liked.length : null,
            likedCapped:
                signedIn && _likes.liked.length >= _likedFetchLimit,
            superLikedCount: signedIn ? _likes.superLikedCount : null,
            streakDays: signedIn ? _stats?.streakDays : null,
          ),
        ),
        const SizedBox(height: 32),
        _Reveal(
          controller: _entrance,
          order: 2,
          child: const _SectionRule(label: 'Taste'),
        ),
        const SizedBox(height: 4),
        _Reveal(
          controller: _entrance,
          order: 3,
          child: const _IndexRow(
            index: '01',
            title: 'Morning mode',
            subtitle: 'Show breakfast first',
            value: 'On',
            tint: kTintMorning,
          ),
        ),
        _Reveal(
          controller: _entrance,
          order: 4,
          child: const _IndexRow(
            index: '02',
            title: 'Spice bias',
            subtitle: 'Prioritize bolder flavors',
            value: 'High',
            tint: kTintSpice,
          ),
        ),
        _Reveal(
          controller: _entrance,
          order: 5,
          child: const _IndexRow(
            index: '03',
            title: 'Nearby focus',
            subtitle: 'Favor shorter distances',
            value: 'On',
            tint: kTintNearby,
          ),
        ),
        if (signedIn)
          _Reveal(
            controller: _entrance,
            order: 6,
            child: _IndexRow(
              index: '04',
              title: 'Passport',
              subtitle: 'Swipe another city before you go',
              value: _savingPassport
                  ? 'Saving…'
                  : user.passportPlaceName ??
                      (user.hasPassport ? 'Pinned' : 'Off'),
              tint: kAccentEmber,
              highlighted: user.hasPassport,
              onTap: () => unawaited(_pickPassport()),
            ),
          ),
        const SizedBox(height: 32),
        _Reveal(
          controller: _entrance,
          order: 7,
          child: const _SectionRule(label: 'Where you swipe'),
        ),
        const SizedBox(height: 4),
        _Reveal(
          controller: _entrance,
          order: 8,
          child: _FactRow(
            label: user != null && user.hasPassport
                ? 'Passport pin'
                : 'Location',
            value: user == null
                ? 'Not set'
                : user.hasPassport
                    ? (user.passportPlaceName ?? 'Pinned')
                    : (user.lastPlaceName ?? 'Not set'),
          ),
        ),
        _Reveal(
          controller: _entrance,
          order: 9,
          child: _FactRow(
            label: 'Search radius',
            value: radiusLabel(user?.searchRadiusKm),
          ),
        ),
        _Reveal(
          controller: _entrance,
          order: 10,
          child: _FactRow(
            label: 'Swipes today',
            value: _stats == null ? '—' : '${_stats!.swipesToday}',
            last: true,
          ),
        ),
      ],
    );
  }
}

/// Mirrors [RestaurantRepository.likedRestaurants]' default page size. A liked
/// list that comes back exactly this long is a page, not a total, so the band
/// reports it as "200+" rather than claiming an exact count it cannot know.
const int _likedFetchLimit = 200;

/// The sentinel [_PassportSheet] returns for "use my real location": a
/// destination with NaN coordinates, distinguishable from a dismissed sheet.
const PassportDestination _clearPassport = PassportDestination(
  name: 'My real location',
  latitude: double.nan,
  longitude: double.nan,
);

/// The top of the page: a small avatar and address over the name set at the
/// largest size the app uses, closed by a full-width rule.
class _Masthead extends StatelessWidget {
  const _Masthead({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final account = user;
    final avatarUrl = account?.avatarUrl;
    final email = account?.email ?? 'Sign in to sync your picks';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: kSurfacePanel,
              backgroundImage:
                  avatarUrl == null ? null : NetworkImage(avatarUrl),
              child: avatarUrl != null
                  ? null
                  : const Icon(
                      Icons.person_rounded,
                      color: kTextOnPhotoSecondary,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppEyebrow(
                    label: account == null ? 'Not signed in' : 'Signed in',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: kTextOnPhotoMuted,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          account?.name ?? 'Guest',
          // Two lines and then an ellipsis: the name is user input, and at
          // display size a long one would otherwise push the whole page down.
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: appDisplayStyle(context),
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, thickness: 1, color: kHairline),
      ],
    );
  }
}

/// Three oversized counts under the masthead. Null renders a dash, which is
/// what the band shows while the stats land and when they never do.
class _CountBand extends StatelessWidget {
  const _CountBand({
    required this.likedCount,
    required this.likedCapped,
    required this.superLikedCount,
    required this.streakDays,
  });

  final int? likedCount;

  /// Whether [likedCount] is a full page rather than a total.
  final bool likedCapped;
  final int? superLikedCount;
  final int? streakDays;

  @override
  Widget build(BuildContext context) {
    final liked = likedCount;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BigCount(
          value: liked == null ? null : '$liked${likedCapped ? '+' : ''}',
          label: 'Liked',
        ),
        const _BandDivider(),
        _BigCount(
          value: superLikedCount == null ? null : '$superLikedCount',
          label: 'Must try',
          color: kAccentEmber,
        ),
        const _BandDivider(),
        _BigCount(
          value: streakDays == null ? null : '$streakDays',
          label: 'Day streak',
        ),
      ],
    );
  }
}

class _BandDivider extends StatelessWidget {
  const _BandDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: kHairline,
    );
  }
}

class _BigCount extends StatelessWidget {
  const _BigCount({
    required this.value,
    required this.label,
    this.color = kTextOnPhoto,
  });

  final String? value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appNumeralStyle(
              context,
              color: value == null ? kTextOnPhotoMuted : color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appEyebrowStyle(context, color: kTextOnPhotoMuted),
          ),
        ],
      ),
    );
  }
}

/// A section label with a rule running out to the right edge — the divider
/// this page uses instead of boxing each group in a card.
class _SectionRule extends StatelessWidget {
  const _SectionRule({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppEyebrow(label: label, color: kTextOnPhotoSecondary),
        const SizedBox(width: 12),
        const Expanded(
          child: Divider(height: 1, thickness: 1, color: kHairline),
        ),
      ],
    );
  }
}

/// One numbered row: the index, the setting, and its current value, separated
/// from the next by a hairline rather than by a gap between cards.
class _IndexRow extends StatelessWidget {
  const _IndexRow({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.tint,
    this.highlighted = false,
    this.onTap,
  });

  final String index;
  final String title;
  final String subtitle;
  final String value;
  final Color tint;

  /// Colours the value in [tint] — reserved for a row that is doing something
  /// right now, so a set passport reads differently from an unset one.
  final bool highlighted;

  /// Null leaves the row inert, which is what the three taste rows are today.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              index,
              style: theme.textTheme.labelSmall?.copyWith(
                color: tint,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: kTextOnPhoto,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kTextOnPhotoMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: highlighted ? tint : kTextOnPhotoSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: kTextOnPhotoMuted,
            ),
          ],
        ],
      ),
    );

    return Column(
      children: [
        if (onTap == null)
          row
        else
          Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: onTap, child: row),
          ),
        const Divider(height: 1, thickness: 1, color: kHairline),
      ],
    );
  }
}

/// A label/value pair on one hairline-separated line.
class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;

  /// The last row in a group drops its rule, so the group ends on content.
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: kTextOnPhotoMuted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: kTextOnPhoto,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!last)
          const Divider(height: 1, thickness: 1, color: kHairline),
      ],
    );
  }
}

/// Fades and lifts one block into place, staggered by [order]. One shared
/// controller drives every block, and it runs once — see
/// [_ProfileTabState._entrance].
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.controller,
    required this.order,
    required this.child,
  });

  final AnimationController controller;

  /// Position in the stagger, top to bottom.
  final int order;
  final Widget child;

  /// How much of the entrance each block waits before it starts. Small enough
  /// that the whole page has settled well inside the controller's duration.
  static const double _step = 0.06;

  @override
  Widget build(BuildContext context) {
    final start = (order * _step).clamp(0.0, 0.7);
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

/// The city list. One tap chooses; the sheet does no writing itself.
class _PassportSheet extends StatelessWidget {
  const _PassportSheet({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Passport', style: appPanelTitleStyle(context)),
            const SizedBox(height: 4),
            Text(
              'Pin the deck to another city. Your real location keeps '
              'syncing underneath and takes over when you switch back.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: kTextOnPhotoMuted,
                  ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                children: [
                  _PassportRow(
                    icon: Icons.my_location_rounded,
                    label: _clearPassport.name,
                    selected: !user.hasPassport,
                    onTap: () =>
                        Navigator.of(context).pop(_clearPassport),
                  ),
                  for (final destination in kPassportDestinations)
                    _PassportRow(
                      icon: Icons.location_city_rounded,
                      label: destination.name,
                      selected: user.hasPassport &&
                          user.passportPlaceName == destination.name,
                      onTap: () => Navigator.of(context).pop(destination),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassportRow extends StatelessWidget {
  const _PassportRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(
        icon,
        color: selected ? kAccentEmber : kTextOnPhotoSecondary,
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: kTextOnPhoto,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: kAccentEmber)
          : null,
    );
  }
}
