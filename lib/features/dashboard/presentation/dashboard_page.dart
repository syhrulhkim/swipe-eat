import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/design_tokens.dart';
import '../../auth/state/auth_controller.dart';
import '../../profile/presentation/profile_tab.dart';
import '../../restaurants/data/likes_migration.dart';
import '../../restaurants/data/visit_prompt_cache.dart';
import '../../restaurants/presentation/swipe_deck.dart';
import '../../restaurants/presentation/visit_prompt_sheet.dart';
import '../../restaurants/state/likes_controller.dart';
import '../../restaurants/state/visit_prompt_controller.dart';
import 'explore_tab.dart';
import 'group_tab.dart';
import 'likes_tab.dart';

/// The signed-in home: five tabs behind one bottom bar.
class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.authController,
    this.visitPrompts,
  });

  final AuthController authController;

  /// Injected by tests; in the app the shared instance is used.
  final VisitPromptController? visitPrompts;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: authController,
      builder: (context, _) => _DashboardShell(
        authController: authController,
        visitPrompts: visitPrompts,
      ),
    );
  }
}

class _DashboardShell extends StatefulWidget {
  const _DashboardShell({required this.authController, this.visitPrompts});

  final AuthController authController;
  final VisitPromptController? visitPrompts;

  @override
  State<_DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<_DashboardShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;

  late final VisitPromptController _visitPrompts =
      widget.visitPrompts ?? VisitPromptController.instance;

  /// One question at a time. The prompt is triggered from two places that can
  /// both fire around a resume, and two sheets over each other would be a bug
  /// the user has to dismiss twice.
  bool _askingAboutVisit = false;

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
    WidgetsBinding.instance.addObserver(this);
    // One-time move of pre-auth device likes into the swipes table. Never
    // blocks the dashboard; a failed run retries on the next launch.
    unawaited(migrateDeviceLikes().then((migrated) {
      if (migrated) {
        LikesController.instance.refresh().catchError((Object error) {
          debugPrint('Post-migration likes refresh failed: $error');
        });
      }
    }));
    // A cold launch is the other way back into the app; the lifecycle callback
    // below only fires for a resume. After the first frame, so the sheet has a
    // laid-out route to open over.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeAskAboutVisit());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabFade.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Coming back from the maps app lands here. The cache's own age rule
    // decides whether enough time has passed to be worth asking.
    if (state == AppLifecycleState.resumed) {
      unawaited(_maybeAskAboutVisit());
    }
  }

  /// Asks about the most recent place the app sent the user to, if one is ripe.
  ///
  /// Silent about everything except a failed write: there is no error worth
  /// interrupting a launch for when the app merely could not think of a
  /// question to ask.
  Future<void> _maybeAskAboutVisit() async {
    if (_askingAboutVisit) {
      return;
    }
    _askingAboutVisit = true;

    try {
      final pending = await _visitPrompts.next();
      if (pending == null || !mounted) {
        return;
      }

      // Not while a restaurant page or a sheet is on top: the question would
      // arrive over something the user is in the middle of.
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) {
        return;
      }

      final answer = await showVisitPromptSheet(context, visit: pending);
      if (answer == null || !mounted) {
        // Dismissed without answering: the trip stays pending and the question
        // comes back next time.
        return;
      }

      await _recordVisitAnswer(pending, answer);
    } finally {
      _askingAboutVisit = false;
    }
  }

  Future<void> _recordVisitAnswer(
    PendingVisit pending,
    VisitAnswer answer,
  ) async {
    try {
      if (answer == VisitAnswer.went) {
        await _visitPrompts.confirm(pending);
      } else {
        await _visitPrompts.dismiss(pending);
      }
      // No refresh of the Liked tab's Visited segment: it loads lazily, so an
      // unopened one already fetches this visit on its first open. One the user
      // has opened this run stays as it was until they pull to refresh — the
      // same launch-snapshot behaviour the IndexedStack gives every tab.
    } on Object catch (error) {
      // The cache is only cleared after the write lands, so the question
      // survives to be asked again.
      debugPrint('Visit answer failed: $error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not mark that place visited.')),
      );
      return;
    }

    if (!mounted || answer != VisitAnswer.went) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${pending.name} marked as visited.')),
    );
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
