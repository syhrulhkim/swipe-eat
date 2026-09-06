import 'package:flutter/material.dart';

import '../../../core/ui/app_lottie.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/empty_state.dart';
import '../../restaurants/models/restaurant.dart';
import '../../restaurants/presentation/restaurant_grid_card.dart';
import 'dashboard_widgets.dart';

/// Which of the design's filters is on. Three of the five chips are the same
/// question asked three ways — has this place got a date yet? — so they are
/// one enum rather than three booleans that can contradict each other.
///
/// Halal is separate because it narrows any of the three, and the Wishlist
/// chip is not here at all: it navigates, so it holds no state to be in.
enum BitesPlanFilter { all, notPlanned, planned }

/// The Bites tab: the design's chip row over one two-column photo grid.
///
/// The Liked | Visited | Reviewed segments are gone (D96). Visited and
/// Reviewed were bookkeeping the design does not ask for; what it asks for is
/// "which of my saved places have I actually got a date for", which is what
/// these chips answer.
class LikesTabView extends StatefulWidget {
  const LikesTabView({
    super.key,
    required this.liked,
    required this.onOpenRestaurant,
    required this.onOpenWishlist,
    this.wishlistedIds = const {},
    this.plannedIds = const {},
    this.plannedLabels = const {},
  });

  /// Liked restaurants, newest like first (LikesController's order).
  final List<Restaurant> liked;

  final void Function(Restaurant restaurant) onOpenRestaurant;

  /// The "Wishlist →" chip. A navigation, not a filter.
  final VoidCallback onOpenWishlist;

  /// Which tiles carry the bookmark badge.
  final Set<int> wishlistedIds;

  /// Which tiles the Planned / Not planned yet chips consider planned. Empty
  /// until the plans phase feeds it, at which point both chips start working
  /// with no change here.
  final Set<int> plannedIds;

  /// The day label a planned tile shows ("Fri 4"). Empty for now, for the same
  /// reason.
  final Map<int, String> plannedLabels;

  @override
  State<LikesTabView> createState() => _LikesTabViewState();
}

class _LikesTabViewState extends State<LikesTabView> {
  BitesPlanFilter _plan = BitesPlanFilter.all;
  bool _halalOnly = false;

  bool get _filtersActive =>
      _plan != BitesPlanFilter.all || _halalOnly;

  List<Restaurant> get _visibleRows {
    return [
      for (final restaurant in widget.liked)
        if (_matches(restaurant)) restaurant,
    ];
  }

  bool _matches(Restaurant restaurant) {
    // Null `isHalal` means the caption never said, which is not the same as
    // "no" — but a Halal filter that returns maybes is not a filter, so only a
    // stated yes passes.
    if (_halalOnly && restaurant.isHalal != true) {
      return false;
    }
    final isPlanned = widget.plannedIds.contains(restaurant.id);

    return switch (_plan) {
      BitesPlanFilter.all => true,
      BitesPlanFilter.planned => isPlanned,
      BitesPlanFilter.notPlanned => !isPlanned,
    };
  }

  void _selectPlan(BitesPlanFilter value) {
    setState(() {
      // Tapping the chip that is already on turns it off, back to All. Without
      // that there is no way out of a filter except finding All again.
      _plan = _plan == value ? BitesPlanFilter.all : value;
    });
  }

  void _clearFilters() {
    setState(() {
      _plan = BitesPlanFilter.all;
      _halalOnly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChipRow(
          plan: _plan,
          halalOnly: _halalOnly,
          onSelectPlan: _selectPlan,
          onToggleHalal: () => setState(() => _halalOnly = !_halalOnly),
          onOpenWishlist: widget.onOpenWishlist,
        ),
        Expanded(child: _buildGrid()),
      ],
    );
  }

  Widget _buildGrid() {
    if (widget.liked.isEmpty) {
      return const AppEmptyState(
        eyebrow: 'Nothing saved',
        title: 'No bites yet',
        message: 'Ngap the places you want and they land here.',
        // One pop on arrival, then still: the tab is waiting for the user,
        // not working.
        art: AppLottie(motion: AppMotion.heart, size: 96, repeat: false),
      );
    }

    final rows = _visibleRows;
    if (rows.isEmpty) {
      // Non-empty source, empty view: the chips hid everything.
      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          EmptyTabMessage(
            eyebrow: 'Filtered out',
            title: 'Nothing matches those chips',
            subtitle: 'Loosen them to see the rest of your bites.',
            actionLabel: 'Show all',
            onAction: _clearFilters,
          ),
        ],
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        0,
        AppSpacing.screenPadding,
        AppSpacing.screenPadding,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final restaurant = rows[index];

        return RestaurantGridCard(
          restaurant: restaurant,
          // The tile shows cuisine and neighbourhood now; this is only the
          // fallback for a row with neither.
          distanceText: '',
          onTap: () => widget.onOpenRestaurant(restaurant),
          // Every tile here is a place the user saved, so all of them are
          // bitten.
          isSaved: true,
          isWishlisted: widget.wishlistedIds.contains(restaurant.id),
          plannedLabel: widget.plannedLabels[restaurant.id],
        );
      },
    );
  }

  @override
  void didUpdateWidget(LikesTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A list that emptied under a filter would otherwise show "filtered out"
    // over nothing at all.
    if (widget.liked.isEmpty && _filtersActive) {
      _plan = BitesPlanFilter.all;
      _halalOnly = false;
    }
  }
}

/// The design's `.chiprow`: five pills, scrolling sideways, bleeding to both
/// screen edges so the row reads as continuing past them.
class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.plan,
    required this.halalOnly,
    required this.onSelectPlan,
    required this.onToggleHalal,
    required this.onOpenWishlist,
  });

  final BitesPlanFilter plan;
  final bool halalOnly;
  final ValueChanged<BitesPlanFilter> onSelectPlan;
  final VoidCallback onToggleHalal;
  final VoidCallback onOpenWishlist;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        0,
        AppSpacing.screenPadding,
        10,
      ),
      child: Row(
        children: [
          AppFilterChip(
            label: 'All',
            selected: plan == BitesPlanFilter.all,
            onTap: () => onSelectPlan(BitesPlanFilter.all),
          ),
          const SizedBox(width: 8),
          AppFilterChip(
            label: 'Not planned yet',
            selected: plan == BitesPlanFilter.notPlanned,
            onTap: () => onSelectPlan(BitesPlanFilter.notPlanned),
          ),
          const SizedBox(width: 8),
          AppFilterChip(
            label: 'Planned',
            selected: plan == BitesPlanFilter.planned,
            onTap: () => onSelectPlan(BitesPlanFilter.planned),
          ),
          const SizedBox(width: 8),
          // Never pressed: it leaves for another screen rather than narrowing
          // this one, and a chip that stays lit after taking you away is
          // claiming to be a filter it is not.
          AppFilterChip(
            label: 'Wishlist →',
            selected: false,
            onTap: onOpenWishlist,
          ),
          const SizedBox(width: 8),
          AppFilterChip(
            label: 'Halal',
            selected: halalOnly,
            onTap: onToggleHalal,
          ),
        ],
      ),
    );
  }
}
