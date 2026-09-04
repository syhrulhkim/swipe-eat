import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/design_tokens.dart';

/// The floating tab bar: a dark pill carrying all five tabs, where the current
/// one **widens into a labelled ember pill** and the rest are icons.
///
/// Only the selected tab is labelled, which is the whole idea — the bar spends
/// its width on the one answer the user is looking for ("where am I?") instead
/// of spreading it evenly across five they already know. The label is not the
/// only marker: the fill, the ink colour and the filled-vs-outline glyph each
/// say it independently, so the bar survives being read without colour.
///
/// Every tab keeps its name in the semantics tree whether or not it is drawn,
/// so a screen reader never meets four unlabelled buttons.
class DashboardBottomNav extends StatelessWidget {
  const DashboardBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Height of the bar itself, and the inset of the tabs within it. A 52 px
  /// tab inside 5 px of padding and a 1 px border is the prototype's geometry.
  ///
  /// The border counts: Flutter adds a `BoxDecoration`'s border to the
  /// container's effective padding, so leaving it out of [_tabHeight] computes
  /// 54 for a tab the `Row` then constrains to 52 anyway. The arithmetic is
  /// spelled out so adjusting [_barPadding] gives the right answer.
  static const double _barHeight = 64;
  static const double _barPadding = 5;
  static const double _barBorder = 1;
  static const double _tabHeight =
      _barHeight - (_barPadding + _barBorder) * 2;

  /// The smallest a tab may be along either axis. Material asks for 48 and the
  /// iOS HIG for 44; the larger of the two governs.
  static const double _minTabExtent = 48;

  /// How far the active pill may grow before it starves the other four.
  ///
  /// The pill takes its width as a *share* of the bar, so on a narrow screen a
  /// fixed 2.3 ratio squeezes the four inactive tabs under the minimum touch
  /// target — at 320 px they come out at 43.8, which is a real miss on an
  /// iPhone SE and on any split-screen or foldable width. The ratio is
  /// therefore a maximum, not a constant: it is whatever still leaves the
  /// inactive tabs [_minTabExtent] wide.
  static int selectedFlexFor(double width) {
    const resting = _BottomNavItem.restingFlex;
    // The flex total at which an inactive tab is exactly _minTabExtent wide.
    final budget = width / _minTabExtent * resting;
    final allowed = (budget - resting * (_tabs.length - 1)).floor();

    return allowed.clamp(resting, _BottomNavItem.maxSelectedFlex);
  }

  /// The tabs drawn in the bar, left to right, with the `IndexedStack` index
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
    // A heart, not a thumbs-up: the deck's like button is a heart and the Bites
    // grid badges hearts, so the tab that collects them should be the same
    // glyph. The design forbids a bare heart for the like *action*, not for the
    // tab that collects them — its own Bites glyph is a heart too.
    (
      icon: Icons.favorite_border_rounded,
      activeIcon: Icons.favorite_rounded,
      label: 'Bites',
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
      label: 'You',
      index: 4,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Container(
          height: _barHeight,
          padding: const EdgeInsets.all(_barPadding),
          decoration: BoxDecoration(
            color: kSurfaceDark,
            borderRadius: BorderRadius.circular(kRadiusPill),
            border: Border.all(color: kHairline),
            boxShadow: kCardShadow,
          ),
          // The bar is a fixed height the rest of the layout sits above, so a
          // label that grew without bound would push itself out of it. It
          // stops scaling where it still fits; the screens themselves scale
          // all the way.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final selectedFlex = selectedFlexFor(constraints.maxWidth);

                return Row(
                  children: [
                    for (final tab in _tabs)
                      _BottomNavItem(
                        icon: tab.icon,
                        activeIcon: tab.activeIcon,
                        label: tab.label,
                        isSelected: selectedIndex == tab.index,
                        selectedFlex: selectedFlex,
                        onTap: () => onSelected(tab.index),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// One tab in the bar: an ember pill carrying a solid icon and the tab's name
/// when selected, a bare outline icon when not.
///
/// The width is animated rather than switched, because the pill growing out of
/// the icon is what ties the new tab to the tap that chose it. Flex is an int,
/// so the tween runs at a scale of 100 — a granularity far finer than a pixel
/// at these widths.
class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.selectedFlex,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isSelected;
  final VoidCallback onTap;

  /// What this tab grows to when it is the current one, decided by the bar
  /// from its own width — see [DashboardBottomNav.selectedFlexFor].
  final int selectedFlex;

  /// Share of the bar an inactive tab takes, and the most the active one may
  /// grow to. 2.3 is the prototype's ratio: enough for the longest label
  /// ("Explore") without starving the other four, on a screen wide enough to
  /// afford it.
  static const int restingFlex = 100;
  static const int maxSelectedFlex = 230;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        end: isSelected
            ? selectedFlex.toDouble()
            : restingFlex.toDouble(),
      ),
      duration: kMotionDuration,
      curve: kMotionEase,
      builder: (context, flex, child) {
        return Expanded(flex: flex.round(), child: child!);
      },
      child: _BottomNavPill(
        icon: icon,
        activeIcon: activeIcon,
        label: label,
        isSelected: isSelected,
        onTap: onTap,
      ),
    );
  }
}

/// The pill itself, kept out of [_BottomNavItem] so the width tween rebuilds
/// nothing but an `Expanded`.
class _BottomNavPill extends StatelessWidget {
  const _BottomNavPill({
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

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? kOnAccent : kCreamSecondary;

    return Semantics(
      // Named whether or not the label is drawn: four of the five tabs show
      // only a glyph, and a glyph is not a name.
      label: label,
      button: true,
      selected: isSelected,
      // Re-declared here because `excludeSemantics` drops the child
      // GestureDetector's own tap action along with its (unhelpful) labels.
      // Without this the node is a button a screen reader can read but cannot
      // activate.
      onTap: onTap,
      excludeSemantics: true,
      child: _PressScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: kMotionDuration,
          curve: kMotionEase,
          height: DashboardBottomNav._tabHeight,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isSelected ? kAccentEmber : Colors.transparent,
            borderRadius: BorderRadius.circular(kRadiusPill),
          ),
          // Clipped so the label is cut off by the pill's own edge while the
          // width animates, rather than spilling across the neighbouring tab.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kRadiusPill),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 22,
                  color: foreground,
                ),
                // The label exists only on the selected tab. `Flexible` with a
                // zero-width gap keeps the row centred at both extremes of the
                // animation instead of drifting left as the pill grows.
                if (isSelected)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style:
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: foreground,
                                  fontWeight: FontWeight.w600,
                                ),
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
        duration: kMotionDuration,
        curve: kMotionEase,
        scale: _pressed ? 0.92 : 1.0,
        child: widget.child,
      ),
    );
  }
}
