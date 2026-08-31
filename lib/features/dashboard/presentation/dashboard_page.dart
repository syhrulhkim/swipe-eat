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

/// The floating tab bar: a dark pill carrying all five tabs as equals, the
/// way the Figma draws it. The selected tab's icon sits inside a ring — the
/// bar's one highlight — rather than raising any tab out of the row.
class _DashboardBottomNav extends StatelessWidget {
  const _DashboardBottomNav({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Height of the pill itself.
  static const double _barHeight = 78;

  /// The tabs drawn in the pill, left to right, with the `IndexedStack` index
  /// each one selects.
  static const _tabs = <({IconData icon, String label, int index})>[
    (icon: Icons.swipe_rounded, label: 'Swipe', index: 0),
    (icon: Icons.explore_rounded, label: 'Explore', index: 1),
    (icon: Icons.thumb_up_rounded, label: 'Liked', index: 2),
    (icon: Icons.groups_rounded, label: 'Group', index: 3),
    (icon: Icons.person_rounded, label: 'Profile', index: 4),
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

/// One tab in the pill: icon in a ring when selected, over a small label.
class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  /// Diameter of the ring around the selected icon.
  static const double _ringSize = 40;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? kTextOnPhoto : kTextOnPhotoMuted;

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
                width: _ringSize,
                height: _ringSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? kTextOnPhoto : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
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
