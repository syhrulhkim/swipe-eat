import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/user_position_state.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../restaurants/models/restaurant.dart';
import '../../restaurants/models/restaurant_card.dart';
import '../../restaurants/models/restaurant_detail_data.dart';
import '../../restaurants/state/likes_controller.dart';
import 'dashboard_widgets.dart';
import 'likes_tab_view.dart';

/// The places the user has liked, newest first.
class LikesTab extends StatefulWidget {
  const LikesTab({super.key});

  @override
  State<LikesTab> createState() => _LikesTabState();
}

class _LikesTabState extends State<LikesTab> with UserPositionState {
  // The swipes table is the source of truth; LikesController caches it and
  // notifies when a like lands anywhere in the app (deck, detail page).
  String? _error;

  @override
  void initState() {
    super.initState();
    loadUserPosition();
    LikesController.instance.addListener(_onLikesChanged);
    unawaited(_loadLikes());
  }

  @override
  void dispose() {
    LikesController.instance.removeListener(_onLikesChanged);
    super.dispose();
  }

  void _onLikesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadLikes() async {
    setState(() {
      _error = null;
    });

    try {
      await LikesController.instance.ensureLoaded();
    } on Object catch (error) {
      debugPrint('Likes load failed: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Could not load your likes.';
      });
    }
  }

  Future<void> _unlike(Restaurant restaurant) async {
    try {
      await LikesController.instance.unlike(restaurant.id);
    } on Object catch (error) {
      debugPrint('Unlike failed: $error');
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove that like.')),
      );
    }
  }

  String _distanceLabel(Restaurant restaurant) {
    final position = userPosition;
    if (position == null ||
        (restaurant.latitude == 0 && restaurant.longitude == 0)) {
      return 'Johor Bahru';
    }

    final meters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      restaurant.latitude,
      restaurant.longitude,
    );

    if (meters >= 100000) {
      return '100 km +';
    }

    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km away';
    }

    return '${meters.toStringAsFixed(0)} m away';
  }

  void _openRestaurant(Restaurant restaurant) {
    context.push(
      '/restaurant/${restaurant.id}',
      extra: RestaurantCard.fromRestaurant(restaurant).toDetailPayload(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final likes = LikesController.instance;
    final error = _error;
    if (!likes.isLoaded || error != null) {
      return DashboardTabShell(
        title: 'Like',
        child: error == null
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  EmptyTabMessage(
                    title: 'Something went wrong',
                    subtitle: error,
                    actionLabel: 'Try again',
                    onAction: () => unawaited(_loadLikes()),
                  ),
                ],
              ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(color: kBackgroundDark),
      child: LikesTabView(
        liked: likes.liked,
        distanceLabel: _distanceLabel,
        onOpenRestaurant: _openRestaurant,
        onUnlike: _unlike,
      ),
    );
  }
}
