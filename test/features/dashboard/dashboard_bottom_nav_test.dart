import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/plans/presentation/calendar_tab.dart';
import 'package:swipe_eat/features/nearby/presentation/nearby_tab.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/dashboard/presentation/dashboard_bottom_nav.dart';
import 'package:swipe_eat/features/dashboard/presentation/dashboard_page.dart';

import '../../support/widget_test_support.dart';
import '../auth/fake_auth_repository.dart';

/// Reference phone viewport used unless a case cares about the size.
const Size _phoneViewport = Size(390, 844);

/// The narrowest phone the design has to survive.
const Size _narrowViewport = Size(320, 568);

const Size _tabletViewport = Size(1024, 1366);

/// Accessibility scale the layout has to survive. Well past the 1.3x the bar
/// clamps at, so the clamp is what is under test and not the scaler.
const TextScaler _hugeTextScale = TextScaler.linear(3.0);

/// The bar's own height. Fixed, because the tabs sit above it — §8 of
/// NGAP-DESIGN-SYSTEM.md, and `.nav{height:64px}` in the prototype.
const double _barHeight = 64;

/// Height of one tab inside the bar: 64 less 5px of padding top and bottom.
const double _tabHeight = 52;

/// The tabs in bar order, as the design system lists them.
const List<String> _tabLabels = [
  'Swipe',
  'Nearby',
  'Bites',
  'Calendar',
  'You',
];

/// The outline glyph each tab rests at, and the solid one it switches to when
/// it becomes the current tab. Asserted as a pair because "filled means here"
/// is the marker that survives being read without colour.
const List<(IconData resting, IconData active)> _tabIcons = [
  (Icons.style_outlined, Icons.style_rounded),
  (Icons.place_outlined, Icons.place_rounded),
  (Icons.favorite_border_rounded, Icons.favorite_rounded),
  (Icons.calendar_today_outlined, Icons.calendar_month_rounded),
  (Icons.person_outline_rounded, Icons.person_rounded),
];

Future<void> _pumpNav(
  WidgetTester tester, {
  int selectedIndex = 0,
  ValueChanged<int>? onSelected,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      // The scaler has to be applied below MaterialApp: its own
      // MediaQuery.fromView would otherwise overwrite an ancestor's data.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        backgroundColor: kBackgroundDark,
        bottomNavigationBar: DashboardBottomNav(
          selectedIndex: selectedIndex,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A bar that actually moves when it is tapped, so the animation and the
/// "exactly one current tab" invariant can be observed across a selection
/// rather than only in two static frames.
Future<void> _pumpLiveNav(WidgetTester tester, {int selectedIndex = 0}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: _NavHost(initialIndex: selectedIndex),
    ),
  );
  await tester.pumpAndSettle();
}

class _NavHost extends StatefulWidget {
  const _NavHost({required this.initialIndex});

  final int initialIndex;

  @override
  State<_NavHost> createState() => _NavHostState();
}

class _NavHostState extends State<_NavHost> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      bottomNavigationBar: DashboardBottomNav(
        selectedIndex: _index,
        onSelected: (index) => setState(() => _index = index),
      ),
    );
  }
}

Finder _nav() => find.byType(DashboardBottomNav);

/// The five tab pills, left to right. `AnimatedContainer` appears exactly once
/// per tab; the press-scale wrapper is an `AnimatedScale`, so it does not
/// collide with this.
Finder _pills() =>
    find.descendant(of: _nav(), matching: find.byType(AnimatedContainer));

/// The nth pill's fill. Transparent for every tab but the current one.
Color _pillColor(WidgetTester tester, int index) {
  final container = tester.widget<AnimatedContainer>(_pills().at(index));
  return (container.decoration! as BoxDecoration).color!;
}

/// The glyph drawn in each tab, in bar order.
List<IconData> _icons(WidgetTester tester) {
  return tester
      .widgetList<Icon>(find.descendant(of: _nav(), matching: find.byType(Icon)))
      .map((icon) => icon.icon!)
      .toList();
}

/// The ink colour of each tab's glyph, in bar order.
List<Color> _iconColors(WidgetTester tester) {
  return tester
      .widgetList<Icon>(find.descendant(of: _nav(), matching: find.byType(Icon)))
      .map((icon) => icon.color!)
      .toList();
}

