import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/app_lottie.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/empty_state.dart';
import '../../restaurants/models/restaurant.dart';
import '../../restaurants/presentation/restaurant_grid_card.dart';
import '../../restaurants/state/restaurant_list_controller.dart';
import 'dashboard_widgets.dart';

/// Which of the Liked screen's three collections is showing.
enum LikedSegment { liked, visited, reviewed }

/// How the visible grid is ordered. Latest is the backend's order (newest
/// decision first), so it needs no client-side sort at all.
enum LikedSort { latest, nearest, rating }

/// The Liked screen per the Figma: Liked | Visited | Reviewed segments over
/// one two-column photo grid, with a sort dropdown and a filter sheet.
class LikesTabView extends StatefulWidget {
  const LikesTabView({
    super.key,
    required this.liked,
    required this.visitedController,
    required this.reviewedController,
    required this.distanceLabel,
    required this.distanceMeters,
    required this.isSuperLiked,
    required this.onOpenRestaurant,
    required this.onUnlike,
    required this.onMarkVisited,
  });

  /// Liked restaurants, newest first (LikesController's order).
  final List<Restaurant> liked;

  /// Lazily loaded: the view calls ensureLoaded the first time each segment
  /// is shown, so a user who never leaves Liked never pays for the others.
  final RestaurantListController visitedController;
  final RestaurantListController reviewedController;

  final String Function(Restaurant restaurant) distanceLabel;

  /// Metres from the user, or [double.infinity] with no fix — the Nearest
  /// sort's key. Infinity everywhere degrades Nearest to the incoming order,
  /// which is the honest behaviour when nothing is actually nearer.
  final double Function(Restaurant restaurant) distanceMeters;

  final bool Function(int restaurantId) isSuperLiked;
  final void Function(Restaurant restaurant) onOpenRestaurant;
  final void Function(Restaurant restaurant) onUnlike;
  final void Function(Restaurant restaurant) onMarkVisited;

  @override
  State<LikesTabView> createState() => _LikesTabViewState();
}

class _LikesTabViewState extends State<LikesTabView> {
  LikedSegment _segment = LikedSegment.liked;
  LikedSort _sort = LikedSort.latest;

  /// The filter sheet's two switches. Client-side: they narrow what is
  /// already on screen, they do not refetch.
  bool _superOnly = false;
  bool _withVideoOnly = false;

  bool get _filtersActive => _superOnly || _withVideoOnly;

  void _showSegment(LikedSegment segment) {
    setState(() {
      _segment = segment;
    });
    // Fire-and-forget: the controller notifies and the grid rebuilds; a
    // failure surfaces as the segment's error state, not as an unawaited
    // exception here.
    switch (segment) {
      case LikedSegment.visited:
        unawaited(widget.visitedController.ensureLoaded());
      case LikedSegment.reviewed:
        unawaited(widget.reviewedController.ensureLoaded());
      case LikedSegment.liked:
        break;
    }
  }

