import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/preference_tile.dart';
import '../../../core/ui/radius_options.dart';
import '../../auth/models/app_user.dart';
import '../../auth/state/auth_controller.dart';
import '../../dashboard/presentation/dashboard_widgets.dart';
import '../../restaurants/state/likes_controller.dart';
import '../data/profile_repository.dart';
import '../models/passport_destination.dart';

/// Who is signed in, what they have collected, and the taste switches that
/// shape their deck.
class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    required this.authController,
    this.repository,
    this.likes,
  });

  final AuthController authController;

  /// Injected by tests; in the app the tab builds its own.
  final ProfileRepository? repository;
  final LikesController? likes;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late final ProfileRepository _profiles =
      widget.repository ?? ProfileRepository();
  late final LikesController _likes = widget.likes ?? LikesController.instance;
  bool _savingPassport = false;

  @override
  void initState() {
    super.initState();
    // The counts come from the shared likes cache, which another tab may have
    // filled already; ensureLoaded is deduplicated, so this is free when it has.
    unawaited(_likes.ensureLoaded().catchError((Object error) {
      debugPrint('Profile likes load failed: $error');
    }));
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
    return AnimatedBuilder(
      // Two sources: the profile row (name, passport, radius) and the likes
      // cache (the counts).
      animation: Listenable.merge([widget.authController, _likes]),
      builder: (context, _) {
        final user = widget.authController.user;
        final signedIn = user != null;
        final name = user?.name ?? 'Guest';
        final email = user?.email ?? 'Sign in to sync your picks';

        return DashboardTabShell(
          eyebrow: signedIn ? 'Signed in' : 'Not signed in',
          title: name,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              14,
              AppSpacing.screenPadding,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileHeaderCard(
                  user: user,
                  email: email,
                  likedCount: _likes.liked.length,
                  likedCapped: _likes.liked.length >= _likedFetchLimit,
                  superLikedCount: _likes.superLikedCount,
                ),
                const SizedBox(height: 22),
                Text('Your taste', style: appSectionTitleStyle(context)),
                const SizedBox(height: 4),
                Text(
                  'What the deck weighs before it deals.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: kTextOnPhotoMuted,
                      ),
                ),
                const SizedBox(height: 12),
                const PreferenceTile(
                  icon: Icons.wb_sunny_rounded,
                  title: 'Morning mode',
                  subtitle: 'Show breakfast first',
                  trailingLabel: 'On',
                  tint: kTintMorning,
                ),
                const SizedBox(height: 10),
                const PreferenceTile(
                  icon: Icons.local_fire_department_rounded,
                  title: 'Spice bias',
                  subtitle: 'Prioritize bolder flavors',
                  trailingLabel: 'High',
                  tint: kTintSpice,
                ),
                const SizedBox(height: 10),
                const PreferenceTile(
                  icon: Icons.pin_drop_rounded,
                  title: 'Nearby focus',
                  subtitle: 'Favor shorter distances',
                  trailingLabel: 'On',
                  tint: kTintNearby,
                ),
                if (signedIn) ...[
                  const SizedBox(height: 10),
                  PreferenceTile(
                    icon: Icons.flight_takeoff_rounded,
                    title: 'Passport',
                    subtitle: 'Swipe another city before you go',
                    trailingLabel: _savingPassport
                        ? 'Saving…'
                        : user.passportPlaceName ??
                            (user.hasPassport ? 'Pinned' : 'Off'),
                    tint: kAccentEmber,
                    onTap: () => unawaited(_pickPassport()),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Mirrors the default page size of `RestaurantRepository.likedRestaurants`. A
/// list that comes back exactly this long is a page, not a total, so the header
/// reports it as "200+" rather than claiming an exact count it cannot know.
const int _likedFetchLimit = 200;

/// The sentinel [_PassportSheet] returns for "use my real location": a
/// destination with NaN coordinates, distinguishable from a dismissed sheet.
const PassportDestination _clearPassport = PassportDestination(
  name: 'My real location',
  latitude: double.nan,
  longitude: double.nan,
);

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.user,
    required this.email,
    required this.likedCount,
    required this.likedCapped,
    required this.superLikedCount,
  });

  final AppUser? user;
  final String email;
  final int likedCount;

  /// Whether [likedCount] is a full page rather than a total.
  final bool likedCapped;
  final int superLikedCount;

  @override
  Widget build(BuildContext context) {
    final account = user;
    final avatarUrl = account?.avatarUrl;

    return SimpleCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: kFillOnPhoto,
                  backgroundImage:
                      avatarUrl == null ? null : NetworkImage(avatarUrl),
                  child: avatarUrl != null
                      ? null
                      : const Icon(
                          Icons.person_rounded,
                          color: kTextOnPhotoSecondary,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    email,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: kTextOnPhotoSecondary,
                        ),
                  ),
                ),
              ],
            ),
            if (account != null) ...[
              const SizedBox(height: 16),
              AppStatStrip(
                stats: [
                  AppStat(
                    label: 'Liked',
                    value: '$likedCount${likedCapped ? '+' : ''}',
                  ),
                  AppStat(label: 'Must try', value: '$superLikedCount'),
                ],
              ),
              const SizedBox(height: 14),
              AppStatStrip(
                stats: [
                  AppStat(
                    label: account.hasPassport ? 'Passport' : 'Location',
                    value: account.hasPassport
                        ? (account.passportPlaceName ?? 'Pinned')
                        : (account.lastPlaceName ?? 'Not set'),
                  ),
                  AppStat(
                    label: 'Search radius',
                    value: radiusLabel(account.searchRadiusKm),
                  ),
                ],
              ),
            ],
          ],
        ),
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
