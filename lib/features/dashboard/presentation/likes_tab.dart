import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/distance_label.dart';
import '../../../core/location/user_position_state.dart';
import '../../../core/ui/app_lottie.dart';
import '../../../core/ui/app_spacing.dart';
import '../../restaurants/data/restaurant_repository.dart';
import '../../restaurants/data/swipe_repository.dart';
import '../../restaurants/models/restaurant.dart';
import '../../restaurants/models/restaurant_card.dart';
import '../../restaurants/models/restaurant_detail_data.dart';
import '../../restaurants/state/likes_controller.dart';
import '../../restaurants/state/restaurant_list_controller.dart';
import 'dashboard_widgets.dart';
import 'likes_tab_view.dart';

/// The places the user has liked, visited and reviewed.
class LikesTab extends StatefulWidget {
  const LikesTab({super.key});

  @override
  State<LikesTab> createState() => _LikesTabState();
}

class _LikesTabState extends State<LikesTab> with UserPositionState {
  // The swipes table is the source of truth; LikesController caches it and
  // notifies when a like lands anywhere in the app (deck, detail page).
  String? _error;

  final RestaurantRepository _restaurants = RestaurantRepository();
  final SwipeRepository _swipes = SwipeRepository();

  /// Loaded the first time their segments are opened, owned here so a tab
  /// switch away and back does not refetch.
  late final RestaurantListController _visited =
      RestaurantListController(() => _restaurants.visitedRestaurants());
  late final RestaurantListController _reviewed =
      RestaurantListController(() => _restaurants.reviewedRestaurants());

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
    _visited.dispose();
    _reviewed.dispose();
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

  Future<void> _markVisited(Restaurant restaurant) async {
    try {
      await _swipes.markVisited(restaurantId: restaurant.id);
    } on Object catch (error) {
      debugPrint('Mark visited failed: $error');
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not mark that place visited.')),
      );
      return;
    }

    // Only once loaded: an untouched Visited segment will fetch the fresh
    // truth on its first open anyway.
    if (_visited.isLoaded) {
      unawaited(_visited.refresh());
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${restaurant.name} marked as visited.')),
    );
  }

  String _distanceLabel(Restaurant restaurant) {
    return distanceLabelFrom(
      userPosition,
      latitude: restaurant.latitude,
      longitude: restaurant.longitude,
    );
  }

  double _distanceMeters(Restaurant restaurant) {
    final position = userPosition;
    if (position == null ||
        (restaurant.latitude == 0 && restaurant.longitude == 0)) {
      return double.infinity;
    }
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      restaurant.latitude,
      restaurant.longitude,
    );
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

    return DashboardTabShell(
      eyebrow: 'Your places',
      title: 'Liked',
      child: !likes.isLoaded || error != null
          ? (error == null
              ? const Center(
                  child: AppLottie(motion: AppMotion.heart, size: 88),
                )
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  children: [
                    EmptyTabMessage(
                      eyebrow: 'Likes unavailable',
                      title: 'Something went wrong',
                      subtitle: error,
                      actionLabel: 'Try again',
                      onAction: () => unawaited(_loadLikes()),
                    ),
                  ],
                ))
          : LikesTabView(
              liked: likes.liked,
              visitedController: _visited,
              reviewedController: _reviewed,
              distanceLabel: _distanceLabel,
              distanceMeters: _distanceMeters,
              isSuperLiked: likes.isSuperLiked,
              onOpenRestaurant: _openRestaurant,
              onUnlike: (restaurant) => unawaited(_unlike(restaurant)),
              onMarkVisited: (restaurant) =>
                  unawaited(_markVisited(restaurant)),
            ),
    );
  }
}
