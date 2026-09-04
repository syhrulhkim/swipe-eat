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

/// Who is signed in, what they have collected, and the taste switches that
/// shape their deck.
class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    required this.authController,
    this.likes,
  });

  final AuthController authController;

  /// Injected by tests; in the app the tab builds its own.
  final LikesController? likes;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late final LikesController _likes = widget.likes ?? LikesController.instance;

  @override
  void initState() {
    super.initState();
    // The counts come from the shared likes cache, which another tab may have
    // filled already; ensureLoaded is deduplicated, so this is free when it has.
    unawaited(_likes.ensureLoaded().catchError((Object error) {
      debugPrint('Profile likes load failed: $error');
    }));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // Two sources: the profile row (name, radius) and the likes
      // cache (the counts).
      animation: Listenable.merge([widget.authController, _likes]),
      builder: (context, _) {
        final user = widget.authController.user;
        final signedIn = user != null;
        final name = user?.name ?? 'Guest';
        final email = user?.email ?? 'Sign in to sync your picks';

        return DashboardTabShell(
          // "You", not the user's name: the design titles the screen and puts
          // the name in the identity row below, where the portrait is.
          title: 'You',
          subtitle: signedIn ? name : 'Not signed in',
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

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.user,
    required this.email,
    required this.likedCount,
    required this.likedCapped,
  });

  final AppUser? user;
  final String email;
  final int likedCount;

  /// Whether [likedCount] is a full page rather than a total.
  final bool likedCapped;

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
                  // "Bites", not "Liked": the design names the saved set
                  // after the gesture. "Must try" went with the super like.
                  AppStat(
                    label: 'Bites',
                    value: '$likedCount${likedCapped ? '+' : ''}',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppStatStrip(
                stats: [
                  AppStat(
                    label: 'Location',
                    value: account.lastPlaceName ?? 'Not set',
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