/// Every label the bar actually draws. The contract is that this is a
/// one-element list naming the current tab.
List<String> _drawnLabels(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.descendant(of: _nav(), matching: find.byType(Text)))
      .map((text) => text.data!)
      .toList();
}

/// The flex each tab currently occupies. 100 at rest, 230 when current, and
/// anything in between while the width tween runs.
List<int> _flexes(WidgetTester tester) {
  return tester
      .widgetList<Expanded>(
        find.descendant(of: _nav(), matching: find.byType(Expanded)),
      )
      .map((expanded) => expanded.flex)
      .toList();
}

/// The text scaler the drawn label ends up with, expressed as the size a 10pt
/// font would render at.
double _labelScale(WidgetTester tester, String label) {
  final richText = tester.widget<RichText>(
    find.descendant(of: find.text(label), matching: find.byType(RichText)),
  );
  return richText.textScaler.scale(10);
}

/// The bar's own box. First in tree order; the five behind it are the
/// `Container`s each `AnimatedContainer` builds for its pill.
Finder _bar() =>
    find.descendant(of: _nav(), matching: find.byType(Container)).first;

/// Which of the dashboard's five tabs the `IndexedStack` is showing.
int _visibleTabIndex(WidgetTester tester) {
  return tester.widget<IndexedStack>(find.byType(IndexedStack)).index!;
}

Future<void> _pumpDashboard(WidgetTester tester) async {
  // The tabs behind the bar all reach for Supabase, which is not initialised
  // under `flutter test`; each one catches its own failure and renders an
  // error state, which is enough of a screen for the bar to sit on.
  await tester.pumpWidget(
    MaterialApp(
      home: DashboardPage(
        authController: AuthController(FakeAuthRepository(sessionPresent: true)),
      ),
    ),
  );
  // Not pumpAndSettle: the tabs run their own idle animations, so the tree
  // never goes quiet.
  await tester.pump();
  await tester.pump(kMotionDuration);
}

