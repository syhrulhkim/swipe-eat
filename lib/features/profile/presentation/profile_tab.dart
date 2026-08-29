import 'package:flutter/material.dart';

import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/preference_tile.dart';
import '../../auth/models/app_user.dart';
import '../../dashboard/presentation/dashboard_widgets.dart';

/// Who is signed in, and the taste switches that shape their deck.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? 'Guest';
    final email = user?.email ?? 'Sign in to sync your picks';

    return DashboardTabShell(
      title: 'Profile',
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
            _ProfileHeaderCard(name: name, email: email),
            const SizedBox(height: 12),
            const PreferenceTile(
              icon: Icons.wb_sunny_rounded,
              title: 'Morning mode',
              subtitle: 'Show breakfast first',
              trailingLabel: 'On',
              tint: Color(0xFFF6D365),
            ),
            const SizedBox(height: 10),
            const PreferenceTile(
              icon: Icons.local_fire_department_rounded,
              title: 'Spice bias',
              subtitle: 'Prioritize bolder flavors',
              trailingLabel: 'High',
              tint: Color(0xFFE76F51),
            ),
            const SizedBox(height: 10),
            const PreferenceTile(
              icon: Icons.pin_drop_rounded,
              title: 'Nearby focus',
              subtitle: 'Favor shorter distances',
              trailingLabel: 'On',
              tint: Color(0xFFB7E4C7),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.name,
    required this.email,
  });

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return SimpleCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: appPanelTitleStyle(context)),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
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
