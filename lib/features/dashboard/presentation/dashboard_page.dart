import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/design_tokens.dart';
import '../../auth/state/auth_controller.dart';
import '../../profile/presentation/profile_tab.dart';
import '../../quiz/presentation/quiz_tab.dart';
import '../../restaurants/data/likes_migration.dart';
import '../../restaurants/presentation/swipe_deck.dart';
import '../../restaurants/state/likes_controller.dart';
import 'explore_tab.dart';
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
      builder: (context, _) =>
          _DashboardShell(authController: authController),
    );
  }
}

class _DashboardShell extends StatefulWidget {
  const _DashboardShell({required this.authController});

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
    return Scaffold(
      backgroundColor: kBackgroundDark,
      bottomNavigationBar: _DashboardBottomNav(
        selectedIndex: _selectedIndex,
        onSelected: _setSelectedIndex,
      ),
      // An IndexedStack, not a swap: rebuilding a tab on every visit would
      // re-deal the deck and refetch the map each time the user glanced at
      // another tab.
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          SwipeDeck(authController: widget.authController),
          ExploreTab(authController: widget.authController),
          const LikesTab(),
          const QuizTab(),
          ProfileTab(user: widget.authController.user),
        ],
      ),
    );
  }
}

/// The floating tab bar: a dark pill carrying the four secondary tabs, with
/// the deck raised out of it as a centre disc.
///
/// The deck is the one thing the app is for, so it does not sit in the row as
/// a peer of Quiz and Profile — it is the button you cannot miss, in the place
/// a thumb already rests. The other four keep their [_kTabOrder] index into
/// the shell's `IndexedStack`; only where they are drawn changes.
class _DashboardBottomNav extends StatelessWidget {
  const _DashboardBottomNav({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Height of the pill itself.
  static const double _barHeight = 66;

  /// Diameter of the centre disc.
  static const double _discSize = 64;

  /// How far the disc's top clears the pill's, which is also the extra height
  /// the bar has to reserve so the raised half is not clipped away.
  static const double _discRaise = 26;

  static const _deckIndex = 0;

  /// The tabs drawn in the pill, left to right, with the `IndexedStack` index
  /// each one selects.
  static const _tabs = <({IconData icon, String label, int index})>[
    (icon: Icons.explore_rounded, label: 'Explore', index: 1),
    (icon: Icons.favorite_rounded, label: 'Like', index: 2),
    (icon: Icons.quiz_rounded, label: 'Quiz', index: 3),
    (icon: Icons.person_rounded, label: 'Profile', index: 4),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SizedBox(
          height: _barHeight + _discRaise,
          child: Stack(
            // The disc deliberately overhangs the pill; clipping the stack
            // would slice its top off.
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _barHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: kSurfaceDark,
                    borderRadius: BorderRadius.circular(kRadiusPill),
                    border: Border.all(color: kHairline),
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < _tabs.length; i++) ...[
                        // The gap the disc sits in, between tab two and three.
                        if (i == 2) const SizedBox(width: _discSize + 16),
                        Expanded(
                          child: _BottomNavItem(
                            icon: _tabs[i].icon,
                            label: _tabs[i].label,
                            isSelected: selectedIndex == _tabs[i].index,
                            onTap: () => onSelected(_tabs[i].index),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: _discSize,
                child: Center(
                  child: _DeckDisc(
                    isSelected: selectedIndex == _deckIndex,
                    onTap: () => onSelected(_deckIndex),
                    size: _discSize,
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

/// The raised centre control that returns to the deck.
class _DeckDisc extends StatelessWidget {
  const _DeckDisc({
    required this.isSelected,
    required this.onTap,
    required this.size,
  });

  final bool isSelected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Swipe',
      button: true,
      selected: isSelected,
      child: _PressScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            // Cream while the deck is up, matching the primary pill: the disc
            // is the same "this is the action" signal in a different shape.
            color: isSelected ? kAccentCream : kSurfacePanel,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.transparent : kHairline,
              width: 4,
            ),
          ),
          child: Icon(
            Icons.swipe_rounded,
            size: 28,
            color: isSelected ? kOnAccent : kTextOnPhoto,
          ),
        ),
      ),
    );
  }
}

/// One flat tab in the pill: icon over a small label, warm when selected.
class _BottomNavItem extends StatelessWidget {
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
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tap target that dips under the finger. Shared by the tabs and the disc so
/// both answer a press the same way.
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
