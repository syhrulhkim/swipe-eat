import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/distance_label.dart';
import '../../../core/location/user_position_state.dart';
import '../../../core/location/user_location.dart';
import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_lottie.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../restaurants/data/restaurant_repository.dart';
import '../../restaurants/models/cuisine_count.dart';
import '../../restaurants/models/restaurant.dart';
import '../../restaurants/models/restaurant_card.dart';
import '../../restaurants/models/restaurant_detail_data.dart';
import '../../restaurants/presentation/restaurant_grid_card.dart';
import 'dashboard_widgets.dart';

/// The list behind an Explore tile: every restaurant of one cuisine within
/// the user's radius, in the same two-column grid grammar as the Liked
/// screen.
class CuisineRestaurantsPage extends StatefulWidget {
  const CuisineRestaurantsPage({
    super.key,
    required this.cuisineId,
    this.cuisine,
    this.repository,
  });

  final int cuisineId;

  /// Carried by the tap from the grid; a deep link arrives without it, and
  /// the page falls back to a generic title.
  final CuisineCount? cuisine;

  /// Injected by tests; in the app the page builds its own.
  final RestaurantRepository? repository;

  @override
  State<CuisineRestaurantsPage> createState() => _CuisineRestaurantsPageState();
}

class _CuisineRestaurantsPageState extends State<CuisineRestaurantsPage>
    with UserPositionState {
  late final RestaurantRepository _restaurants =
      widget.repository ?? RestaurantRepository();

  List<Restaurant> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    loadUserPosition();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Same contract as the old Explore map: a fallback fix is not a real
      // location, and passing null lets the RPC measure from the profile's
      // stored coordinates instead.
      final position = await resolveUserPosition();
      final hasRealPosition = !isFallbackUserPosition(position);
      final rows = await _restaurants.search(
        cuisineId: widget.cuisineId,
        latitude: hasRealPosition ? position.latitude : null,
        longitude: hasRealPosition ? position.longitude : null,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } on Object catch (error) {
      debugPrint('Cuisine list load failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Could not load restaurants.';
      });
    }
  }

  void _openRestaurant(Restaurant restaurant) {
    context.push(
      '/restaurant/${restaurant.id}',
      extra: RestaurantCard.fromRestaurant(restaurant).toDetailPayload(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cuisine = widget.cuisine;
    final title = cuisine == null
        ? 'Explore'
        : '${cuisine.emoji} ${cuisine.label}'.trim();
    final error = _error;

    return Scaffold(
      backgroundColor: kBackgroundDark,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                12,
                AppSpacing.screenPadding,
                12,
              ),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    size: kUtilityButtonSize,
                    onPhoto: false,
                    semanticLabel: 'Back',
                    onTap: () => unawaited(Navigator.of(context).maybePop()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppEyebrow(label: 'Within your radius'),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appSectionTitleStyle(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: AppLottie(motion: AppMotion.pin, size: 88),
                    )
                  : error != null || _rows.isEmpty
                      ? ListView(
                          physics: const BouncingScrollPhysics(),
                          padding:
                              const EdgeInsets.all(AppSpacing.screenPadding),
                          children: [
                            if (error != null)
                              EmptyTabMessage(
                                eyebrow: 'List unavailable',
                                title: 'Something went wrong',
                                subtitle: error,
                                actionLabel: 'Try again',
                                onAction: () => unawaited(_load()),
                              )
                            else
                              const EmptyTabMessage(
                                eyebrow: 'Nothing in range',
                                title: 'No places nearby',
                                subtitle:
                                    'Widen your search radius in Settings to '
                                    'see more of this cuisine.',
                              ),
                          ],
                        )
                      : GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenPadding,
                            4,
                            AppSpacing.screenPadding,
                            AppSpacing.screenPadding,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: _rows.length,
                          itemBuilder: (context, index) {
                            final restaurant = _rows[index];
                            return RestaurantGridCard(
                              restaurant: restaurant,
                              distanceText: distanceLabelFrom(
                                userPosition,
                                latitude: restaurant.latitude,
                                longitude: restaurant.longitude,
                              ),
                              onTap: () => _openRestaurant(restaurant),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
