import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/design_tokens.dart';
import '../../auth/state/auth_controller.dart';
import '../../profile/presentation/profile_tab.dart';
import '../../restaurants/data/likes_migration.dart';
import '../../restaurants/presentation/swipe_deck.dart';
import '../../restaurants/state/likes_controller.dart';
import 'explore_tab.dart';
import 'group_tab.dart';
import 'likes_tab.dart';

/// The signed-in home: five tabs behind one bottom bar.
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
      builder: (context, _) => _DashboardShell(authController: authController),
    );
  }
}

class _DashboardShell extends StatefulWidget {
  const _DashboardShell({required this.authController});

  final AuthController authController;

  @override
  State<_DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<_DashboardShell>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  /// Fades the newly selected tab in. Starts completed so the first tab is
  /// simply there — the dashboard has just crossfaded in from the splash, and
  /// a second fade on top of that reads as a stutter.
  ///
  /// One shot per selection: the tabs are all mounted at once behind an
  /// IndexedStack, so anything that kept running would animate a resting
  /// screen.
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: 1,
  );

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

  @override
  void dispose() {
    _tabFade.dispose();
    super.dispose();
  }

  void _setSelectedIndex(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
    _tabFade.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      bottomNavigationBar: _DashboardBottomNav(
        selectedIndex: _selectedIndex,
        onSelected: _setSelectedIndex,
      ),
      // An IndexedStack, not a swap: rebuilding a tab on every visit would
      // re-deal the deck and refetch the map each time the user glanced at
      // another tab. The switch itself is instant, so the fade below is what
      // makes it read as a change of screen rather than as a repaint.
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _tabFade, curve: Curves.easeOutCubic),
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            SwipeDeck(authController: widget.authController),
            const ExploreTab(),
            const LikesTab(),
            const GroupTab(),
            ProfileTab(authController: widget.authController),
          ],
        ),
      ),
    );
  }
}

/// The floating tab bar: a dark pill carrying all five tabs as equals. No tab
/// is raised out of the row; the selected one is marked by an ember pill
/// behind its icon, the same accent the buttons and focus rings use.
///
/// Diverges from the Figma, which draws the selection as a white ring. A ring
/// is a shape the rest of the app never uses, and it said "selected" only by
/// being there — the ember fill says it in the app's own colour, and the
/// outline/filled icon pair says it a second time for anyone who cannot pick
/// the tint out.
class _DashboardBottomNav extends StatelessWidget {
  const _DashboardBottomNav({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Height of the pill itself. Enough for a 48 px touch target under the
  /// indicator and its label, and no more.
  static const double _barHeight = 70;

  /// The tabs drawn in the pill, left to right, with the `IndexedStack` index
  /// each one selects.
  ///
  /// Every tab carries an outline glyph for its resting state and a solid one
  /// for the selected state, so the current tab is legible without relying on
  /// colour alone.
  static const _tabs =
      <({IconData icon, IconData activeIcon, String label, int index})>[
    (
      icon: Icons.style_outlined,
      activeIcon: Icons.style_rounded,
      label: 'Swipe',
      index: 0,
    ),
    (
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
      label: 'Explore',
      index: 1,
    ),
    // A heart, not a thumbs-up: the deck's like button is a heart and the Liked
    // grid badges hearts, so the tab that collects them should be the same
    // glyph.
    (
      icon: Icons.favorite_border_rounded,
      activeIcon: Icons.favorite_rounded,
      label: 'Liked',
      index: 2,
    ),
    (
      icon: Icons.groups_outlined,
      activeIcon: Icons.groups_rounded,
      label: 'Group',
      index: 3,
    ),
    (
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
      index: 4,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          height: _barHeight,
          decoration: BoxDecoration(
            color: kSurfaceDark,
            borderRadius: BorderRadius.circular(kRadiusPill),
            border: Border.all(color: kHairline),
          ),
          child: Row(
            children: [
              for (final tab in _tabs)
                Expanded(
                  child: _BottomNavItem(
                    icon: tab.icon,
                    activeIcon: tab.activeIcon,
                    label: tab.label,
                    isSelected: selectedIndex == tab.index,
                    onTap: () => onSelected(tab.index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tab in the pill: a solid icon on an ember pill when selected, an
/// outline icon on nothing when not, over a small label.
class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isSelected;
  final VoidCallback onTap;

  /// The selection pill behind the icon. Wider than it is tall so five of them
  /// sit in the bar without crowding the labels.
  static const double _indicatorWidth = 44;
  static const double _indicatorHeight = 30;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? kAccentEmber : kTextOnPhotoMuted;

    return Semantics(
      label: label,
      button: true,
      selected: isSelected,
      child: _PressScale(
        onTap: onTap,
        child: SizedBox(
          height: _DashboardBottomNav._barHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: _indicatorWidth,
                height: _indicatorHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? kAccentEmber.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(kRadiusPill),
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  size: 21,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              // The bar is a fixed height that the rest of the layout sits
              // above, so the label cannot be allowed to grow without bound —
              // past a point it would push itself out of the pill. It stops
              // scaling where it still fits; the screens themselves scale all
              // the way.
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
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

/// Tap target that dips under the finger.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) {
        _setPressed(true);
        unawaited(HapticFeedback.selectionClick());
      },
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.92 : 1.0,
        child: widget.child,
      ),
    );
  }
}