  List<Restaurant> _visibleRows(List<Restaurant> source) {
    var rows = source;
    if (_superOnly) {
      rows = [
        for (final r in rows)
          if (widget.isSuperLiked(r.id)) r,
      ];
    }
    if (_withVideoOnly) {
      rows = [
        for (final r in rows)
          if (r.videoUrl != null && r.videoUrl!.isNotEmpty) r,
      ];
    }
    switch (_sort) {
      case LikedSort.latest:
        return rows;
      case LikedSort.nearest:
        final sorted = List.of(rows)
          ..sort((a, b) =>
              widget.distanceMeters(a).compareTo(widget.distanceMeters(b)));
        return sorted;
      case LikedSort.rating:
        final sorted = List.of(rows)
          ..sort((a, b) => b.rating.compareTo(a.rating));
        return sorted;
    }
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: kSurfacePanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
      ),
      builder: (sheetContext) {
        // The sheet manages its own copy of the switches so every flip
        // repaints the sheet immediately; the grid updates on the way out.
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void update(void Function() change) {
              setSheetState(change);
              setState(() {});
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filters', style: appPanelTitleStyle(sheetContext)),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: kAccentEmber,
                      title: Text(
                        'Must try only',
                        style: Theme.of(sheetContext).textTheme.bodyMedium,
                      ),
                      value: _superOnly,
                      onChanged: (value) => update(() => _superOnly = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: kAccentEmber,
                      title: Text(
                        'With TikTok review',
                        style: Theme.of(sheetContext).textTheme.bodyMedium,
                      ),
                      value: _withVideoOnly,
                      onChanged: (value) =>
                          update(() => _withVideoOnly = value),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            0,
            AppSpacing.screenPadding,
            10,
          ),
          child: _SegmentControl(
            segment: _segment,
            onSelected: _showSegment,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            0,
            AppSpacing.screenPadding,
            10,
          ),
          child: Row(
            children: [
              _SortButton(
                sort: _sort,
                onSelected: (sort) => setState(() => _sort = sort),
              ),
              const Spacer(),
              AppIconButton(
                icon: Icons.tune_rounded,
                size: kUtilityButtonSize,
                onPhoto: false,
                iconColor: _filtersActive ? kAccentEmber : kTextOnPhoto,
                semanticLabel: 'Filters',
                onTap: () => unawaited(_openFilterSheet()),
              ),
            ],
          ),
        ),
        Expanded(child: _buildSegmentBody()),
      ],
    );
  }

  Widget _buildSegmentBody() {
    switch (_segment) {
      case LikedSegment.liked:
        return _buildLiked();
      case LikedSegment.visited:
        return _buildControllerList(
          widget.visitedController,
          emptyEyebrow: 'Nowhere yet',
          emptyTitle: 'No visits logged',
          emptyMessage: 'When you have actually eaten somewhere, mark it '
              'visited on its Liked card.',
        );
      case LikedSegment.reviewed:
        return _buildControllerList(
          widget.reviewedController,
          emptyEyebrow: 'Nothing written',
          emptyTitle: 'No reviews yet',
          emptyMessage:
              'Reviews you write show up here so you can find them again.',
        );
    }
  }

  Widget _buildLiked() {
    if (widget.liked.isEmpty) {
      return const AppEmptyState(
        eyebrow: 'Nothing saved',
        title: 'No likes yet',
        message:
            'Swipe right on restaurants you love and they will show up here.',
        // One pop on arrival, then still: the tab is waiting for the user,
        // not working.
        art: AppLottie(motion: AppMotion.heart, size: 96, repeat: false),
      );
    }

    return _buildGrid(
      _visibleRows(widget.liked),
      likedActions: true,
    );
  }

  Widget _buildControllerList(
    RestaurantListController controller, {
    required String emptyEyebrow,
    required String emptyTitle,
    required String emptyMessage,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final error = controller.error;
        if (!controller.isLoaded) {
          if (controller.loading) {
            return const Center(
              child: AppLottie(motion: AppMotion.heart, size: 88),
            );
          }
          if (error != null) {
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                EmptyTabMessage(
                  eyebrow: 'List unavailable',
                  title: 'Something went wrong',
                  subtitle: error,
                  actionLabel: 'Try again',
                  onAction: () => unawaited(controller.refresh()),
                ),
              ],
            );
          }
        }

        if (controller.rows.isEmpty) {
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              EmptyTabMessage(
                eyebrow: emptyEyebrow,
                title: emptyTitle,
                subtitle: emptyMessage,
              ),
            ],
          );
        }

        return _buildGrid(_visibleRows(controller.rows), likedActions: false);
      },
    );
  }

  Widget _buildGrid(List<Restaurant> rows, {required bool likedActions}) {
    if (rows.isEmpty) {
      // Non-empty source, empty view: the filters hid everything.
      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          EmptyTabMessage(
            eyebrow: 'Filtered out',
            title: 'Nothing matches your filters',
            subtitle: 'Loosen them to see this list again.',
            actionLabel: 'Clear filters',
            onAction: () => setState(() {
              _superOnly = false;
              _withVideoOnly = false;
            }),
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
        final isSuper = widget.isSuperLiked(restaurant.id);

        return RestaurantGridCard(
          restaurant: restaurant,
          distanceText: widget.distanceLabel(restaurant),
          onTap: () => widget.onOpenRestaurant(restaurant),
          badge: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSuper) ...[
                const _SuperLikeBadge(),
                const SizedBox(width: 6),
              ],
              if (likedActions) ...[
                AppIconButton(
                  icon: Icons.check_rounded,
                  size: 30,
                  semanticLabel: 'Mark visited',
                  onTap: () => widget.onMarkVisited(restaurant),
                ),
                const SizedBox(width: 6),
                AppIconButton(
                  icon: Icons.favorite_rounded,
                  size: 30,
                  iconColor: kAccentEmber,
                  semanticLabel: 'Remove from likes',
                  onTap: () => widget.onUnlike(restaurant),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// The ember star in a grid card's corner: this like was a "must try".
class _SuperLikeBadge extends StatelessWidget {
  const _SuperLikeBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Must try',
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: kAccentEmber,
          borderRadius: BorderRadius.circular(kRadiusPill),
        ),
        child: const Icon(Icons.star_rounded, size: 18, color: kOnAccent),
      ),
    );
  }
}

/// Liked | Visited | Reviewed. One container, the active segment filled
/// cream the way the primary button is.
class _SegmentControl extends StatelessWidget {
  const _SegmentControl({required this.segment, required this.onSelected});

  final LikedSegment segment;
  final ValueChanged<LikedSegment> onSelected;

  static const _labels = {
    LikedSegment.liked: 'Liked',
    LikedSegment.visited: 'Visited',
    LikedSegment.reviewed: 'Reviewed',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kSurfacePanel,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: kHairline),
      ),
      child: Row(
        children: [
          for (final value in LikedSegment.values)
            Expanded(
              child: _SegmentPill(
                label: _labels[value]!,
                selected: value == segment,
                onTap: () => onSelected(value),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? kAccentCream : Colors.transparent,
            borderRadius: BorderRadius.circular(kRadiusPill),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? kOnAccent : kTextOnPhotoSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

/// "Latest ▾" — the sort menu, styled as the secondary button.
class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onSelected});

  final LikedSort sort;
  final ValueChanged<LikedSort> onSelected;

  static const _labels = {
    LikedSort.latest: 'Latest',
    LikedSort.nearest: 'Nearest',
    LikedSort.rating: 'Top rated',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<LikedSort>(
      onSelected: onSelected,
      color: kSurfacePanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusPanel),
        side: const BorderSide(color: kHairline),
      ),
      itemBuilder: (context) => [
        for (final value in LikedSort.values)
          PopupMenuItem(
            value: value,
            child: Text(
              _labels[value]!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: value == sort ? kAccentEmber : kTextOnPhoto,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
      ],
      child: Container(
        height: kUtilityButtonSize,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: kSurfacePanel,
          borderRadius: BorderRadius.circular(kRadiusPill),
          border: Border.all(color: kHairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _labels[sort]!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: kTextOnPhoto,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down_rounded,
              color: kTextOnPhoto,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
