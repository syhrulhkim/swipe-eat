import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/user_position_state.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/glass_ui.dart';
import '../../auth/state/auth_controller.dart';
import '../../restaurants/models/restaurant.dart';
import '../../restaurants/models/restaurant_card.dart';
import '../../restaurants/models/restaurant_detail_data.dart';
import '../state/explore_controller.dart';
import 'dashboard_widgets.dart';
import 'explore_map_view.dart';

/// The map tab: every restaurant within the user's radius, pinned.
class ExploreTab extends StatefulWidget {
  const ExploreTab({
    super.key,
    required this.authController,
    this.controller,
  });

  final AuthController authController;

  /// Injected by tests; in the app the tab builds its own.
  final ExploreController? controller;

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> with UserPositionState {
  late final ExploreController _explore = widget.controller ??
      ExploreController(authController: widget.authController);
  late final bool _ownsController = widget.controller == null;

  @override
  void initState() {
    super.initState();
    loadUserPosition();
    if (_ownsController) {
      unawaited(_explore.load());
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _explore.dispose();
    }
    super.dispose();
  }

  void _openRestaurant(Restaurant restaurant) {
    context.push(
      '/restaurant',
      extra: RestaurantCard.fromRestaurant(restaurant).toDetailPayload(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _explore,
      builder: (context, _) {
        final error = _explore.error;
        if (_explore.loading || error != null || _explore.restaurants.isEmpty) {
          return DashboardTabShell(
            title: 'Explore',
            child: _explore.loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    children: [
                      if (error != null)
                        EmptyTabMessage(
                          title: 'Something went wrong',
                          subtitle: error,
                          actionLabel: 'Try again',
                          onAction: () => unawaited(_explore.load()),
                        )
                      else
                        const EmptyTabMessage(
                          title: 'No restaurants yet',
                          subtitle: 'Check back soon.',
                        ),
                    ],
                  ),
          );
        }

        return DecoratedBox(
          decoration: const BoxDecoration(color: kBackgroundDeep),
          child: ExploreMapView(
            restaurants: _explore.restaurants,
            userPosition: userPosition,
            onOpenRestaurant: _openRestaurant,
          ),
        );
      },
    );
  }
}
