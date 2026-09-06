import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_lottie.dart';
import '../../../core/ui/app_spacing.dart';
import '../../restaurants/models/restaurant.dart';
import '../../restaurants/models/restaurant_card.dart';
// `toDetailPayload` is an extension on RestaurantCard and lives here.
import '../../plans/state/plans_controller.dart';
import '../../restaurants/models/restaurant_detail_data.dart';
import '../../restaurants/state/likes_controller.dart';
import 'dashboard_widgets.dart';
import 'likes_tab_view.dart';

/// The places the user has bitten, filtered by the design's chip row.
class LikesTab extends StatefulWidget {
  const LikesTab({super.key, this.plans});

  /// The calendar the "Planned" chips and the tiles' day badges read.
  /// Injected by tests; in the app the shared instance is used.
  final PlansController? plans;

  @override
  State<LikesTab> createState() => _LikesTabState();
}

class _LikesTabState extends State<LikesTab> {
  // The swipes table is the source of truth; LikesController caches it and
  // notifies when a like lands anywhere in the app (deck, detail page).
  String? _error;

  late final PlansController _plans = widget.plans ?? PlansController.instance;

  @override
  void initState() {
    super.initState();
    LikesController.instance.addListener(_onLikesChanged);
    // The chips filter on the calendar, so the tab has to hear about a plan
    // made anywhere else in the app.
    _plans.addListener(_onLikesChanged);
    unawaited(_loadLikes());
  }

  @override
  void dispose() {
    LikesController.instance.removeListener(_onLikesChanged);
    _plans.removeListener(_onLikesChanged);
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
        _error = 'Could not load your bites.';
      });
    }
  }

  void _openRestaurant(Restaurant restaurant) {
    context.push(
      '/restaurant/${restaurant.id}',
      extra: RestaurantCard.fromRestaurant(restaurant).toDetailPayload(),
    );
  }

  /// The Wishlist chip. The refresh on the way back is the whole reason this
  /// awaits the push: crossing a place off over there clears its bookmark
  /// here, and the tab would otherwise keep showing a badge for a place the
  /// user has already eaten.
  Future<void> _openWishlist() async {
    await context.push<void>('/wishlist');
    if (!mounted) {
      return;
    }
    unawaited(
      LikesController.instance.refresh().catchError((Object error) {
        debugPrint('Refreshing bites after the wishlist failed: $error');
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final likes = LikesController.instance;
    final error = _error;

    final saved = likes.liked.length;

    return DashboardTabShell(
      title: 'Your bites',
      // The design's header is the title over a count, with no eyebrow. The
      // count is only honest once the list has actually loaded.
      subtitle: likes.isLoaded
          ? (saved == 1 ? '1 saved' : '$saved saved')
          : null,
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
                      eyebrow: 'Bites unavailable',
                      title: 'Something went wrong',
                      subtitle: error,
                      actionLabel: 'Try again',
                      onAction: () => unawaited(_loadLikes()),
                    ),
                  ],
                ))
          : LikesTabView(
              liked: likes.liked,
              wishlistedIds: {
                for (final restaurant in likes.liked)
                  if (likes.isSavedForLater(restaurant.id)) restaurant.id,
              },
              plannedIds: _plans.plannedRestaurantIds,
              plannedLabels: _plans.plannedLabels,
              onOpenRestaurant: _openRestaurant,
              onOpenWishlist: () => unawaited(_openWishlist()),
            ),
    );
  }
}
