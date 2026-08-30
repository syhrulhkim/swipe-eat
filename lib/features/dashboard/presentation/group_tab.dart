import 'package:flutter/material.dart';

import '../../../core/ui/app_spacing.dart';
import 'dashboard_widgets.dart';

/// Group dining, not built yet. The tab exists because the design's nav
/// carries it; the screen says so honestly instead of pretending.
class GroupTab extends StatelessWidget {
  const GroupTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardTabShell(
      eyebrow: 'Swipe together',
      title: 'Group',
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: const [
          EmptyTabMessage(
            eyebrow: 'Coming soon',
            title: 'Nothing here yet',
            subtitle: 'Group sessions — where you and your friends swipe the '
                'same deck and the places you all like win — are on the way.',
          ),
        ],
      ),
    );
  }
}