void main() {
  setUpAll(() {
    HttpOverrides.global = ImageHttpOverrides();
  });

  group('DashboardBottomNav structure', () {
    testWidgets('carries the five tabs in design order', (tester) async {
      useViewport(tester, _phoneViewport);
      final handle = tester.ensureSemantics();
      await _pumpNav(tester);

      expect(_pills(), findsNWidgets(5));
      for (final label in _tabLabels) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }

      // Order, not just membership: the bar is muscle memory.
      final lefts = [
        for (final label in _tabLabels)
          tester.getTopLeft(find.bySemanticsLabel(label)).dx,
      ];
      expect(lefts, orderedEquals([...lefts]..sort()));

      handle.dispose();
    });

    testWidgets('is a fixed 64px bar of 52px tabs', (tester) async {
      useViewport(tester, _phoneViewport);
      await _pumpNav(tester);

      expect(tester.getSize(_bar()).height, _barHeight);
      for (var index = 0; index < 5; index++) {
        expect(tester.getSize(_pills().at(index)).height, _tabHeight);
      }
    });

    testWidgets('is a hairlined surface pill, not a Material bar',
        (tester) async {
      useViewport(tester, _phoneViewport);
      await _pumpNav(tester);

      final decoration =
          tester.widget<Container>(_bar()).decoration! as BoxDecoration;
      expect(decoration.color, kSurfaceDark);
      expect((decoration.border! as Border).top.color, kHairline);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(kRadiusPill),
      );
    });
  });

  group('DashboardBottomNav current tab', () {
    testWidgets('draws the label of the current tab and no other',
        (tester) async {
      for (var index = 0; index < _tabLabels.length; index++) {
        await _pumpNav(tester, selectedIndex: index);

        expect(_drawnLabels(tester), [_tabLabels[index]],
            reason: 'selectedIndex $index');
      }
    });

    testWidgets('fills exactly one pill with the accent', (tester) async {
      for (var index = 0; index < _tabLabels.length; index++) {
        await _pumpNav(tester, selectedIndex: index);

        final fills = [for (var i = 0; i < 5; i++) _pillColor(tester, i)];
        expect(
          fills,
          [
            for (var i = 0; i < 5; i++)
              i == index ? kAccentEmber : Colors.transparent,
          ],
          reason: 'selectedIndex $index',
        );
      }
    });

    testWidgets('inks the current tab for the accent and the rest in cream',
        (tester) async {
      await _pumpNav(tester, selectedIndex: 2);

      expect(_iconColors(tester), [
        kCreamSecondary,
        kCreamSecondary,
        kOnAccent,
        kCreamSecondary,
        kCreamSecondary,
      ]);

      final label = tester.widget<Text>(find.text('Bites'));
      expect(label.style!.color, kOnAccent);
    });

    testWidgets('solidifies the current glyph and leaves the rest outlined',
        (tester) async {
      for (var index = 0; index < _tabIcons.length; index++) {
        await _pumpNav(tester, selectedIndex: index);

        expect(
          _icons(tester),
          [
            for (var i = 0; i < _tabIcons.length; i++)
              i == index ? _tabIcons[i].$2 : _tabIcons[i].$1,
          ],
          reason: 'selectedIndex $index',
        );
      }
    });

    testWidgets('expands the current tab and rests the other four',
        (tester) async {
      await _pumpNav(tester, selectedIndex: 1);

      expect(_flexes(tester), [100, 230, 100, 100, 100]);
      // The share is not just declared, it is spent: the current pill is the
      // widest thing in the bar.
      final widths = [
        for (var i = 0; i < 5; i++) tester.getSize(_pills().at(i)).width,
      ];
      expect(widths[1], greaterThan(widths[0]));
      expect(widths[1], greaterThan(widths[4]));
    });
  });

  group('DashboardBottomNav selection', () {
    testWidgets('reports the index of the tapped tab', (tester) async {
      useViewport(tester, _phoneViewport);
      final handle = tester.ensureSemantics();
      final taps = <int>[];
      await _pumpNav(tester, onSelected: taps.add);

      for (final label in _tabLabels) {
        await tester.tap(find.bySemanticsLabel(label));
        await tester.pump();
      }

      expect(taps, [0, 1, 2, 3, 4]);
      handle.dispose();
    });

    testWidgets('moves the pill to the tapped tab', (tester) async {
      useViewport(tester, _phoneViewport);
      final handle = tester.ensureSemantics();
      await _pumpLiveNav(tester);

      expect(_drawnLabels(tester), ['Swipe']);

      await tester.tap(find.bySemanticsLabel('You'));
      await tester.pumpAndSettle();

      expect(_drawnLabels(tester), ['You']);
      expect(_pillColor(tester, 0), Colors.transparent);
      expect(_pillColor(tester, 4), kAccentEmber);
      expect(_flexes(tester), [100, 100, 100, 100, 230]);

      handle.dispose();
    });

    testWidgets('widens rather than snaps', (tester) async {
      useViewport(tester, _phoneViewport);
      final handle = tester.ensureSemantics();
      await _pumpLiveNav(tester);

      await tester.tap(find.bySemanticsLabel('Calendar'));
      // Half way through the shared motion duration the tween is still on its
      // way — the pill grows out of the icon that was tapped.
      await tester.pump();
      await tester.pump(kMotionDuration ~/ 2);

      final midFlexes = _flexes(tester);
      expect(midFlexes[3], greaterThan(100));
      expect(midFlexes[3], lessThan(230));
      expect(midFlexes[0], lessThan(230));

      await tester.pumpAndSettle();
      expect(_flexes(tester), [100, 100, 100, 230, 100]);

      handle.dispose();
    });
  });

  group('DashboardBottomNav semantics', () {
    testWidgets('names every tab, drawn label or not', (tester) async {
      useViewport(tester, _phoneViewport);
      final handle = tester.ensureSemantics();
      await _pumpNav(tester, selectedIndex: 0);

      // Only 'Swipe' is drawn, yet all five are readable.
      expect(_drawnLabels(tester), ['Swipe']);
      for (final label in _tabLabels) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          matchesSemantics(
            label: label,
            isButton: true,
            hasSelectedState: true,
            isSelected: label == 'Swipe',
            hasTapAction: true,
          ),
          reason: label,
        );
      }

      handle.dispose();
    });

    testWidgets('marks exactly one tab selected', (tester) async {
      useViewport(tester, _phoneViewport);
      final handle = tester.ensureSemantics();

      for (var index = 0; index < _tabLabels.length; index++) {
        await _pumpNav(tester, selectedIndex: index);

        for (var tab = 0; tab < _tabLabels.length; tab++) {
          expect(
            tester.getSemantics(find.bySemanticsLabel(_tabLabels[tab])),
            matchesSemantics(
              label: _tabLabels[tab],
              isButton: true,
              hasSelectedState: true,
              isSelected: tab == index,
              hasTapAction: true,
            ),
            reason: '${_tabLabels[tab]} with selectedIndex $index',
          );
        }
      }

      handle.dispose();
    });

    testWidgets('does not repeat the drawn label as a second node',
        (tester) async {
      useViewport(tester, _phoneViewport);
      final handle = tester.ensureSemantics();
      await _pumpNav(tester, selectedIndex: 1);

      // `excludeSemantics` is what keeps the pill's own Text out of the tree:
      // without it the current tab would be announced twice.
      expect(find.bySemanticsLabel('Nearby'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('a screen reader tap selects the tab', (tester) async {
      useViewport(tester, _phoneViewport);
      final handle = tester.ensureSemantics();
      final taps = <int>[];
      await _pumpNav(tester, onSelected: taps.add);

      // Not a gesture: the semantics action itself, which is all an assistive
      // technology has. `excludeSemantics` drops the child GestureDetector's
      // action, so the tab has to re-declare it — and `semantics.tap` throws
      // rather than passing when the node cannot be activated.
      for (final label in _tabLabels) {
        tester.semantics.tap(find.semantics.byLabel(label));
        await tester.pump();
      }

      expect(taps, [0, 1, 2, 3, 4]);
      handle.dispose();
    });
  });

  group('DashboardBottomNav text scaling', () {
    testWidgets('clamps the label at 1.3x', (tester) async {
      useViewport(tester, _phoneViewport);
      await _pumpNav(tester, textScaler: _hugeTextScale);

      expect(_labelScale(tester, 'Swipe'), 13.0);
    });

    testWidgets('scales up to the clamp', (tester) async {
      useViewport(tester, _phoneViewport);
      await _pumpNav(tester, textScaler: const TextScaler.linear(1.1));

      expect(_labelScale(tester, 'Swipe'), closeTo(11.0, 0.001));
    });

    testWidgets('keeps the bar 64px tall at any scale', (tester) async {
      useViewport(tester, _phoneViewport);
      await _pumpNav(tester, textScaler: _hugeTextScale);

      expect(tester.getSize(_bar()).height, _barHeight);
      expect(tester.getSize(_pills().at(0)).height, _tabHeight);
    });
  });

  group('DashboardBottomNav layout', () {
    // Every case selects Nearby, the second tab, so the pill is measured on a
    // label that is neither the shortest nor the longest.
    const nearby = 1;

    testWidgets('lays out without overflow on a phone', (tester) async {
      useViewport(tester, _phoneViewport);
      await _pumpNav(tester, selectedIndex: nearby);

      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out without overflow on a narrow phone', (tester) async {
      useViewport(tester, _narrowViewport);
      await _pumpNav(tester, selectedIndex: nearby);

      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out without overflow on a tablet', (tester) async {
      useViewport(tester, _tabletViewport, dpr: 2.0);
      await _pumpNav(tester, selectedIndex: nearby);

      expect(tester.takeException(), isNull);
    });

    testWidgets('survives the longest label at a huge text scale',
        (tester) async {
      useViewport(tester, _narrowViewport);
      await _pumpNav(
        tester,
        selectedIndex: nearby,
        textScaler: _hugeTextScale,
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(_bar()).height, _barHeight);
    });

    testWidgets('survives every tab being current at a huge text scale',
        (tester) async {
      useViewport(tester, _narrowViewport);

      for (var index = 0; index < _tabLabels.length; index++) {
        await _pumpNav(
          tester,
          selectedIndex: index,
          textScaler: _hugeTextScale,
        );

        expect(tester.takeException(), isNull, reason: _tabLabels[index]);
      }
    });

    testWidgets('does not overflow mid-animation', (tester) async {
      useViewport(tester, _narrowViewport);
      final handle = tester.ensureSemantics();
      await _pumpLiveNav(tester);

      await tester.tap(find.bySemanticsLabel('Nearby').last);
      // Walk the whole tween: the pill is narrower than its content for most
      // of it, which is what the clip is for.
      for (var step = 0; step < 8; step++) {
        await tester.pump(kMotionDuration ~/ 8);
        expect(tester.takeException(), isNull, reason: 'step $step');
      }

      handle.dispose();
    });

    testWidgets('every tab clears the 48px touch target on both axes',
        (tester) async {
      // Width is the axis that fails. The pill takes its width as a share of
      // the bar, so a fixed 2.3 ratio put the four inactive tabs at 43.8 px
      // here — under Material's 48 and under the iOS HIG's 44 — while the
      // height was never in doubt. Asserting only the height passed happily
      // through that.
      useViewport(tester, _narrowViewport);
      final handle = tester.ensureSemantics();
      await _pumpNav(tester);

      for (final label in _tabLabels) {
        final size = tester.getSize(find.bySemanticsLabel(label));
        expect(size.height, greaterThanOrEqualTo(48), reason: '$label height');
        expect(size.width, greaterThanOrEqualTo(48), reason: '$label width');
      }

      handle.dispose();
    });

    testWidgets('the pill still grows fully when the screen can afford it',
        (tester) async {
      // The width cap is a floor under the inactive tabs, not a haircut on
      // every screen: an ordinary phone keeps the prototype's 2.3 ratio.
      useViewport(tester, _phoneViewport);
      await _pumpNav(tester);
      await tester.pumpAndSettle();

      expect(_flexes(tester), [230, 100, 100, 100, 100]);
    });

    testWidgets('a narrow bar trades pill width for touch targets',
        (tester) async {
      useViewport(tester, _narrowViewport);
      await _pumpNav(tester);
      await tester.pumpAndSettle();

      final flexes = _flexes(tester);
      // Still the widest, still labelled — just not by the full ratio.
      expect(flexes.first, lessThan(230));
      expect(flexes.first, greaterThan(100));
      expect(flexes.skip(1), everyElement(100));
      expect(_drawnLabels(tester), ['Swipe']);
    });
  });

  group('DashboardPage bottom nav', () {
    testWidgets('starts on Swipe', (tester) async {
      useViewport(tester, _phoneViewport);
      await _pumpDashboard(tester);

      expect(_drawnLabels(tester), ['Swipe']);
      expect(_pillColor(tester, 0), kAccentEmber);
    });

    testWidgets('a tap switches the tab behind the bar', (tester) async {
      useViewport(tester, _phoneViewport);
      final handle = tester.ensureSemantics();
      await _pumpDashboard(tester);

      expect(_visibleTabIndex(tester), 0);

      await tester.tap(find.bySemanticsLabel('Calendar'));
      await tester.pump();
      await tester.pump(kMotionDuration);

      expect(_visibleTabIndex(tester), 3);
      expect(_drawnLabels(tester), ['Calendar']);
      expect(_pillColor(tester, 3), kAccentEmber);
      expect(tester.takeException(), isNull);

      handle.dispose();
    });

    testWidgets('a tab nobody has opened is not mounted, and stays after it is',
        (tester) async {
      useViewport(tester, _phoneViewport);
      final handle = tester.ensureSemantics();
      await _pumpDashboard(tester);

      // D140: five tabs mounted at launch meant five sets of `initState`
      // fetches, four of them for screens nobody had opened.
      expect(find.byType(NearbyTab, skipOffstage: false), findsNothing);
      expect(find.byType(CalendarTab, skipOffstage: false), findsNothing);

      await tester.tap(find.bySemanticsLabel('Calendar'));
      await tester.pump();
      await tester.pump(kMotionDuration);
      // One more frame: the reveal is deliberately deferred, so a tab's
      // `initState` does not fire inside the shell's own build.
      await tester.pump();

      expect(_visibleTabIndex(tester), 3);
      expect(find.byType(CalendarTab, skipOffstage: false), findsOneWidget);
      expect(find.byType(NearbyTab, skipOffstage: false), findsNothing);

      // Back to the deck: the calendar stays mounted, which is the whole
      // reason the stack is indexed rather than swapped.
      await tester.tap(find.bySemanticsLabel('Swipe'));
      await tester.pump();
      await tester.pump(kMotionDuration);

      expect(find.byType(CalendarTab, skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);

      handle.dispose();
    });

    testWidgets('re-tapping the current tab is a no-op', (tester) async {
      useViewport(tester, _phoneViewport);
      final handle = tester.ensureSemantics();
      await _pumpDashboard(tester);

      await tester.tap(find.bySemanticsLabel('Swipe'));
      await tester.pump();
      await tester.pump(kMotionDuration);

      expect(_visibleTabIndex(tester), 0);
      expect(_drawnLabels(tester), ['Swipe']);
      expect(tester.takeException(), isNull);

      handle.dispose();
    });
  });
}
