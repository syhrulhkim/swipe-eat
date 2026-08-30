import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_lottie.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../restaurants/models/cuisine_count.dart';
import '../../restaurants/models/restaurant.dart';
import '../../restaurants/models/restaurant_card.dart';
import '../../restaurants/models/restaurant_detail_data.dart';
import '../../restaurants/presentation/restaurant_grid_card.dart';
import '../state/explore_controller.dart';
import 'dashboard_widgets.dart';

/// The Explore tab: a grid of cuisine tiles — the catalog arranged by craving
/// rather than by distance. A tile opens the per-cuisine list, where the
/// radius rule applies.
class ExploreTab extends StatefulWidget {
  const ExploreTab({
    super.key,
    this.controller,
  });

  /// Injected by tests; in the app the tab builds its own.
  final ExploreController? controller;

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  late final ExploreController _explore =
      widget.controller ?? ExploreController();
  late final bool _ownsController = widget.controller == null;

  @override
  void initState() {
    super.initState();
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

  void _openCuisine(CuisineCount cuisine) {
    context.push('/explore/cuisine/${cuisine.id}', extra: cuisine);
  }

  void _openRestaurant(Restaurant restaurant) {
    context.push(
      '/restaurant/${restaurant.id}',
      extra: RestaurantCard.fromRestaurant(restaurant).toDetailPayload(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _explore,
      builder: (context, _) {
        final error = _explore.error;

        return DashboardTabShell(
          eyebrow: 'Browse by craving',
          title: 'Explore',
          child: _explore.loading
              ? const Center(
                  child: AppLottie(motion: AppMotion.pin, size: 88),
                )
              : error != null || _explore.cuisines.isEmpty
                  ? ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.screenPadding),
                      children: [
                        if (error != null)
                          EmptyTabMessage(
                            eyebrow: 'Explore unavailable',
                            title: 'Something went wrong',
                            subtitle: error,
                            actionLabel: 'Try again',
                            onAction: () => unawaited(_explore.load()),
                          )
                        else
                          const EmptyTabMessage(
                            eyebrow: 'Nothing here',
                            title: 'No categories yet',
                            subtitle: 'Check back soon.',
                          ),
                      ],
                    )
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        if (_explore.topPicks.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _TopPicksRail(
                              picks: _explore.topPicks,
                              onOpen: _openRestaurant,
                            ),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenPadding,
                            4,
                            AppSpacing.screenPadding,
                            AppSpacing.screenPadding,
                          ),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 1.15,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final cuisine = _explore.cuisines[index];
                                return _CuisineTile(
                                  cuisine: cuisine,
                                  onTap: () => _openCuisine(cuisine),
                                );
                              },
                              childCount: _explore.cuisines.length,
                            ),
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }
}

/// The Top Picks rail: today's shortlist from the deck ranking, unswiped rows
/// only, reshuffled at midnight with the deck seed. Thins out as the user
/// swipes and disappears when empty.
class _TopPicksRail extends StatelessWidget {
  const _TopPicksRail({required this.picks, required this.onOpen});

  final List<Restaurant> picks;
  final ValueChanged<Restaurant> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            4,
            AppSpacing.screenPadding,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Top picks today', style: appSectionTitleStyle(context)),
              const SizedBox(height: 2),
              Text(
                'Your shortlist, reshuffled at midnight.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: kTextOnPhotoMuted,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            itemCount: picks.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final restaurant = picks[index];
              return SizedBox(
                width: 148,
                child: RestaurantGridCard(
                  restaurant: restaurant,
                  // The rail has no position of its own; the cuisine tag is
                  // the more useful second line here anyway.
                  distanceText: restaurant.tag,
                  onTap: () => onOpen(restaurant),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

/// One craving: the cuisine's best cover photo under a scrim, the emoji and
/// label on top, the count as the small line under them.
class _CuisineTile extends StatelessWidget {
  const _CuisineTile({required this.cuisine, required this.onTap});

  final CuisineCount cuisine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final coverUrl = cuisine.coverUrl;
    final count = cuisine.restaurantCount;

    return Semantics(
      label: count == 1
          ? '${cuisine.label}, 1 place'
          : '${cuisine.label}, $count places',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kRadiusPanel),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverUrl == null)
                const ColoredBox(color: kSurfacePanel)
              else
                Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: kSurfacePanel),
                ),
              // Text sits straight on the photo, so it needs the same scrim
              // the cards use — and on the plain panel it is harmlessly dark.
              const PhotoBottomScrim(),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cuisine.emoji} ${cuisine.label}'.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appPanelTitleStyle(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 1 ? '1 place' : '$count places',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: kTextOnPhotoMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              // A hairline over the photo keeps the tile edges crisp against
              // the dark background, matching every panel in the app.
              // IgnorePointer for the same reason as RestaurantGridCard: a
              // full-tile overlay must never intercept taps.
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(kRadiusPanel),
                    border: Border.all(color: kHairline),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
