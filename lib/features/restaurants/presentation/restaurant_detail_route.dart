import 'package:flutter/material.dart';

import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../data/restaurant_repository.dart';
import '../models/restaurant_detail_data.dart';
import 'restaurant_detail_page.dart';

/// The `/restaurant/:id` route.
///
/// A tap from a card already holds everything the page paints, so it travels
/// as [initialData] and the page appears with no wait. A link — a deep link, a
/// restored route — has only the id, so the row is fetched, and an id that
/// resolves to nothing says so instead of showing an empty page.
class RestaurantDetailRoute extends StatefulWidget {
  const RestaurantDetailRoute({
    super.key,
    required this.restaurantId,
    this.initialData,
    this.repository,
  });

  /// Null when the URL carried something that is not an id at all.
  final int? restaurantId;

  final RestaurantDetailData? initialData;

  /// Injected by tests; in the app the route builds its own.
  final RestaurantRepository? repository;

  @override
  State<RestaurantDetailRoute> createState() => _RestaurantDetailRouteState();
}

class _RestaurantDetailRouteState extends State<RestaurantDetailRoute> {
  late final RestaurantRepository _repository =
      widget.repository ?? RestaurantRepository();

  RestaurantDetailData? _data;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    if (_data == null && widget.restaurantId != null) {
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.restaurantId;
    if (id == null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final restaurant = await _repository.fetchById(id);
      if (!mounted) {
        return;
      }

      setState(() {
        _data = restaurant == null
            ? null
            : RestaurantDetailData.fromRestaurant(restaurant);
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data != null) {
      return RestaurantDetailPage(data: data);
    }

    if (_loading) {
      return const _DetailPlaceholder(
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_error != null) {
      return _DetailPlaceholder(
        child: _DetailMessage(
          title: 'Could not open this restaurant',
          subtitle: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: _load,
        ),
      );
    }

    return const _DetailPlaceholder(
      child: _DetailMessage(
        title: 'Restaurant not found',
        subtitle: 'It may have closed or been removed from the catalog.',
      ),
    );
  }
}

/// The page's chrome without the page: the same dark ground and a way back.
class _DetailPlaceholder extends StatelessWidget {
  const _DetailPlaceholder({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      body: Stack(
        children: [
          Positioned.fill(child: child),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Align(
                alignment: Alignment.topLeft,
                child: AppCircleButton(
                  icon: Icons.arrow_back_rounded,
                  size: kUtilityButtonSize,
                  semanticLabel: 'Back',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.64),
                    height: 1.35,
                  ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: kAccentEmber),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
