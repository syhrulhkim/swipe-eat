import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/preference_tile.dart';
import '../../../core/ui/radius_options.dart';
import '../../auth/models/app_user.dart';
import '../../dashboard/presentation/dashboard_widgets.dart';

/// Who is signed in, and the taste switches that shape their deck.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
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
            _ProfileHeaderCard(user: user, email: email),
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
  }
}

/// The account card. The name is already the screen title, so this carries the
/// face, the address, and the two settings the deck actually reads.
class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.user, required this.email});

  final AppUser? user;
  final String email;

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
