// ignore_for_file: unused_element_parameter

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../core/location/open_directions.dart';
import '../../../core/location/place_name.dart';
import '../../../core/location/user_location.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/glass_ui.dart';
import '../../../core/ui/preference_tile.dart';
import '../../../core/ui/rating_label.dart';
import '../../../core/ui/tiktok_thumbnail_placeholder.dart';
import '../../auth/state/auth_controller.dart';
import '../../auth/models/app_user.dart';
import '../../profile/data/profile_repository.dart';
import '../../quiz/data/quiz_repository.dart';
import '../../quiz/models/quiz_question.dart';
import '../../restaurants/data/likes_migration.dart';
import '../../restaurants/data/restaurant_repository.dart';
import '../../restaurants/data/swipe_repository.dart';
import '../../restaurants/models/restaurant.dart';
import '../../restaurants/state/likes_controller.dart';
import 'explore_map_view.dart';
import 'likes_tab_view.dart';

_SwipeCardData _swipeCardDataFromRestaurant(Restaurant restaurant) {
  final reviews = restaurant.reviews
      .where((review) => review.text.trim().isNotEmpty)
      .map(
        (review) => _ReviewSnippet(author: review.author, text: review.text),
      )
      .toList();

  return _SwipeCardData(
    id: restaurant.id,
    title: restaurant.name,
    tag: restaurant.tag,
    details: restaurant.details,
    color: restaurant.brandColor,
    rating: restaurant.rating,
    latitude: restaurant.latitude,
    longitude: restaurant.longitude,
    reviewName: reviews.isNotEmpty ? reviews.first.author : '',
    reviewText: reviews.isNotEmpty ? reviews.first.text : '',
    reviews: reviews,
    imageUrls: restaurant.imageUrls,
    videoUrl: restaurant.videoUrl,
  );
}

mixin _UserPositionState<T extends StatefulWidget> on State<T> {
  Position? _userPosition;

  void _resolveUserPosition() {
    resolveUserPosition().then((position) {
      if (!mounted) {
        return;
      }

      setState(() {
        _userPosition = position;
      });
    });
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.authController,
  });

  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: authController,
      builder: (context, _) {
        final scaffoldStyle = context.theme.scaffoldStyle.copyWith(
          footerDecoration: const DecorationDelta.value(
            BoxDecoration(color: Colors.transparent),
          ),
        );

        return _DashboardShell(
          scaffoldStyle: scaffoldStyle,
          authController: authController,
        );
      },
    );
  }
}

class _DashboardShell extends StatefulWidget {
  const _DashboardShell({
    required this.scaffoldStyle,
    required this.authController,
  });

  final FScaffoldStyle scaffoldStyle;
  final AuthController authController;

  @override
  State<_DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<_DashboardShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // One-time move of pre-auth device likes into the swipes table. Never
    // blocks the dashboard; a failed run retries on the next launch.
    unawaited(migrateDeviceLikes().then((migrated) {
      if (migrated) {
        LikesController.instance.refresh().catchError((Object error) {
          debugPrint('Post-migration likes refresh failed: $error');
        });
      }
    }));
  }

  void _setSelectedIndex(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      scaffoldStyle: widget.scaffoldStyle,
      childPad: false,
      footer: _DashboardBottomNav(
        selectedIndex: _selectedIndex,
        onSelected: _setSelectedIndex,
      ),
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          _SwipeDeck(authController: widget.authController),
          _ExploreTab(authController: widget.authController),
          const _LikesTab(),
          const _QuizTab(),
          _ProfileTab(
            user: widget.authController.user,
          ),
        ],
      ),
    );
  }
}

