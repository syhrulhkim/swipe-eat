import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

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
      // An IndexedStack, not a swap: rebuilding a tab on every visit would
      // re-deal the deck and refetch the map each time the user glanced at
      // another tab.
      child: IndexedStack(
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

class _DashboardBottomNav extends StatelessWidget {
  const _DashboardBottomNav({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.swipe_rounded, label: 'Swipe'),
    (icon: Icons.explore_rounded, label: 'Explore'),
    (icon: Icons.favorite_rounded, label: 'Like'),
    (icon: Icons.quiz_rounded, label: 'Quiz'),
    (icon: Icons.person_rounded, label: 'Profile'),
  ];

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
              border: Border.all(color: kHairline),
            ),
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  _BottomNavItem(
                    icon: _items[i].icon,
                    label: _items[i].label,
                    isSelected: selectedIndex == i,
                    onTap: () => onSelected(i),
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
              unawaited(HapticFeedback.selectionClick());
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
                      ? kAccentEmber
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
                  color: widget.isSelected ? kOnAccent : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
