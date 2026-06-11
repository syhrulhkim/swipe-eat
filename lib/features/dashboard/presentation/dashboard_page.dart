// ignore_for_file: unused_element_parameter

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../core/ui/app_spacing.dart';
import '../../auth/state/auth_controller.dart';
import '../../auth/models/app_user.dart';

Position _dummyUserPosition() {
  return Position(
    longitude: 102.933333,
    latitude: 1.850000,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    accuracy: 0,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
    isMocked: true,
  );
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
          _SwipeDeck(),
          const _ExploreTab(),
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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFF12161D),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
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
    final selectedColor = Colors.white;
    final unselectedColor = Colors.white.withValues(alpha: 0.62);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
            child: SizedBox.expand(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 1),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: widget.isSelected
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      scale: _pressed ? 0.94 : 1.0,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        scale: widget.isSelected ? 1.0 : 0.96,
                        child: Icon(
                          widget.icon,
                          size: 28,
                          color: widget.isSelected
                              ? selectedColor
                              : unselectedColor,
                        ),
                      ),
                    ),
                    Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: widget.isSelected
                                ? selectedColor
                                : unselectedColor,
                            fontWeight: widget.isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            height: 1.0,
                          ),
                    ),
                  ],
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
  const _ExploreTab();

  @override
  State<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<_ExploreTab> {
  Position? _userPosition;
  String? _distanceStatus;

  final List<_SwipeCardData> _spotCards = const [
    _SwipeCardData(
      title: 'Mak Limah Asam Pedas',
      tag: 'Must Try',
      details:
          'A bold, comfort-first local favorite with a rich asam pedas profile.',
      color: Color(0xFFF6D365),
      rating: 4.3,
      latitude: 1.8522138,
      longitude: 102.9253991,
      reviewName: 'Explore pick',
      reviewText: 'Rich, spicy, and very comforting.',
      reviews: [
        _ReviewSnippet(
            author: 'Local foodie', text: 'Rich, spicy, and very comforting.'),
      ],
      imageUrls: [
        'https://tempatcuti.my/wp-content/uploads/2023/12/Mak-Limah-Asam-Pedas.jpg',
      ],
    ),
    _SwipeCardData(
      title: 'Warung Wak Jaferi',
      tag: 'Morning',
      details: 'Relaxed breakfast plates with a calm, homely local feel.',
      color: Color(0xFFB7E4C7),
      rating: 4.4,
      latitude: 1.8406831,
      longitude: 102.9430163,
      reviewName: 'Explore pick',
      reviewText: 'Calm breakfast spot with traditional dishes.',
      reviews: [
        _ReviewSnippet(
            author: 'Local foodie',
            text: 'Calm breakfast spot with traditional dishes.'),
      ],
      imageUrls: [
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Warung-Wak-Jaferi.jpg',
      ],
    ),
    _SwipeCardData(
      title: 'Selera Izzati',
      tag: 'Easygoing',
      details:
          'Simple, satisfying breakfast with a clean and approachable vibe.',
      color: Color(0xFFF4A261),
      rating: 4.1,
      latitude: 1.8471209,
      longitude: 102.9334028,
      reviewName: 'Explore pick',
      reviewText: 'Simple, satisfying Malay breakfast.',
      reviews: [
        _ReviewSnippet(
            author: 'Local foodie',
            text: 'Simple, satisfying Malay breakfast.'),
      ],
      imageUrls: [
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Selera-Izzati.jpg',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _userPosition = _dummyUserPosition();
  }

  String _distanceLabelFor(_SwipeCardData data) {
    final userPosition = _userPosition;
    if (userPosition == null) {
      return _distanceStatus ?? 'Distance loading';
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

    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km away';
    }

    return '${meters.toStringAsFixed(0)} m away';
  }

  @override
  Widget build(BuildContext context) {
    return _DashboardTabShell(
      title: 'Explore',
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF141922),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      color: Colors.white.withValues(alpha: 0.70)),
                  const SizedBox(width: 10),
                  Text(
                    'Search foods or stalls',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.48),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ..._spotCards.map((card) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SpotPreviewCard(
                  data: card,
                  distanceText: _distanceLabelFor(card),
                  layout: _SpotPreviewLayout.compact,
                  compactStats: false,
                  showActionStrip: false,
                  onTap: () => context.push(
                    '/restaurant',
                    extra: card.toDetailPayload(),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _LikesTab extends StatefulWidget {
  const _LikesTab();

  @override
  State<_LikesTab> createState() => _LikesTabState();
}

class _LikesTabState extends State<_LikesTab> {
  Position? _userPosition;
  String? _distanceStatus;

  static const _savedPlaces = [
    _SwipeCardData(
      title: 'Warung Madu 3 Parit Besar',
      tag: 'Saved',
      details: 'Hearty breakfast with a warm, local atmosphere.',
      color: Color(0xFFE76F51),
      rating: 4.1,
      latitude: 1.8683906,
      longitude: 102.957791,
      reviewName: 'Saved spot',
      reviewText: 'Warm service and a breakfast spread that feels inviting.',
      reviews: [
        _ReviewSnippet(
            author: 'You',
            text: 'Warm service and a breakfast spread that feels inviting.'),
      ],
      imageUrls: [
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Warung-Madu-3-Parit-Besar.jpg',
      ],
    ),
    _SwipeCardData(
      title: 'Warung Ahmad Nasi Lemak',
      tag: 'Liked',
      details: 'Fragrant nasi lemak with a dependable sambal kick.',
      color: Color(0xFFEE9B00),
      rating: 4.2,
      latitude: 1.8740357,
      longitude: 102.9415007,
      reviewName: 'Saved spot',
      reviewText: 'Fragrant nasi lemak, nice sambal, and a dependable stop.',
      reviews: [
        _ReviewSnippet(
            author: 'You',
            text: 'Fragrant nasi lemak, nice sambal, and a dependable stop.'),
      ],
      imageUrls: [
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Warung-Ahmad-Nasi-Lemak.jpg',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _userPosition = _dummyUserPosition();
  }

  String _distanceLabelFor(_SwipeCardData data) {
    final userPosition = _userPosition;
    if (userPosition == null) {
      return _distanceStatus ?? 'Distance loading';
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

    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km away';
    }

    return '${meters.toStringAsFixed(0)} m away';
  }

  @override
  Widget build(BuildContext context) {
    return _DashboardTabShell(
      title: 'Like',
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
            ..._savedPlaces.map(
              (data) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SpotPreviewCard(
                  data: data,
                  distanceText: _distanceLabelFor(data),
                  layout: _SpotPreviewLayout.list,
                  compactStats: false,
                  showActionStrip: false,
                  onTap: () => context.push(
                    '/restaurant',
                    extra: data.toDetailPayload(),
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

class _QuizTab extends StatefulWidget {
  const _QuizTab();

  @override
  State<_QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<_QuizTab> {
  int _selectedAnswer = -1;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final isAnswered = _submitted && _selectedAnswer >= 0;

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
            Text(
              'Choose one answer to get a suggestion.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.64),
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_quizAnswers.length, (index) {
              final answer = _quizAnswers[index];
              final selected = _selectedAnswer == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _QuizAnswerTile(
                  label: answer,
                  selected: selected,
                  onTap: () {
                    setState(() {
                      _selectedAnswer = index;
                      _submitted = true;
                    });
                  },
                ),
              );
            }),
            const SizedBox(height: 14),
            const _QuizResultCard(
              title: 'Best next bite',
              subtitle: 'Warung Wak Jaferi',
              body:
                  'A calm breakfast stop with a familiar local feel and a gentle morning pace.',
              accent: Color(0xFFB7E4C7),
            ),
            if (!isAnswered) ...[
              const SizedBox(height: 10),
              Text(
                'Select an answer above to refresh the suggestion.',
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
            const _PreferenceTile(
              icon: Icons.wb_sunny_rounded,
              title: 'Morning mode',
              subtitle: 'Show breakfast first',
              trailingLabel: 'On',
              tint: Color(0xFFF6D365),
            ),
            const SizedBox(height: 10),
            const _PreferenceTile(
              icon: Icons.local_fire_department_rounded,
              title: 'Spice bias',
              subtitle: 'Prioritize bolder flavors',
              trailingLabel: 'High',
              tint: Color(0xFFE76F51),
            ),
            const SizedBox(height: 10),
            const _PreferenceTile(
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
      decoration: const BoxDecoration(color: Color(0xFF0C0F14)),
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

class _GlassContainer extends StatelessWidget {
  const _GlassContainer({
    required this.child,
    required this.accent,
  });

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141922),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accent.withValues(alpha: 0.18),
          ),
        ),
        child: child,
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141922),
          borderRadius: BorderRadius.circular(20),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
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

enum _SpotPreviewLayout {
  compact,
  list,
}

class _SpotPreviewCard extends StatelessWidget {
  const _SpotPreviewCard({
    required this.data,
    required this.distanceText,
    required this.layout,
    required this.compactStats,
    required this.showActionStrip,
    this.onTap,
  });

  final _SwipeCardData data;
  final String distanceText;
  final _SpotPreviewLayout layout;
  final bool compactStats;
  final bool showActionStrip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isCompact = layout == _SpotPreviewLayout.compact;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: _GlassContainer(
          accent: data.color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(26),
                  topRight: Radius.circular(26),
                ),
                child: AspectRatio(
                  aspectRatio: isCompact ? 1.65 : 2.25,
                  child: Image.network(
                    data.imageUrls.first,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TagPill(label: data.tag, accent: data.color),
                        const Spacer(),
                        if (compactStats)
                          _MiniStat(
                            icon: Icons.star_rounded,
                            text: data.rating.toStringAsFixed(1),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.details,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.72),
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _InfoChip(
                          icon: Icons.star_rounded,
                          label: data.rating.toStringAsFixed(1),
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          icon: Icons.place_rounded,
                          label: distanceText,
                        ),
                      ],
                    ),
                    if (showActionStrip) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionChip(
                              icon: Icons.close_rounded,
                              label: 'Pass',
                              tint: const Color(0xFFE25555),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionChip(
                              icon: Icons.favorite_rounded,
                              label: 'Like',
                              tint: const Color(0xFF1F9D55),
                            ),
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
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(22),
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
    return _GlassContainer(
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

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.tint,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailingLabel;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      accent: tint,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: tint),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.66),
              ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            trailingLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

const List<String> _quizAnswers = [
  'I want something comforting and familiar.',
  'I want bold spice and bigger flavor.',
  'I want a quick, easy breakfast stop.',
];

class _SwipeDeck extends StatefulWidget {
  const _SwipeDeck();

  @override
  State<_SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<_SwipeDeck>
    with SingleTickerProviderStateMixin {
  final List<_SwipeCardData> _cards = const [
    _SwipeCardData(
      title: 'Mak Limah Asam Pedas',
      tag: 'Asam Pedas',
      details:
          'A Batu Pahat asam pedas spot known for its rich, spicy, and tangy comfort food. The card uses the actual storefront photo from the Batu Pahat food guide.',
      color: Color(0xFFF6D365),
      rating: 4.3,
      latitude: 1.8522138,
      longitude: 102.9253991,
      reviewName: 'Google Maps highlight',
      reviewText:
          'Rich, spicy, and very comforting. A must for asam pedas fans.',
      reviews: [
        _ReviewSnippet(
            author: 'Google Maps user',
            text:
                'Rich, spicy, and very comforting. A must for asam pedas fans.'),
        _ReviewSnippet(
            author: 'Google Maps user',
            text: 'Big flavor, balanced spice, and a really satisfying meal.'),
        _ReviewSnippet(
            author: 'Google Maps user',
            text:
                'The sauce is bold and the dish feels comforting every time.'),
      ],
      imageUrls: [
        'https://tempatcuti.my/wp-content/uploads/2023/12/Mak-Limah-Asam-Pedas.jpg',
        'https://tempatcuti.my/wp-content/uploads/2023/12/Asam-Pedas-Generation-Tambak-Batu-Pahat.jpg',
      ],
      videoUrl: 'https://www.tiktok.com/@johorfoodie/video/7647473389518540053',
    ),
    _SwipeCardData(
      title: 'Warung Wak Jaferi',
      tag: 'Breakfast',
      details:
          'A Batu Pahat breakfast stop with a relaxed morning feel and traditional local dishes. The photo is pulled from the Batu Pahat dining guide for a more authentic look.',
      color: Color(0xFFB7E4C7),
      rating: 4.4,
      latitude: 1.8406831,
      longitude: 102.9430163,
      reviewName: 'Google Maps highlight',
      reviewText:
          'Calm breakfast spot with traditional dishes that feel homely and fresh.',
      reviews: [
        _ReviewSnippet(
            author: 'Google Maps user',
            text:
                'Calm breakfast spot with traditional dishes that feel homely and fresh.'),
        _ReviewSnippet(
            author: 'Google Maps user',
            text:
                'Friendly atmosphere and a breakfast plate that feels easy to enjoy.'),
        _ReviewSnippet(
            author: 'Google Maps user',
            text: 'Simple, comforting, and a nice place to start the day.'),
      ],
      imageUrls: [
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Warung-Wak-Jaferi.jpg',
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Warung-Zai-Kak-Zai-Nasi-Lemak.jpg',
      ],
      videoUrl: 'https://www.tiktok.com/@johorfoodie/video/7639688200797064469',
    ),
    _SwipeCardData(
      title: 'Selera Izzati',
      tag: 'Breakfast',
      details:
          'A Batu Pahat morning food spot that keeps the deck varied with another local breakfast option. The card uses the actual restaurant photo instead of a generic food image.',
      color: Color(0xFFF4A261),
      rating: 4.1,
      latitude: 1.8471209,
      longitude: 102.9334028,
      reviewName: 'Google Maps highlight',
      reviewText:
          'Simple, satisfying Malay breakfast with a very easygoing vibe.',
      reviews: [
        _ReviewSnippet(
            author: 'Google Maps user',
            text:
                'Simple, satisfying Malay breakfast with a very easygoing vibe.'),
        _ReviewSnippet(
            author: 'Google Maps user',
            text: 'Good value, easy to eat, and a relaxed morning stop.'),
        _ReviewSnippet(
            author: 'Google Maps user',
            text: 'A dependable breakfast place with familiar flavors.'),
      ],
      imageUrls: [
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Selera-Izzati.jpg',
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Gerai-Makan-Hidayah.jpg',
      ],
      videoUrl: 'https://www.tiktok.com/@johorfoodie/video/7636253229818350869',
    ),
    _SwipeCardData(
      title: 'Warung Madu 3 Parit Besar',
      tag: 'Breakfast',
      details:
          'A Batu Pahat breakfast spot with a warm, local feel and a photo that matches the actual restaurant frontage from the guide.',
      color: Color(0xFFE76F51),
      rating: 4.1,
      latitude: 1.8683906,
      longitude: 102.957791,
      reviewName: 'Google Maps highlight',
      reviewText:
          'Warm service and a breakfast spread that feels hearty and inviting.',
      reviews: [
        _ReviewSnippet(
            author: 'Google Maps user',
            text:
                'Warm service and a breakfast spread that feels hearty and inviting.'),
        _ReviewSnippet(
            author: 'Google Maps user',
            text: 'Comforting food with a friendly, welcoming feel.'),
        _ReviewSnippet(
            author: 'Google Maps user',
            text: 'Nice morning stop with a cozy local breakfast vibe.'),
      ],
      imageUrls: [
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Warung-Madu-3-Parit-Besar.jpg',
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Hans-Nasi-Lemak-Ayam-Kamung-Benteng-BP.jpg',
      ],
      videoUrl: 'https://www.tiktok.com/@johorfoodie/video/7631138703229930760',
    ),
    _SwipeCardData(
      title: 'Warung Ahmad Nasi Lemak',
      tag: 'Nasi Lemak',
      details:
          'A Batu Pahat nasi lemak stop with a familiar local breakfast vibe and an actual restaurant photo from the guide.',
      color: Color(0xFFEE9B00),
      rating: 4.2,
      latitude: 1.8740357,
      longitude: 102.9415007,
      reviewName: 'Google Maps highlight',
      reviewText:
          'Fragrant nasi lemak, nice sambal, and a dependable breakfast stop.',
      reviews: [
        _ReviewSnippet(
            author: 'Google Maps user',
            text:
                'Fragrant nasi lemak, nice sambal, and a dependable breakfast stop.'),
        _ReviewSnippet(
            author: 'Google Maps user',
            text: 'Good sambal kick and a breakfast plate that hits the spot.'),
        _ReviewSnippet(
            author: 'Google Maps user',
            text: 'A reliable nasi lemak stop with a familiar local feel.'),
      ],
      imageUrls: [
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Warung-Ahmad-Nasi-Lemak.jpg',
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Warung-Zai-Kak-Zai-Nasi-Lemak.jpg',
      ],
    ),
  ];

  int _index = 0;
  Offset _dragOffset = Offset.zero;
  bool _infoExpanded = false;
  bool _reviewInteractionActive = false;
  Position? _userPosition;
  String? _distanceStatus;

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

  @override
  void initState() {
    super.initState();
    _warmInitialTikTokPlayers();
    _userPosition = _dummyUserPosition();
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
      () => _createTikTokPlayerController(videoUrl),
    );
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  void _handleLike() => _animateOut(true);
  void _handleDislike() => _animateOut(false);

  void _animateOut(bool liked) {
    if (_index >= _cards.length || _motionType != _SwipeMotionType.idle) {
      return;
    }

    setState(() {
      _motionType = _SwipeMotionType.swipeOut;
      _animationStartOffset = _dragOffset;
      _animationEndOffset = Offset(liked ? 460 : -460, -220);
    });

    _motionController.forward(from: 0);
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
    return data.rating.toStringAsFixed(1);
  }

  String _distanceLabelFor(_SwipeCardData data) {
    final userPosition = _userPosition;
    if (userPosition == null) {
      return _distanceStatus ?? 'Distance loading';
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

  void _setReviewInteractionActive(bool active) {
    if (_reviewInteractionActive == active) {
      return;
    }

    setState(() {
      _reviewInteractionActive = active;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= _cards.length) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: FCard(
            title: const Text('No more cards'),
            subtitle: const Text('Restart to keep swiping.'),
            child: FButton(
              variant: FButtonVariant.outline,
              onPress: () {
                setState(() {
                  _index = 0;
                  _dragOffset = Offset.zero;
                  _infoExpanded = false;
                  _motionType = _SwipeMotionType.idle;
                  _animationStartOffset = Offset.zero;
                  _animationEndOffset = Offset.zero;
                  _motionController.reset();
                });
              },
              child: const Text('Restart deck'),
            ),
          ),
        ),
      );
    }

    final current = _cards[_index];
    final next = _index + 1 < _cards.length ? _cards[_index + 1] : null;
    final currentPlayerFuture = _preloadTikTokPlayer(current.videoUrl);
    final nextPlayerFuture = _preloadTikTokPlayer(next?.videoUrl);
    final motionProgress =
        Curves.easeInOutCubic.transform(_motionController.value);
    final currentOffset = _motionType == _SwipeMotionType.idle
        ? _dragOffset
        : ui.Offset.lerp(
              _animationStartOffset,
              _animationEndOffset,
              motionProgress,
            ) ??
            _dragOffset;
    final dragPercentage = (currentOffset.dx.abs() / 260).clamp(0.0, 1.0);
    final rotation = currentOffset.dx / 900;
    final showLike = currentOffset.dx > 20;
    final showNope = currentOffset.dx < -20;
    final transitionLift = Curves.easeOutCubic.transform(dragPercentage);
    final currentRating = _ratingText(current);
    final currentDistance = _distanceLabelFor(current);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _FloatingHeader(),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (next != null)
                    Positioned.fill(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 120),
                        opacity: 0.82 + (transitionLift * 0.18),
                        child: Transform.translate(
                          offset: Offset(0, 22 - (transitionLift * 22)),
                          child: Transform.scale(
                            scale: 0.92 + (transitionLift * 0.08),
                            child: _SwipeCard(
                              key: ValueKey(next.title),
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
                              onPass: () => _triggerAction(false),
                              onLike: () => _triggerAction(true),
                            ),
                          ),
                        ),
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
                          final scale = _motionType == _SwipeMotionType.swipeOut
                              ? ui.lerpDouble(1, 0.982, motionProgress) ?? 1
                              : ui.lerpDouble(1, 0.995, motionProgress) ?? 1;
                          final opacity =
                              _motionType == _SwipeMotionType.swipeOut
                                  ? ui.lerpDouble(1, 0.84, motionProgress) ?? 1
                                  : 1.0;

                          return Opacity(
                            opacity: opacity,
                            child: Transform.translate(
                              offset: currentOffset,
                              child: Transform.rotate(
                                angle: rotation,
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
                              key: ValueKey(current.title),
                              data: current,
                              likeOpacity: showLike ? dragPercentage : 0,
                              nopeOpacity: showNope ? dragPercentage : 0,
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
          ],
        );
      },
    );
  }
}

class _FloatingHeader extends StatelessWidget {
  const _FloatingHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          Positioned.fill(
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
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, left: 16, right: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.34),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.place_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Peserai, Batu Pahat',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      context.push('/settings');
                    },
                    icon: const Icon(
                      Icons.settings_rounded,
                      color: Colors.white,
                    ),
                    splashRadius: 22,
                    tooltip: 'Settings',
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
    if (oldWidget.data.title != widget.data.title) {
      _imageIndex = 0;
    }
  }

  @override
  void dispose() {
    super.dispose();
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
    const bottomRadius = Radius.circular(40);
    final hasMultipleImages = widget.data.imageUrls.length > 1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            bottomLeft: bottomRadius,
            bottomRight: bottomRadius,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: bottomRadius,
                bottomRight: bottomRadius,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
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
                                  return const SizedBox.expand();
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
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: AppSpacing.screenPadding + 4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RestaurantInfoPanel(
                        data: widget.data,
                        expanded: widget.infoExpanded,
                        ratingText: widget.ratingText,
                        distanceText: widget.distanceText,
                        imageIndex: _imageIndex,
                        hasMultipleImages: hasMultipleImages,
                        onTap: widget.onInfoTap,
                        onReviewInteractionChanged:
                            widget.onReviewInteractionChanged,
                      ),
                      if (widget.onPass != null && widget.onLike != null) ...[
                        const SizedBox(height: 3),
                        _SwipeActionBar(
                          onPass: widget.onPass!,
                          onLike: widget.onLike!,
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
    required this.imageIndex,
    required this.hasMultipleImages,
    required this.onTap,
    required this.onReviewInteractionChanged,
  });

  final _SwipeCardData data;
  final bool expanded;
  final String ratingText;
  final String distanceText;
  final int imageIndex;
  final bool hasMultipleImages;
  final VoidCallback onTap;
  final ValueChanged<bool> onReviewInteractionChanged;

  @override
  State<_RestaurantInfoPanel> createState() => _RestaurantInfoPanelState();
}

class _RestaurantInfoPanelState extends State<_RestaurantInfoPanel>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.black.withValues(alpha: 0.16),
          child: InkWell(
            onTap: widget.onTap,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.hasMultipleImages) ...[
                      _ImageProgressDots(
                        count: widget.data.imageUrls.length,
                        activeIndex: widget.imageIndex,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _TagPill(
                      label: widget.data.tag,
                      accent: widget.data.color,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.data.title,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoPill(
                          icon: Icons.star_rounded,
                          label: widget.ratingText,
                        ),
                        _InfoPill(
                          icon: Icons.place_rounded,
                          label: widget.distanceText,
                        ),
                      ],
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: widget.expanded
                          ? Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.data.details,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          height: 1.35,
                                          color: Colors.white
                                              .withValues(alpha: 0.82),
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
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeActionBar extends StatelessWidget {
  const _SwipeActionBar({
    required this.onPass,
    required this.onLike,
  });

  final VoidCallback onPass;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.14),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _ConnectedActionButton(
                    icon: Icons.close_rounded,
                    label: 'Pass',
                    color: const Color(0xFFE25555),
                    onTap: onPass,
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                Expanded(
                  child: _ConnectedActionButton(
                    icon: Icons.favorite_rounded,
                    label: 'Like',
                    color: const Color(0xFF1F9D55),
                    onTap: onLike,
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

class _ConnectedActionButton extends StatelessWidget {
  const _ConnectedActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatefulWidget {
  const _TagPill({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  State<_TagPill> createState() => _TagPillState();
}

class _TagPillState extends State<_TagPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTapDown: (_) {
          setState(() {
            _pressed = true;
          });
        },
        onTapCancel: () {
          setState(() {
            _pressed = false;
          });
        },
        onTap: () {
          setState(() {
            _pressed = !_pressed;
          });
        },
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          scale: _pressed ? 0.96 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: _pressed ? 0.28 : 0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: widget.accent.withValues(alpha: _pressed ? 0.45 : 0.28),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      widget.accent.withValues(alpha: _pressed ? 0.18 : 0.08),
                  blurRadius: _pressed ? 12 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.10,
                        fontSize: 9,
                      ),
                ),
                const SizedBox(width: 5),
                Icon(
                  _pressed
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ),
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
  controller
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.black)
    ..setUserAgent(
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
      'Mobile/15E148 Safari/604.1',
    )
    ..setNavigationDelegate(NavigationDelegate());

  final videoId = _extractTikTokVideoId(videoUrl);
  final playerUrl = videoId == null
      ? videoUrl
      : 'https://www.tiktok.com/player/v1/$videoId?autoplay=1&controls=1&volume_control=1&muted=0&music_info=1&description=1&timestamp=1&rel=0&loop=1';

  await controller.loadHtmlString(
    _buildTikTokPlayerHtml(playerUrl),
    baseUrl: 'https://www.tiktok.com',
  );

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
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.48),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
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

String _buildTikTokPlayerHtml(String playerUrl) {
  return '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, viewport-fit=cover">
    <style>
      html, body {
        margin: 0;
        padding: 0;
        width: 100%;
        height: 100%;
        overflow: hidden;
        background: #000;
      }
      .player {
        position: relative;
        width: 100%;
        height: 100%;
      }
      iframe {
        position: absolute;
        inset: 0;
        width: 100%;
        height: 100%;
        border: 0;
      }
    </style>
  </head>
  <body>
    <div class="player">
      <iframe
        id="tiktok-player"
        src="$playerUrl"
        allow="autoplay; fullscreen; picture-in-picture"
        allowfullscreen
        scrolling="no"
      ></iframe>
    </div>
    <script>
      const iframe = document.getElementById('tiktok-player');
      const sendCommand = (type) => {
        if (!iframe || !iframe.contentWindow) {
          return;
        }

        iframe.contentWindow.postMessage(
          {
            'x-tiktok-player': true,
            type: type,
            value: null,
          },
          '*',
        );
      };

      const startPlayback = () => {
        sendCommand('unMute');
        sendCommand('play');
      };

      iframe.addEventListener('load', () => {
        setTimeout(startPlayback, 400);
        setTimeout(startPlayback, 1200);
      });
    </script>
  </body>
</html>
''';
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
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w600,
                        fontSize: 9,
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
        borderRadius: BorderRadius.circular(18),
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
            borderRadius: BorderRadius.circular(999),
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
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

/*
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FloatingIconButton(
          icon: icon,
          onTap: onTap,
          color: label == 'Like'
              ? const Color(0xFF1F9D55)
              : const Color(0xFFE25555),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _FloatingIconButton extends StatelessWidget {
  const _FloatingIconButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final background = color ?? Colors.white.withValues(alpha: 0.16);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: background,
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
*/

class _SwipeCardData {
  const _SwipeCardData({
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
  });

  factory RestaurantDetailData.fromPayload(Map<String, dynamic> payload) {
    return RestaurantDetailData(
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
    );
  }

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
}

extension _SwipeCardDataPayload on _SwipeCardData {
  Map<String, dynamic> toDetailPayload() {
    return {
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

class _RestaurantDetailPageState extends State<RestaurantDetailPage> {
  Position? _userPosition;
  String? _distanceStatus;

  @override
  void initState() {
    super.initState();
    _userPosition = _dummyUserPosition();
  }

  String _distanceLabel() {
    final userPosition = _userPosition;
    if (userPosition == null) {
      return _distanceStatus ?? 'Distance loading';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.data.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          8,
          AppSpacing.screenPadding,
          24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 1.45,
                child: Image.network(
                  widget.data.imageUrls.isNotEmpty
                      ? widget.data.imageUrls.first
                      : 'https://via.placeholder.com/800x500',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.data.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.data.details,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DetailChip(
                  icon: Icons.star_rounded,
                  label: widget.data.rating.toStringAsFixed(1),
                ),
                _DetailChip(
                  icon: Icons.place_rounded,
                  label: _distanceLabel(),
                ),
                if (widget.data.tag.isNotEmpty)
                  _DetailChip(
                    icon: Icons.local_dining_rounded,
                    label: widget.data.tag,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _DetailCard(
              title: 'More photos',
              child: Column(
                children: widget.data.imageUrls
                    .map(
                      (imageUrl) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AspectRatio(
                            aspectRatio: 1.7,
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            _DetailCard(
              title: 'Location',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_pin, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_distanceLabel()} from your location',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _DetailCard(
              title: 'Top review',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.data.reviewName,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.data.reviewText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          height: 1.35,
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

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
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
        color: const Color(0xFF141922),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