class _DashboardBottomNav extends StatelessWidget {
  const _DashboardBottomNav({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        // No BackdropFilter here: FScaffold lays the footer out below the
        // body, so there is nothing behind the pill to blur — an opaque-ish
        // fill gives the same look without the wasted render pass.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kRadiusPill),
          child: Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: kSurfaceDark.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(kRadiusPill),
              border: Border.all(color: kGlassBorder),
            ),
            child: Row(
              children: [
                _BottomNavItem(
                  icon: Icons.swipe_rounded,
                  label: 'Swipe',
                  isSelected: selectedIndex == 0,
                  onTap: () => onSelected(0),
                ),
                _BottomNavItem(
                  icon: Icons.explore_rounded,
                  label: 'Explore',
                  isSelected: selectedIndex == 1,
                  onTap: () => onSelected(1),
                ),
                _BottomNavItem(
                  icon: Icons.favorite_rounded,
                  label: 'Like',
                  isSelected: selectedIndex == 2,
                  onTap: () => onSelected(2),
                ),
                _BottomNavItem(
                  icon: Icons.quiz_rounded,
                  label: 'Quiz',
                  isSelected: selectedIndex == 3,
                  onTap: () => onSelected(3),
                ),
                _BottomNavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: selectedIndex == 4,
                  onTap: () => onSelected(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatefulWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Semantics(
          label: widget.label,
          button: true,
          selected: widget.isSelected,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onTapDown: (_) {
              setState(() {
                _pressed = true;
              });
              HapticFeedback.selectionClick();
            },
            onTapCancel: () {
              setState(() {
                _pressed = false;
              });
            },
            onTapUp: (_) {
              setState(() {
                _pressed = false;
              });
            },
            child: AnimatedScale(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              scale: _pressed ? 0.92 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? kAccentLime
                      : Colors.white.withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isSelected
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Icon(
                  widget.icon,
                  size: 26,
                  color: widget.isSelected ? kOnAccentLime : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreTab extends StatefulWidget {
  const _ExploreTab({required this.authController});

  final AuthController authController;

  @override
  State<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<_ExploreTab> with _UserPositionState {
  List<Restaurant> _restaurants = const [];
  bool _loading = true;
  String? _error;

  /// The radius the rows on screen were fetched under. The tabs live in an
  /// IndexedStack that never re-inits, so a Settings change must be listened
  /// for — the radius is a server-side filter, and stale rows would break
  /// its promise that out-of-range places are not shown.
  late int? _appliedRadiusKm = widget.authController.user?.searchRadiusKm;

  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_onAuthChanged);
    _resolveUserPosition();
    _loadSpots();
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final radius = widget.authController.user?.searchRadiusKm;
    if (radius == _appliedRadiusKm) {
      return;
    }
    _appliedRadiusKm = radius;
    _loadSpots();
  }

  Future<void> _loadSpots() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // The radius rule lives server-side: what the deck may not serve,
      // Explore may not show. A fallback fix is not a real location — passing
      // null lets the RPC measure from the profile's stored coordinates.
      final position = await resolveUserPosition();
      final hasRealPosition = !isFallbackUserPosition(position);
      final restaurants = await RestaurantRepository().search(
        latitude: hasRealPosition ? position.latitude : null,
        longitude: hasRealPosition ? position.longitude : null,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _restaurants = restaurants;
        _loading = false;
      });
    } catch (error) {
      debugPrint('Explore load failed: $error');
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
      '/restaurant',
      extra: _swipeCardDataFromRestaurant(restaurant).toDetailPayload(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _error != null || _restaurants.isEmpty) {
      return _DashboardTabShell(
        title: 'Explore',
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  _error != null
                      ? _EmptyTabMessage(
                          title: 'Something went wrong',
                          subtitle: _error!,
                          actionLabel: 'Try again',
                          onAction: _loadSpots,
                        )
                      : const _EmptyTabMessage(
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
        restaurants: _restaurants,
        userPosition: _userPosition,
        onOpenRestaurant: _openRestaurant,
      ),
    );
  }
}

class _LikesTab extends StatefulWidget {
  const _LikesTab();

  @override
  State<_LikesTab> createState() => _LikesTabState();
}

class _LikesTabState extends State<_LikesTab> with _UserPositionState {
  // The swipes table is the source of truth; LikesController caches it and
  // notifies when a like lands anywhere in the app (deck, detail page).
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolveUserPosition();
    LikesController.instance.addListener(_onLikesChanged);
    _loadLikes();
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
    } catch (error) {
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
    } catch (error) {
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
    final userPosition = _userPosition;
    if (userPosition == null ||
        (restaurant.latitude == 0 && restaurant.longitude == 0)) {
      return 'Johor Bahru';
    }

    final meters = Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
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
      '/restaurant',
      extra: _swipeCardDataFromRestaurant(restaurant).toDetailPayload(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final likes = LikesController.instance;
    if (!likes.isLoaded || _error != null) {
      return _DashboardTabShell(
        title: 'Like',
        child: _error == null
            ? const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  _EmptyTabMessage(
                    title: 'Something went wrong',
                    subtitle: _error!,
                    actionLabel: 'Try again',
                    onAction: _loadLikes,
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

class _QuizTab extends StatefulWidget {
  const _QuizTab();

  @override
  State<_QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<_QuizTab> {
  QuizQuestion? _question;
  bool _loading = true;
  String? _error;
  int _selectedOptionId = -1;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final question = await QuizRepository().fetchActiveQuestion();
      if (!mounted) {
        return;
      }

      setState(() {
        _question = question;
        _loading = false;
      });
    } catch (error) {
      debugPrint('Quiz load failed: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Could not load the quiz.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = _question;
    QuizOption? selectedOption;
    if (question != null) {
      for (final option in question.options) {
        if (option.id == _selectedOptionId) {
          selectedOption = option;
        }
      }
    }

    return _DashboardTabShell(
      title: 'Quiz',
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          14,
          AppSpacing.screenPadding,
          24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_error != null)
              _EmptyTabMessage(
                title: 'Something went wrong',
                subtitle: _error!,
                actionLabel: 'Try again',
                onAction: _loadQuiz,
              )
            else if (question == null || question.options.isEmpty)
              const _EmptyTabMessage(
                title: 'No quiz available',
                subtitle: 'Check back soon.',
              )
            else ...[
              Text(
                question.prompt,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.64),
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 12),
              ...question.options.map((option) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _QuizAnswerTile(
                    label: option.label,
                    selected: option.id == _selectedOptionId,
                    onTap: () {
                      setState(() {
                        _selectedOptionId = option.id;
                      });
                    },
                  ),
                );
              }),
              const SizedBox(height: 14),
              if (selectedOption != null)
                _QuizResultCard(
                  title: selectedOption.resultTitle,
                  subtitle: selectedOption.recommendedRestaurantName ?? 'None',
                  body: selectedOption.resultBody,
                  accent: selectedOption.resultAccent,
                )
              else
                Text(
                  'Select an answer above to get a suggestion.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.60),
                      ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.user,
  });

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? 'Guest';
    final email = user?.email ?? 'Sign in to sync your picks';

    return _DashboardTabShell(
      title: 'Profile',
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          14,
          AppSpacing.screenPadding,
          24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SimpleProfileCard(
              name: name,
              email: email,
            ),
            const SizedBox(height: 12),
            const PreferenceTile(
              icon: Icons.wb_sunny_rounded,
              title: 'Morning mode',
              subtitle: 'Show breakfast first',
              trailingLabel: 'On',
              tint: Color(0xFFF6D365),
            ),
            const SizedBox(height: 10),
            const PreferenceTile(
              icon: Icons.local_fire_department_rounded,
              title: 'Spice bias',
              subtitle: 'Prioritize bolder flavors',
              trailingLabel: 'High',
              tint: Color(0xFFE76F51),
            ),
            const SizedBox(height: 10),
            const PreferenceTile(
              icon: Icons.pin_drop_rounded,
              title: 'Nearby focus',
              subtitle: 'Favor shorter distances',
              trailingLabel: 'On',
              tint: Color(0xFFB7E4C7),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTabShell extends StatelessWidget {
  const _DashboardTabShell({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: kBackgroundDark),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                18,
                AppSpacing.screenPadding,
                12,
              ),
              child: _TabTopBar(
                title: title,
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _TabTopBar extends StatelessWidget {
  const _TabTopBar({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.35,
              ),
        ),
      ),
    );
  }
}

class _SimpleCard extends StatelessWidget {
  const _SimpleCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusPanel),
      child: Container(
        decoration: BoxDecoration(
          color: kSurfacePanel,
          borderRadius: BorderRadius.circular(kRadiusPanel),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _SimpleProfileCard extends StatelessWidget {
  const _SimpleProfileCard({
    required this.name,
    required this.email,
  });

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return _SimpleCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: glassPanelTitleStyle(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizAnswerTile extends StatelessWidget {
  const _QuizAnswerTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected
        ? const Color(0xFFB7E4C7)
        : Colors.white.withValues(alpha: 0.10);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusPanel),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(kRadiusPanel),
            border: Border.all(
                color: accent.withValues(alpha: selected ? 0.42 : 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: selected ? accent : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? accent
                        : Colors.white.withValues(alpha: 0.24),
                  ),
                  shape: BoxShape.circle,
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        size: 13, color: Colors.black)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
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

class _QuizResultCard extends StatelessWidget {
  const _QuizResultCard({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      accent: accent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.12,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.74),
                    height: 1.35,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTabMessage extends StatelessWidget {
  const _EmptyTabMessage({
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
    return _SimpleCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: glassPanelTitleStyle(context),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.66),
                    height: 1.35,
                  ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              FButton(
                variant: FButtonVariant.outline,
                onPress: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SwipeDeck extends StatefulWidget {
  const _SwipeDeck({required this.authController});

  final AuthController authController;

  @override
  State<_SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<_SwipeDeck>
    with SingleTickerProviderStateMixin, _UserPositionState {
  List<_SwipeCardData> _cards = const [];
  bool _deckLoading = true;
  String? _deckError;

  int _index = 0;
  Offset _dragOffset = Offset.zero;
  bool _infoExpanded = false;
  bool _reviewInteractionActive = false;
  Offset _animationStartOffset = Offset.zero;
  Offset _animationEndOffset = Offset.zero;
  _SwipeMotionType _motionType = _SwipeMotionType.idle;

  late final AnimationController _motionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  )..addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) {
        return;
      }

      setState(() {
        if (_motionType == _SwipeMotionType.swipeOut) {
          _index += 1;
        }

        _dragOffset = Offset.zero;
        _infoExpanded = false;
        _reviewInteractionActive = false;
        _motionType = _SwipeMotionType.idle;
      });

      _motionController.reset();
    });
  final Map<String, Future<WebViewController>> _tiktokPlayerCache = {};

  /// Guards against overlapping [_loadDeck] runs (init + retry buttons): only
  /// the newest request may publish its result, so a stale slow response can
  /// never overwrite a fresher deck.
  int _deckLoadGeneration = 0;

  /// The radius the current deck was dealt under — see the twin field on
  /// [_ExploreTabState] for why a Settings change must reload from here.
  late int? _appliedRadiusKm =
      widget.authController.user?.searchRadiusKm;

  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_onAuthChanged);
    _resolveUserPosition();
    _loadDeck();
  }

  void _onAuthChanged() {
    final radius = widget.authController.user?.searchRadiusKm;
    if (radius == _appliedRadiusKm) {
      return;
    }
    _appliedRadiusKm = radius;
    _loadDeck();
  }

  Future<void> _loadDeck() async {
    final generation = ++_deckLoadGeneration;
    setState(() {
      _deckLoading = true;
      _deckError = null;
    });

    try {
      // The position is an input to the server-side ranking now, so it is
      // resolved first. It is session-cached, so only the very first load
      // pays for the permission dialog + GPS fix. The fallback position is
      // not a real fix — passing null lets the RPC fall back to the profile's
      // stored coordinates instead of ranking around a bogus origin.
      final position = await resolveUserPosition();
      final hasRealPosition = !isFallbackUserPosition(position);
      if (hasRealPosition) {
        // Fire-and-forget: the deck must not wait on reverse geocoding.
        unawaited(_syncLocation(position));
      }

      // Ranked, radius-filtered and de-duplicated against past swipes by the
      // get_deck RPC; the rows arrive in serve order.
      final restaurants = await RestaurantRepository().fetchDeck(
        latitude: hasRealPosition ? position.latitude : null,
        longitude: hasRealPosition ? position.longitude : null,
      );
      if (!mounted || generation != _deckLoadGeneration) {
        return;
      }

      setState(() {
        _cards = restaurants.map(_swipeCardDataFromRestaurant).toList();
        _index = 0;
        _deckLoading = false;
        _tiktokPlayerCache.clear();
      });
      _warmInitialTikTokPlayers();
    } catch (error) {
      debugPrint('Deck load failed: $error');
      if (!mounted || generation != _deckLoadGeneration) {
        return;
      }

      setState(() {
        _deckLoading = false;
        _deckError = 'Could not load restaurants. Check your connection.';
      });
    }
  }

  /// Pushes a real fix (and its reverse-geocoded name) onto the profile, so
  /// the header chip and every server-side radius rule agree on where the
  /// user is. The returned profile row feeds [AuthController.applyUser],
  /// which is what swaps the chip from the stale name to the current one.
  Future<void> _syncLocation(Position position) async {
    try {
      final placeName = await resolvePlaceName(position);
      final user = await ProfileRepository().updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        placeName: placeName,
      );
      if (!mounted) {
        return;
      }
      widget.authController.applyUser(user);
    } catch (error) {
      // The chip keeps the last stored name; nothing else depends on this.
      debugPrint('Location sync failed: $error');
    }
  }

  void _warmInitialTikTokPlayers() {
    for (final card in _cards.take(5)) {
      final videoUrl = card.videoUrl;
      if (videoUrl == null || videoUrl.isEmpty) {
        continue;
      }

      _preloadTikTokPlayer(videoUrl);
    }
  }

  void _warmNeighborTikTokPlayers() {
    for (var offset = 0; offset < 3; offset++) {
      final index = _index + offset;
      if (index < 0 || index >= _cards.length) {
        continue;
      }

      final videoUrl = _cards[index].videoUrl;
      if (videoUrl == null || videoUrl.isEmpty) {
        continue;
      }

      _preloadTikTokPlayer(videoUrl);
    }
  }

  Future<WebViewController>? _preloadTikTokPlayer(String? videoUrl) {
    if (videoUrl == null || videoUrl.isEmpty) {
      return null;
    }

    return _tiktokPlayerCache.putIfAbsent(
      videoUrl,
      () {
        final future = _createTikTokPlayerController(videoUrl);
        // A warmed player nobody has mounted yet has no listener, so a load
        // failure would surface as an unhandled async error. The FutureBuilder
        // that mounts later still sees the error through its own listener.
        unawaited(future.then((_) {}, onError: (Object error) {
          debugPrint('TikTok player load failed: $error');
        }));
        return future;
      },
    );
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthChanged);
    _motionController.dispose();
    super.dispose();
  }

  void _handleLike() => _animateOut(true);
  void _handleDislike() => _animateOut(false);

  void _animateOut(bool liked) {
    if (_index >= _cards.length || _motionType != _SwipeMotionType.idle) {
      return;
    }

    // Optimistic: the card flies out immediately, the write follows behind
    // it. A failed write costs a toast and nothing else — the backend never
    // saw the swipe, so the card simply resurfaces on a future deck.
    unawaited(_recordSwipe(_cards[_index], liked));

    setState(() {
      _motionType = _SwipeMotionType.swipeOut;
      _animationStartOffset = _dragOffset;
      _animationEndOffset = Offset(liked ? 460 : -460, -220);
    });

    _motionController.forward(from: 0);
  }

  Future<void> _recordSwipe(_SwipeCardData card, bool liked) async {
    final position = _userPosition;
    final hasRealPosition =
        position != null && !isFallbackUserPosition(position);
    final latitude = hasRealPosition ? position.latitude : null;
    final longitude = hasRealPosition ? position.longitude : null;

    try {
      if (liked) {
        // Through the controller so the Like tab and any open detail page
        // update without their own round trip.
        await LikesController.instance.like(
          card.id,
          latitude: latitude,
          longitude: longitude,
        );
      } else {
        await SwipeRepository().record(
          restaurantId: card.id,
          liked: false,
          latitude: latitude,
          longitude: longitude,
        );
      }
    } catch (error) {
      debugPrint('Swipe write failed: $error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that swipe.')),
      );
    }
  }

  void _triggerAction(bool liked) {
    if (_index >= _cards.length || _motionType != _SwipeMotionType.idle) {
      return;
    }

    setState(() {
      _motionController.stop();
      _motionType = _SwipeMotionType.idle;
      _dragOffset = Offset(liked ? 14 : -14, -1);
    });

    _animateOut(liked);
  }

  Future<void> _openVideoPlayer(_SwipeCardData data) async {
    final videoUrl = data.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _TikTokPlayerScreen(videoUrl: videoUrl);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  String _ratingText(_SwipeCardData data) {
    return ratingLabel(data.rating);
  }

  String _distanceLabelFor(_SwipeCardData data) {
    final userPosition = _userPosition;
    if (userPosition == null) {
      return 'Distance loading';
    }

    if (!hasMapFix(data.latitude, data.longitude)) {
      // Measuring to the 0,0 sentinel reports the distance to Null Island,
      // which reads as a real answer.
      return 'Distance unknown';
    }

    final meters = Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
      data.latitude,
      data.longitude,
    );

    if (meters >= 100000) {
      return '100km +';
    }
    final km = meters / 1000;
    if (km > 100) {
      return '100km +';
    }

    return '${km.toStringAsFixed(1)} km';
  }

  /// Card pose for the frame being painted.
  ///
  /// [_motionController] ticks without calling `setState`, so these values MUST
  /// be read inside an [AnimatedBuilder] listening to it. Deriving them once in
  /// `build` freezes the card at its release pose for the whole 640 ms and then
  /// teleports it.
  _MotionFrame _motionFrame() {
    final progress = Curves.easeInOutCubic.transform(_motionController.value);
    final offset = _motionType == _SwipeMotionType.idle
        ? _dragOffset
        : ui.Offset.lerp(
              _animationStartOffset,
              _animationEndOffset,
              progress,
            ) ??
            _dragOffset;
    final dragPercentage = (offset.dx.abs() / 260).clamp(0.0, 1.0);

    return _MotionFrame(
      progress: progress,
      offset: offset,
      dragPercentage: dragPercentage,
      lift: Curves.easeOutCubic.transform(dragPercentage),
    );
  }

  void _setReviewInteractionActive(bool active) {
    if (_reviewInteractionActive == active) {
      return;
    }

    setState(() {
      _reviewInteractionActive = active;
    });
  }

  /// What the header chip says. The reverse-geocoded name of the last stored
  /// fix when there is one; 'Nearby' for accounts that have never granted
  /// location. `DashboardPage` rebuilds on every AuthController notification,
  /// so [_syncLocation]'s applyUser refreshes this without a listener here.
  String get _locationLabel =>
      widget.authController.user?.lastPlaceName ?? 'Nearby';

  // Keeps the floating header visible around the loading/error/empty states
  // so those states aren't a bare widget on an otherwise blank tab.
  Widget _deckMessage(Widget child) {
    return Stack(
      children: [
        Center(child: child),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _FloatingHeader(locationLabel: _locationLabel),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_deckLoading) {
      return _deckMessage(
        const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final deckError = _deckError;
    if (deckError != null) {
      return _deckMessage(
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: FCard(
            title: const Text('Something went wrong'),
            subtitle: Text(deckError),
            child: FButton(
              variant: FButtonVariant.outline,
              onPress: _loadDeck,
              child: const Text('Try again'),
            ),
          ),
        ),
      );
    }

    if (_cards.isEmpty) {
      return _deckMessage(
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: FCard(
            title: const Text('No restaurants yet'),
            subtitle: const Text('Check back soon.'),
            child: FButton(
              variant: FButtonVariant.outline,
              onPress: _loadDeck,
              child: const Text('Reload'),
            ),
          ),
        ),
      );
    }

    if (_index >= _cards.length) {
      // Not a local replay: every card in `_cards` is already swiped
      // server-side, so replaying it would fight `get_deck`'s exclusion.
      // A reload lets the backend deal fresh rows — or resurface old passes
      // via its 3-day exhaustion fallback.
      return _deckMessage(
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: FCard(
            title: const Text('No more cards'),
            subtitle: const Text('Reload to keep swiping.'),
            child: FButton(
              variant: FButtonVariant.outline,
              onPress: _loadDeck,
              child: const Text('Reload deck'),
            ),
          ),
        ),
      );
    }

    final current = _cards[_index];
    final next = _index + 1 < _cards.length ? _cards[_index + 1] : null;
    final currentPlayerFuture = _preloadTikTokPlayer(current.videoUrl);
    final nextPlayerFuture = _preloadTikTokPlayer(next?.videoUrl);
    final motion = _motionFrame();
    final currentRating = _ratingText(current);
    final currentDistance = _distanceLabelFor(current);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (next != null)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _motionController,
                        // The card itself is passed as `child` so it is built
                        // once, not on every tick — it can host a WebView.
                        child: _SwipeCard(
                          key: ValueKey(next.id),
                          data: next,
                          isBehind: true,
                          infoExpanded: _infoExpanded,
                          ratingText: _ratingText(next),
                          distanceText: _distanceLabelFor(next),
                          onTap: () => _openVideoPlayer(next),
                          tiktokPlayerFuture: nextPlayerFuture,
                          onInfoTap: () {
                            setState(() {
                              _infoExpanded = !_infoExpanded;
                            });
                          },
                          onReviewInteractionChanged:
                              _setReviewInteractionActive,
                          // No onPass/onLike: the behind card must never
                          // act on the deck while the top card is active.
                        ),
                        builder: (context, child) {
                          final lift = _motionFrame().lift;

                          return Opacity(
                            opacity: 0.82 + (lift * 0.18),
                            child: Transform.translate(
                              offset: Offset(0, 22 - (lift * 22)),
                              child: Transform.scale(
                                scale: 0.92 + (lift * 0.08),
                                child: child,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  Positioned.fill(
                    child: GestureDetector(
                      onPanStart: _motionType != _SwipeMotionType.idle ||
                              _reviewInteractionActive
                          ? null
                          : (_) {
                              _warmNeighborTikTokPlayers();
                            },
                      onPanUpdate: _motionType != _SwipeMotionType.idle ||
                              _reviewInteractionActive
                          ? null
                          : (details) {
                              setState(() {
                                if (_dragOffset == Offset.zero) {
                                  _warmNeighborTikTokPlayers();
                                }
                                _motionController.stop();
                                _motionType = _SwipeMotionType.idle;
                                _dragOffset += details.delta;
                              });
                            },
                      onPanEnd: _motionType != _SwipeMotionType.idle ||
                              _reviewInteractionActive
                          ? null
                          : (details) {
                              if (_dragOffset.dx > 110) {
                                _handleLike();
                                return;
                              }

                              if (_dragOffset.dx < -110) {
                                _handleDislike();
                                return;
                              }

                              setState(() {
                                _motionType = _SwipeMotionType.settleBack;
                                _animationStartOffset = _dragOffset;
                                _animationEndOffset = Offset.zero;
                                _motionController.forward(from: 0);
                                _dragOffset = Offset.zero;
                              });
                            },
                      child: AnimatedBuilder(
                        animation: _motionController,
                        builder: (context, child) {
                          // Read live from the controller: values captured in
                          // build() would hold still for the whole animation.
                          final frame = _motionFrame();
                          final scale = _motionType == _SwipeMotionType.swipeOut
                              ? ui.lerpDouble(1, 0.982, frame.progress) ?? 1
                              : ui.lerpDouble(1, 0.995, frame.progress) ?? 1;
                          final opacity =
                              _motionType == _SwipeMotionType.swipeOut
                                  ? ui.lerpDouble(1, 0.84, frame.progress) ?? 1
                                  : 1.0;

                          return Opacity(
                            opacity: opacity,
                            child: Transform.translate(
                              offset: frame.offset,
                              child: Transform.rotate(
                                angle: frame.offset.dx / 900,
                                child: Transform.scale(
                                  scale: scale,
                                  child: child,
                                ),
                              ),
                            ),
                          );
                        },
                        child: Stack(
                          children: [
                            _SwipeCard(
                              key: ValueKey(current.id),
                              data: current,
                              likeOpacity: motion.offset.dx > 20
                                  ? motion.dragPercentage
                                  : 0,
                              nopeOpacity: motion.offset.dx < -20
                                  ? motion.dragPercentage
                                  : 0,
                              infoExpanded: _infoExpanded,
                              ratingText: currentRating,
                              distanceText: currentDistance,
                              onTap: () => _openVideoPlayer(current),
                              tiktokPlayerFuture: currentPlayerFuture,
                              onInfoTap: () {
                                setState(() {
                                  _infoExpanded = !_infoExpanded;
                                });
                              },
                              onReviewInteractionChanged:
                                  _setReviewInteractionActive,
                              onPass: () => _triggerAction(false),
                              onLike: () => _triggerAction(true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Painted above the card so the settings button stays tappable;
            // the gradient itself ignores pointers so card gestures pass
            // through the top 300px.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _FloatingHeader(locationLabel: _locationLabel),
            ),
          ],
        );
      },
    );
  }
}

class _FloatingHeader extends StatelessWidget {
  const _FloatingHeader({required this.locationLabel});

  /// The user's reverse-geocoded whereabouts, from the profile row — not a
  /// hardcoded town.
  final String locationLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.90),
                      Colors.black.withValues(alpha: 0.82),
                      Colors.black.withValues(alpha: 0.66),
                      Colors.black.withValues(alpha: 0.46),
                      Colors.black.withValues(alpha: 0.30),
                      Colors.black.withValues(alpha: 0.16),
                      Colors.black.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.09, 0.20, 0.34, 0.50, 0.68, 0.86, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, left: 16, right: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassChip(
                    icon: Icons.place_rounded,
                    label: locationLabel,
                  ),
                  GlassCircleButton(
                    icon: Icons.settings_rounded,
                    size: kUtilityButtonSize,
                    iconSize: 20,
                    background: Colors.black.withValues(alpha: 0.34),
                    semanticLabel: 'Settings',
                    onTap: () {
                      context.push('/settings');
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _SwipeMotionType {
  idle,
  settleBack,
  swipeOut,
}

/// One frame of swipe motion: see `_SwipeDeckState._motionFrame`.
class _MotionFrame {
  const _MotionFrame({
    required this.progress,
    required this.offset,
    required this.dragPercentage,
    required this.lift,
  });

  /// Eased 0..1 position through the settle-back / swipe-out animation.
  final double progress;

  /// Where the top card sits relative to its resting position.
  final Offset offset;

  /// How far towards a committed swipe the card is, 0..1.
  final double dragPercentage;

  /// Eased [dragPercentage], used to raise the card behind into place.
  final double lift;
}

class _SwipeCard extends StatefulWidget {
  const _SwipeCard({
    super.key,
    required this.data,
    required this.infoExpanded,
    required this.ratingText,
    required this.distanceText,
    required this.onTap,
    required this.onInfoTap,
    required this.onReviewInteractionChanged,
    this.tiktokPlayerFuture,
    this.onPass,
    this.onLike,
    this.isBehind = false,
    this.likeOpacity = 0,
    this.nopeOpacity = 0,
  });

  final _SwipeCardData data;
  final bool infoExpanded;
  final String ratingText;
  final String distanceText;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;
  final ValueChanged<bool> onReviewInteractionChanged;
  final Future<WebViewController>? tiktokPlayerFuture;
  final VoidCallback? onPass;
  final VoidCallback? onLike;
  final bool isBehind;
  final double likeOpacity;
  final double nopeOpacity;

  @override
  State<_SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<_SwipeCard> {
  int _imageIndex = 0;
  Offset? _imagePointerStart;
  bool _imagePointerMoved = false;

  @override
  void didUpdateWidget(covariant _SwipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.id != widget.data.id) {
      _imageIndex = 0;
    }
  }

  void _changeImage(int delta) {
    final nextIndex =
        (_imageIndex + delta).clamp(0, widget.data.imageUrls.length - 1);
    if (nextIndex == _imageIndex) {
      return;
    }

    setState(() {
      _imageIndex = nextIndex;
    });
  }

  void _handleImageTap(Offset localPosition, double width) {
    if (widget.data.imageUrls.length <= 1) {
      return;
    }

    final isLeftSide = localPosition.dx < width / 2;
    _changeImage(isLeftSide ? -1 : 1);
  }

  @override
  Widget build(BuildContext context) {
    const bottomRadius = Radius.circular(kRadiusCard);
    final cardVideoUrl = widget.data.videoUrl;
    final showsPhotos =
        widget.isBehind || cardVideoUrl == null || cardVideoUrl.isEmpty;
    final hasMultipleImages = showsPhotos && widget.data.imageUrls.length > 1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: bottomRadius,
            bottomRight: bottomRadius,
          ),
          child: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: bottomRadius,
                bottomRight: bottomRadius,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Square at the top (the card runs under the status-bar
                // scrim); only the outer bottom corners are rounded.
                Positioned.fill(
                  child: ClipRect(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final videoUrl = widget.data.videoUrl;
                        if (!widget.isBehind &&
                            videoUrl != null &&
                            videoUrl.isNotEmpty) {
                          return IgnorePointer(
                            child: _SwipeTikTokPlayer(
                              key: ValueKey(videoUrl),
                              videoUrl: videoUrl,
                              controllerFuture: widget.tiktokPlayerFuture,
                            ),
                          );
                        }

                        if (widget.data.imageUrls.isEmpty) {
                          return TikTokThumbnailPlaceholder(
                            creatorHandle:
                                tiktokCreatorHandle(widget.data.videoUrl),
                          );
                        }

                        return Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (event) {
                            _imagePointerStart = event.localPosition;
                            _imagePointerMoved = false;
                          },
                          onPointerMove: (event) {
                            final start = _imagePointerStart;
                            if (start == null || _imagePointerMoved) {
                              return;
                            }

                            if ((event.localPosition - start).distance > 12) {
                              _imagePointerMoved = true;
                            }
                          },
                          onPointerUp: (event) {
                            final start = _imagePointerStart;
                            final moved = _imagePointerMoved;
                            _imagePointerStart = null;
                            _imagePointerMoved = false;

                            if (start == null || moved) {
                              return;
                            }

                            final local = event.localPosition;
                            _handleImageTap(local, constraints.maxWidth);
                          },
                          onPointerCancel: (_) {
                            _imagePointerStart = null;
                            _imagePointerMoved = false;
                          },
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: SizedBox.expand(
                              key: ValueKey(widget.data.imageUrls[_imageIndex]),
                              child: Image.network(
                                widget.data.imageUrls[_imageIndex],
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) {
                                    return child;
                                  }

                                  return const SizedBox.expand(
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return SizedBox.expand(
                                    child: TikTokThumbnailPlaceholder(
                                      creatorHandle: tiktokCreatorHandle(
                                        widget.data.videoUrl,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 1.00),
                            Colors.black.withValues(alpha: 1.00),
                            Colors.black.withValues(alpha: 0.96),
                            Colors.black.withValues(alpha: 0.84),
                            Colors.black.withValues(alpha: 0.56),
                            Colors.black.withValues(alpha: 0.22),
                            Colors.black.withValues(alpha: 0.00),
                          ],
                          stops: const [0.0, 0.14, 0.28, 0.46, 0.70, 0.90, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                const PhotoBottomScrim(height: 360),
                if (hasMultipleImages)
                  Positioned(
                    top: 150,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: _ImageProgressDots(
                          count: widget.data.imageUrls.length,
                          activeIndex: _imageIndex,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: AppSpacing.screenPadding + 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RestaurantInfoPanel(
                        data: widget.data,
                        expanded: widget.infoExpanded,
                        ratingText: widget.ratingText,
                        distanceText: widget.distanceText,
                        onTap: widget.onInfoTap,
                        onReviewInteractionChanged:
                            widget.onReviewInteractionChanged,
                      ),
                      if (widget.onPass != null && widget.onLike != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GlassCircleButton(
                              icon: Icons.close_rounded,
                              size: kActionButtonSize,
                              background: Colors.black.withValues(alpha: 0.30),
                              semanticLabel: 'Pass',
                              onTap: widget.onPass!,
                            ),
                            GlassCircleButton(
                              icon: Icons.favorite_rounded,
                              size: kActionButtonSize,
                              background: Colors.white.withValues(alpha: 0.22),
                              semanticLabel: 'Like',
                              onTap: widget.onLike!,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestaurantInfoPanel extends StatefulWidget {
  const _RestaurantInfoPanel({
    required this.data,
    required this.expanded,
    required this.ratingText,
    required this.distanceText,
    required this.onTap,
    required this.onReviewInteractionChanged,
  });

  final _SwipeCardData data;
  final bool expanded;
  final String ratingText;
  final String distanceText;
  final VoidCallback onTap;
  final ValueChanged<bool> onReviewInteractionChanged;

  @override
  State<_RestaurantInfoPanel> createState() => _RestaurantInfoPanelState();
}

class _RestaurantInfoPanelState extends State<_RestaurantInfoPanel> {
  Future<void> _openDirections() async {
    final opened = await openDirections(
      latitude: widget.data.latitude,
      longitude: widget.data.longitude,
      label: widget.data.title,
    );
    if (opened || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open maps for this place.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(kRadiusPanel),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: widget.expanded
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(kRadiusPanel),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(
                            sigmaX: kGlassBlurSigma,
                            sigmaY: kGlassBlurSigma,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.32),
                              borderRadius: BorderRadius.circular(kRadiusPanel),
                              border: Border.all(color: kGlassBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.data.details,
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        height: 1.35,
                                        color: Colors.white
                                            .withValues(alpha: 0.85),
                                      ),
                                ),
                                const SizedBox(height: 10),
                                _ReviewCarousel(
                                  reviews: widget.data.reviews,
                                  onInteractionChanged:
                                      widget.onReviewInteractionChanged,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Row(
              children: [
                _CategoryBadge(
                  label: widget.data.tag,
                  accent: widget.data.color,
                ),
                const Spacer(),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  turns: widget.expanded ? 0.5 : 0,
                  child: Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white.withValues(alpha: 0.65),
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: widget.data.title,
                style: glassTitleStyle(context),
                children: [
                  // Unrated restaurants render ratingLabel's '–', which reads
                  // as a stray dash after the name — show real ratings only.
                  if (widget.ratingText.trim() != '–')
                    TextSpan(
                      text: '  ${widget.ratingText}',
                      style: glassTitleMutedStyle(context),
                    ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.place_rounded,
                  color: kTextOnPhotoSecondary,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    widget.distanceText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: glassPlaceStyle(context),
                  ),
                ),
                if (hasMapFix(widget.data.latitude, widget.data.longitude)) ...[
                  const SizedBox(width: 8),
                  // Its own tap target: the surrounding InkWell expands the
                  // panel, and leaving directions to that gesture would open
                  // maps every time the user peeked at the reviews.
                  GestureDetector(
                    onTap: _openDirections,
                    behavior: HitTestBehavior.opaque,
                    child: const GlassChip(
                      label: 'Directions',
                      icon: Icons.directions_rounded,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(
          color: accent.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: glassOverlineStyle(context),
      ),
    );
  }
}

class _SwipeTikTokPlayer extends StatefulWidget {
  const _SwipeTikTokPlayer({
    super.key,
    required this.videoUrl,
    this.applyCardFraming = true,
    this.controllerFuture,
  });

  final String videoUrl;
  final bool applyCardFraming;
  final Future<WebViewController>? controllerFuture;

  @override
  State<_SwipeTikTokPlayer> createState() => _SwipeTikTokPlayerState();
}

class _SwipeTikTokPlayerState extends State<_SwipeTikTokPlayer> {
  late final Future<WebViewController> _controllerFuture;

  @override
  void initState() {
    super.initState();
    _controllerFuture = widget.controllerFuture ??
        _createTikTokPlayerController(widget.videoUrl);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WebViewController>(
      future: _controllerFuture,
      builder: (context, snapshot) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData)
                  ClipRect(
                    child: widget.applyCardFraming
                        ? Transform.translate(
                            offset: Offset(0, constraints.maxHeight * 0.07),
                            child: Transform.scale(
                              scale: 1.03,
                              alignment: Alignment.center,
                              child: SizedBox.expand(
                                child: WebViewWidget(
                                  controller: snapshot.data!,
                                ),
                              ),
                            ),
                          )
                        : SizedBox.expand(
                            child: WebViewWidget(
                              controller: snapshot.data!,
                            ),
                          ),
                  ),
                if (widget.applyCardFraming)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 138,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.96),
                              Colors.black.withValues(alpha: 0.84),
                              Colors.black.withValues(alpha: 0.58),
                              Colors.black.withValues(alpha: 0.26),
                              Colors.black.withValues(alpha: 0.00),
                            ],
                            stops: const [0.0, 0.16, 0.40, 0.72, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (snapshot.connectionState != ConnectionState.done)
                  const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (snapshot.hasError)
                  // The spinner is gone but no WebView arrived, so without
                  // this the card would sit on a bare black rectangle.
                  Center(
                    child: Text(
                      'Video unavailable',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

Future<WebViewController> _createTikTokPlayerController(String videoUrl) async {
  late final PlatformWebViewControllerCreationParams params;
  if (WebViewPlatform.instance is WebKitWebViewPlatform) {
    params = WebKitWebViewControllerCreationParams(
      allowsInlineMediaPlayback: true,
      mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
    );
  } else {
    params = const PlatformWebViewControllerCreationParams();
  }

  final controller = WebViewController.fromPlatformCreationParams(params);
  // Awaited one by one rather than cascaded: each setter returns a future, and
  // a cascade drops them, so a failure would vanish and the load below could
  // race ahead of the settings it depends on.
  await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
  await controller.setBackgroundColor(Colors.black);
  await controller.setUserAgent(
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
    'Mobile/15E148 Safari/604.1',
  );
  await controller.setNavigationDelegate(NavigationDelegate());

  final platformController = controller.platform;
  if (platformController is AndroidWebViewController) {
    // Android blocks playback started by script or by an autoplay attribute
    // until this is false, so the player would sit on its first frame.
    await platformController.setMediaPlaybackRequiresUserGesture(false);
  }

  final videoId = _extractTikTokVideoId(videoUrl);
  final playerUrl = videoId == null
      ? videoUrl
      : 'https://www.tiktok.com/player/v1/$videoId?autoplay=1&controls=1&volume_control=1&muted=0&music_info=1&description=1&timestamp=1&rel=0&loop=1';

  // The player is loaded as the top-level document. Wrapping it in local HTML
  // needs a baseUrl, and claiming `https://www.tiktok.com` for a page TikTok
  // did not serve makes the player refuse with its own "Player error" screen.
  await controller.loadRequest(Uri.parse(playerUrl));

  return controller;
}

String? _extractTikTokVideoId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return null;
  }

  for (final segment in uri.pathSegments.reversed) {
    if (RegExp(r'^\d+$').hasMatch(segment)) {
      return segment;
    }
  }

  return null;
}

class _TikTokPlayerScreen extends StatelessWidget {
  const _TikTokPlayerScreen({required this.videoUrl});

  final String videoUrl;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _SwipeTikTokPlayer(
              key: ValueKey(videoUrl),
              videoUrl: videoUrl,
              applyCardFraming: false,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topRight,
                  child: GlassCircleButton(
                    icon: Icons.close_rounded,
                    size: kUtilityButtonSize,
                    background: Colors.black.withValues(alpha: 0.48),
                    // A WebView platform view cannot be blurred by a
                    // BackdropFilter, so don't pay for one.
                    frosted: false,
                    semanticLabel: 'Close player',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCarousel extends StatefulWidget {
  const _ReviewCarousel({
    required this.reviews,
    required this.onInteractionChanged,
  });

  final List<_ReviewSnippet> reviews;
  final ValueChanged<bool> onInteractionChanged;

  @override
  State<_ReviewCarousel> createState() => _ReviewCarouselState();
}

class _ReviewCarouselState extends State<_ReviewCarousel> {
  late final PageController _pageController = PageController();
  int _pageIndex = 0;

  double _reviewCardHeight(BuildContext context, double maxWidth) {
    final baseTextStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.90),
          height: 1.35,
        );
    final titleStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.75),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.10,
        );
    final contentWidth = math.max(120.0, maxWidth - 12 - 12 - 30 - 10);

    double textHeightFor(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: baseTextStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: contentWidth);
      return painter.height;
    }

    final titlePainter = TextPainter(
      text: TextSpan(text: 'Top review', style: titleStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: contentWidth);

    final reviewHeight = widget.reviews.fold<double>(
      0,
      (currentMax, review) => math.max(currentMax, textHeightFor(review.text)),
    );
    final textColumnHeight = titlePainter.height + 3 + reviewHeight;
    final contentHeight = math.max(30.0, textColumnHeight);

    return 12 + contentHeight + 10 + 4;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reviews.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = _reviewCardHeight(context, constraints.maxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => widget.onInteractionChanged(true),
              onPointerUp: (_) => widget.onInteractionChanged(false),
              onPointerCancel: (_) => widget.onInteractionChanged(false),
              child: SizedBox(
                height: height,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.reviews.length,
                  onPageChanged: (index) {
                    setState(() {
                      _pageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _ReviewCard(snippet: widget.reviews[index]),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Swipe for more reviews',
                  style: glassOverlineStyle(context).copyWith(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                _ReviewDots(
                    count: widget.reviews.length, activeIndex: _pageIndex),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.snippet,
  });

  final _ReviewSnippet snippet;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(kRadiusPanel),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rate_review_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Top review',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.10,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  snippet.text,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.90),
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewDots extends StatelessWidget {
  const _ReviewDots({
    required this.count,
    required this.activeIndex,
  });

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final isActive = index == activeIndex;
        return Container(
          width: isActive ? 14 : 5,
          height: 5,
          margin: EdgeInsets.only(right: index == count - 1 ? 0 : 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isActive ? 0.95 : 0.30),
            borderRadius: BorderRadius.circular(kRadiusPill),
          ),
        );
      }),
    );
  }
}

class _ImageProgressDots extends StatelessWidget {
  const _ImageProgressDots({
    required this.count,
    required this.activeIndex,
  });

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final isActive = index == activeIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: isActive ? 18 : 6,
          height: 3,
          margin: EdgeInsets.only(right: index == count - 1 ? 0 : 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isActive ? 0.95 : 0.35),
            borderRadius: BorderRadius.circular(kRadiusPill),
          ),
        );
      }),
    );
  }
}

class _SwipeCardData {
  const _SwipeCardData({
    required this.id,
    required this.title,
    required this.tag,
    required this.details,
    required this.color,
    required this.rating,
    required this.latitude,
    required this.longitude,
    required this.reviewName,
    required this.reviewText,
    required this.reviews,
    required this.imageUrls,
    this.videoUrl,
  });

  final int id;
  final String title;
  final String tag;
  final String details;
  final Color color;
  final double rating;
  final double latitude;
  final double longitude;
  final String reviewName;
  final String reviewText;
  final List<_ReviewSnippet> reviews;
  final List<String> imageUrls;
  final String? videoUrl;
}

class _ReviewSnippet {
  const _ReviewSnippet({
    required this.author,
    required this.text,
  });

  final String author;
  final String text;
}

class RestaurantDetailData {
  const RestaurantDetailData({
    required this.id,
    required this.title,
    required this.tag,
    required this.details,
    required this.color,
    required this.rating,
    required this.latitude,
    required this.longitude,
    required this.reviewName,
    required this.reviewText,
    required this.imageUrls,
    this.videoUrl,
  });

  factory RestaurantDetailData.fromPayload(Map<String, dynamic> payload) {
    return RestaurantDetailData(
      id: (payload['id'] as num?)?.toInt() ?? 0,
      title: payload['title'] as String? ?? 'Restaurant',
      tag: payload['tag'] as String? ?? '',
      details: payload['details'] as String? ?? '',
      color: Color((payload['color'] as int?) ?? 0xFF141922),
      rating: (payload['rating'] as num?)?.toDouble() ?? 0,
      latitude: (payload['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (payload['longitude'] as num?)?.toDouble() ?? 0,
      reviewName: payload['reviewName'] as String? ?? '',
      reviewText: payload['reviewText'] as String? ?? '',
      imageUrls: (payload['imageUrls'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      videoUrl: payload['videoUrl'] as String?,
    );
  }

  final int id;
  final String title;
  final String tag;
  final String details;
  final Color color;
  final double rating;
  final double latitude;
  final double longitude;
  final String reviewName;
  final String reviewText;
  final List<String> imageUrls;
  final String? videoUrl;
}

extension _SwipeCardDataPayload on _SwipeCardData {
  Map<String, dynamic> toDetailPayload() {
    return {
      'id': id,
      'title': title,
      'tag': tag,
      'details': details,
      'color': color.toARGB32(),
      'rating': rating,
      'latitude': latitude,
      'longitude': longitude,
      'reviewName': reviewName,
      'reviewText': reviewText,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
    };
  }
}

class RestaurantDetailPage extends StatefulWidget {
  const RestaurantDetailPage({
    super.key,
    required this.data,
  });

  final RestaurantDetailData data;

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage>
    with _UserPositionState {
  int _heroIndex = 0;
  final GlobalKey _locationKey = GlobalKey();
  final GlobalKey _reviewKey = GlobalKey();
  String? _placeName;

  bool get _liked => LikesController.instance.isLiked(widget.data.id);

  @override
  void initState() {
    super.initState();
    _resolveUserPosition();
    _resolvePlaceName();
    LikesController.instance.addListener(_onLikesChanged);
    // Best-effort: an unreachable backend leaves the heart empty, and the
    // toggle below surfaces its own error if the user then taps it.
    LikesController.instance.ensureLoaded().catchError((Object error) {
      debugPrint('Likes load failed: $error');
    });
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

  Future<void> _resolvePlaceName() async {
    final name = await resolvePlaceNameForCoordinates(
      widget.data.latitude,
      widget.data.longitude,
    );
    if (!mounted || name == null) {
      return;
    }
    setState(() {
      _placeName = name;
    });
  }

  Future<void> _openDirections() async {
    final opened = await openDirections(
      latitude: widget.data.latitude,
      longitude: widget.data.longitude,
      label: widget.data.title,
    );
    if (opened || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open maps for this place.')),
    );
  }

  Future<void> _toggleLike() async {
    final likes = LikesController.instance;
    try {
      if (likes.isLiked(widget.data.id)) {
        await likes.unlike(widget.data.id, source: 'detail');
      } else {
        await likes.like(widget.data.id, source: 'detail');
      }
    } catch (error) {
      debugPrint('Like toggle failed: $error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that change.')),
      );
    }
  }

  String _distanceLabel() {
    final userPosition = _userPosition;
    if (userPosition == null) {
      return 'Distance loading';
    }

    if (!hasMapFix(widget.data.latitude, widget.data.longitude)) {
      // Measuring to the 0,0 sentinel reports the distance to Null Island,
      // which reads as a real answer.
      return 'Distance unknown';
    }

    final meters = Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
      widget.data.latitude,
      widget.data.longitude,
    );

    if (meters >= 100000) {
      return '100km +';
    }

    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km away';
    }

    return '${meters.toStringAsFixed(0)} m away';
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) {
      return;
    }

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  Widget _heroPlaceholder() {
    return TikTokThumbnailPlaceholder(
      creatorHandle: tiktokCreatorHandle(widget.data.videoUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = widget.data.imageUrls;
    final heroIndex =
        imageUrls.isEmpty ? 0 : _heroIndex.clamp(0, imageUrls.length - 1);
    final heroUrl = imageUrls.isEmpty ? null : imageUrls[heroIndex];
    final videoUrl = widget.data.videoUrl;

    return Scaffold(
      backgroundColor: kBackgroundDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Hero image pinned behind the scrolling content.
          Positioned.fill(
            child: heroUrl == null
                ? _heroPlaceholder()
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: SizedBox.expand(
                      key: ValueKey(heroUrl),
                      child: Image.network(
                        heroUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _heroPlaceholder();
                        },
                      ),
                    ),
                  ),
          ),
          const PhotoWash(),
          const PhotoTopScrim(),
          const PhotoBottomScrim(),
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                      child: Column(
                        children: [
                          const Spacer(),
                          Text.rich(
                            TextSpan(
                              text: widget.data.title,
                              style: glassTitleStyle(context),
                              children: [
                                if (ratingLabel(widget.data.rating) != '–')
                                  TextSpan(
                                    text:
                                        '  ${ratingLabel(widget.data.rating)}',
                                    style: glassTitleMutedStyle(context),
                                  ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.place_rounded,
                                color: kTextOnPhotoSecondary,
                                size: 16,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  _distanceLabel(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: glassPlaceStyle(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (ratingLabel(widget.data.rating) != '–')
                                GlassChip(
                                  icon: Icons.star_rounded,
                                  label: ratingLabel(widget.data.rating),
                                ),
                              if (widget.data.tag.isNotEmpty)
                                GlassChip(
                                  icon: Icons.local_dining_rounded,
                                  label: widget.data.tag,
                                ),
                              if (videoUrl != null && videoUrl.isNotEmpty)
                                const GlassChip(
                                  icon: Icons.music_note_rounded,
                                  label: 'TikTok Review',
                                ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              GlassCircleButton(
                                icon: Icons.favorite_rounded,
                                iconColor: _liked ? kAccentLime : kTextOnPhoto,
                                semanticLabel: _liked ? 'Liked' : 'Like',
                                onTap: _toggleLike,
                              ),
                              GlassCircleButton(
                                icon: Icons.chat_bubble_rounded,
                                semanticLabel: 'Reviews',
                                onTap: () => _scrollToSection(_reviewKey),
                              ),
                              GlassCircleButton(
                                icon: Icons.route_rounded,
                                semanticLabel: 'Location',
                                onTap: () => _scrollToSection(_locationKey),
                              ),
                              GlassCircleButton(
                                icon: Icons.close_rounded,
                                semanticLabel: 'Close',
                                onTap: () => Navigator.of(context).maybePop(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: kBackgroundDark,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    20,
                    AppSpacing.screenPadding,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.data.details,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                              height: 1.4,
                            ),
                      ),
                      const SizedBox(height: 16),
                      if (widget.data.imageUrls.isNotEmpty) ...[
                        _DetailCard(
                          title: 'More photos',
                          child: Column(
                            children: widget.data.imageUrls
                                .map(
                                  (imageUrl) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(kRadiusThumb),
                                      child: AspectRatio(
                                        aspectRatio: 1.7,
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return TikTokThumbnailPlaceholder(
                                              creatorHandle:
                                                  tiktokCreatorHandle(
                                                widget.data.videoUrl,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      KeyedSubtree(
                        key: _locationKey,
                        child: _DetailCard(
                          title: 'Location',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.location_pin,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (_placeName != null) ...[
                                          Text(
                                            _placeName!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                        ],
                                        Text(
                                          hasMapFix(
                                            widget.data.latitude,
                                            widget.data.longitude,
                                          )
                                              ? '${_distanceLabel()} from your '
                                                  'location'
                                              : 'No location on file for this '
                                                  'place',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.white
                                                    .withValues(alpha: 0.78),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (hasMapFix(
                                widget.data.latitude,
                                widget.data.longitude,
                              )) ...[
                                const SizedBox(height: 12),
                                _DirectionsButton(onTap: _openDirections),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      KeyedSubtree(
                        key: _reviewKey,
                        child: _DetailCard(
                          title: 'Top review',
                          child: widget.data.reviewText.isEmpty
                              ? Text(
                                  'No reviews yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.66),
                                      ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.data.reviewName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: Colors.white
                                                .withValues(alpha: 0.68),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      widget.data.reviewText,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            height: 1.35,
                                          ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Fixed top controls: back, photo switcher, video.
          // Positioned rather than a plain Stack child: StackFit.expand would
          // stretch this row to the full screen height, centring the controls
          // vertically and letting the invisible row swallow drags meant for
          // the scroll view underneath.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    GlassCircleButton(
                      icon: Icons.arrow_back_rounded,
                      size: kUtilityButtonSize,
                      background: Colors.black.withValues(alpha: 0.34),
                      semanticLabel: 'Back',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: imageUrls.length > 1
                          ? Center(
                              child: _HeroThumbnailStrip(
                                imageUrls: imageUrls,
                                activeIndex: heroIndex,
                                onSelected: (index) {
                                  setState(() {
                                    _heroIndex = index;
                                  });
                                },
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (videoUrl != null && videoUrl.isNotEmpty)
                      GlassCircleButton(
                        icon: Icons.play_arrow_rounded,
                        size: kUtilityButtonSize,
                        background: Colors.black.withValues(alpha: 0.34),
                        semanticLabel: 'Watch TikTok review',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  _TikTokPlayerScreen(videoUrl: videoUrl),
                            ),
                          );
                        },
                      )
                    else
                      const SizedBox(width: kUtilityButtonSize),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top-center photo switcher from the reference design: a frosted pill of
/// mini thumbnails; the active one gets an accent ring.
class _HeroThumbnailStrip extends StatelessWidget {
  const _HeroThumbnailStrip({
    required this.imageUrls,
    required this.activeIndex,
    required this.onSelected,
  });

  final List<String> imageUrls;
  final int activeIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final visible = imageUrls.length > 5 ? imageUrls.sublist(0, 5) : imageUrls;

    // Five 36px thumbnails need ~216px, more than the slot between the back
    // and play buttons on a 320pt-wide phone. Shrink the pill to fit instead
    // of overflowing it off the right edge.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: _pill(visible),
    );
  }

  Widget _pill(List<String> visible) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusPill),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: kGlassBlurSigma,
          sigmaY: kGlassBlurSigma,
        ),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(kRadiusPill),
            border: Border.all(color: kGlassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < visible.length; i++)
                Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                  // Matches _StripThumb on the Like tab: screen readers need
                  // to know these photo swatches are buttons.
                  child: Semantics(
                    label: 'Photo ${i + 1} of ${visible.length}',
                    button: true,
                    selected: i == activeIndex,
                    child: GestureDetector(
                      onTap: () => onSelected(i),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(kRadiusPill),
                          border: Border.all(
                            color: i == activeIndex
                                ? kAccentLime
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            visible[i],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const ColoredBox(
                                color: kGlassFill,
                                child: Icon(
                                  Icons.image_not_supported_rounded,
                                  color: Colors.white54,
                                  size: 16,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
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

class _DirectionsButton extends StatelessWidget {
  const _DirectionsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: kAccentLime,
        borderRadius: BorderRadius.circular(kRadiusPill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusPill),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.directions_rounded,
                  size: 18,
                  color: kOnAccentLime,
                ),
                const SizedBox(width: 8),
                // Flexible, or a large accessibility text scale pushes the
                // label past the button's edge instead of ellipsising.
                Flexible(
                  child: Text(
                    'Get directions',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: kOnAccentLime,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfacePanel,
        borderRadius: BorderRadius.circular(kRadiusPanel),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: glassPanelTitleStyle(context)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
