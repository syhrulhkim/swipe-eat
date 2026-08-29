import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';

import '../../support/widget_test_support.dart';

/// Viewport used for the plain (non-stack) widget cases.
const Size _phoneViewport = Size(390, 844);

/// Stack size used by the scrim cases: taller than either scrim below, so
/// "pinned to the top" and "pinned to the bottom" are distinguishable.
const Size _stackSize = Size(400, 900);

/// Explicit scrim heights, so the assertions do not depend on the defaults.
const double _topScrimHeight = 190;
const double _bottomScrimHeight = 620;

/// Width of the box the chip is squeezed into by the ellipsis case.
const double _chipHostWidth = 140;

/// A label long enough to overflow any chip on a phone-width screen.
const String _longLabel =
    'Nasi Kandar Pelita Simpang Empat Batu Pahat Johor Darul Takzim';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

/// Identifies the host [Stack]; the enclosing [Scaffold] contributes Stacks
/// of its own, so finding the host stack by type would be ambiguous.
const Key _hostStackKey = ValueKey('host-stack');

/// Pumps a [_stackSize]-sized [Stack] holding [children], for the scrims. The
/// viewport is widened to match so the stack is not squeezed by the default
/// 800x600 test surface.
Future<void> _pumpStack(WidgetTester tester, List<Widget> children) async {
  useViewport(tester, _stackSize);
  await tester.pumpWidget(
    _host(
      SizedBox(
        width: _stackSize.width,
        height: _stackSize.height,
        child: Stack(key: _hostStackKey, children: children),
      ),
    ),
  );
}

/// Matches the [Semantics] wrapper [AppCircleButton] adds for an
/// icon-only control. `button: true` is what tells a screen reader this is
/// tappable; [Material]/[InkWell] never set that flag themselves, so a hit
/// here can only come from the widget under test.
Finder _buttonSemantics({String? label}) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        widget.properties.button == true &&
        (label == null || widget.properties.label == label),
    description: 'Semantics(button: true, label: $label)',
  );
}

/// The fill the button paints, which is what [AppCircleButton.onPhoto]
/// chooses between.
Color? _circleButtonFill(WidgetTester tester) {
  return tester
      .widget<Material>(
        find
            .descendant(
              of: find.byType(AppCircleButton),
              matching: find.byType(Material),
            )
            .first,
      )
      .color;
}

/// The same, for a chip — which paints through a [BoxDecoration] instead.
Color? _chipFill(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(AppChip),
          matching: find.byType(Container),
        )
        .first,
  );
  return (container.decoration! as BoxDecoration).color;
}

void main() {
  group('AppCircleButton', () {
    testWidgets('renders the requested icon', (tester) async {
      await tester.pumpWidget(
        _host(
          AppCircleButton(
            icon: Icons.favorite_rounded,
            iconColor: kAccentEmber,
            onTap: () {},
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.favorite_rounded));
      expect(icon.color, kAccentEmber);
      // Default icon size is derived from the circle diameter.
      expect(icon.size, kActionButtonSize * 0.44);
    });

    testWidgets('tapping it fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          AppCircleButton(
            icon: Icons.route_rounded,
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.byType(AppCircleButton));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('sizes the tap target to the given diameter', (tester) async {
      await tester.pumpWidget(
        _host(
          AppCircleButton(
            icon: Icons.settings_rounded,
            size: kUtilityButtonSize,
            onTap: () {},
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(AppCircleButton)),
        const Size(kUtilityButtonSize, kUtilityButtonSize),
      );
    });

    testWidgets('onPhoto: true paints the translucent on-photo fill',
        (tester) async {
      await tester.pumpWidget(
        _host(
          AppCircleButton(
            icon: Icons.close_rounded,
            onTap: () {},
          ),
        ),
      );

      expect(_circleButtonFill(tester), kFillOnPhoto);
    });

    testWidgets('onPhoto: false paints the opaque panel surface',
        (tester) async {
      await tester.pumpWidget(
        _host(
          AppCircleButton(
            icon: Icons.close_rounded,
            onPhoto: false,
            onTap: () {},
          ),
        ),
      );

      expect(_circleButtonFill(tester), kSurfacePanel);
      // ...and the button still works.
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('an explicit background wins over both', (tester) async {
      await tester.pumpWidget(
        _host(
          AppCircleButton(
            icon: Icons.close_rounded,
            background: kAccentCream,
            onTap: () {},
          ),
        ),
      );

      expect(_circleButtonFill(tester), kAccentCream);
    });

    testWidgets('renders the badge count when it is above 0', (tester) async {
      await tester.pumpWidget(
        _host(
          AppCircleButton(
            icon: Icons.chat_bubble_rounded,
            badgeCount: 3,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('omits the badge for a zero, negative or null count',
        (tester) async {
      for (final count in <int?>[null, 0, -1]) {
        await tester.pumpWidget(
          _host(
            AppCircleButton(
              icon: Icons.chat_bubble_rounded,
              badgeCount: count,
              onTap: () {},
            ),
          ),
        );

        // The badge is the only [Text] in the subtree — [Icon] paints through
        // a [RichText] — so no Text at all means no badge.
        expect(
          find.descendant(
            of: find.byType(AppCircleButton),
            matching: find.byType(Text),
          ),
          findsNothing,
          reason: 'badgeCount: $count',
        );
      }
    });

    testWidgets('the badge ignores pointers and leaves the button tappable',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          AppCircleButton(
            icon: Icons.chat_bubble_rounded,
            badgeCount: 12,
            onTap: () => taps++,
          ),
        ),
      );

      expect(
        find.ancestor(
          of: find.text('12'),
          matching: find.byWidgetPredicate(
            (widget) => widget is IgnorePointer && widget.ignoring,
            description: 'IgnorePointer(ignoring: true)',
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.chat_bubble_rounded));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('semanticLabel wraps the control in a button Semantics node',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          AppCircleButton(
            icon: Icons.favorite_rounded,
            semanticLabel: 'Like',
            onTap: () {},
          ),
        ),
      );

      expect(_buttonSemantics(label: 'Like'), findsOneWidget);
      expect(find.bySemanticsLabel('Like'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('omitting semanticLabel adds no button Semantics wrapper',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          AppCircleButton(
            icon: Icons.favorite_rounded,
            onTap: () {},
          ),
        ),
      );

      expect(_buttonSemantics(), findsNothing);

      handle.dispose();
    });
  });

  group('AppChip', () {
    testWidgets('renders the label on its own', (tester) async {
      await tester.pumpWidget(_host(const AppChip(label: 'TikTok Review')));

      expect(find.text('TikTok Review'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('renders a leading icon when one is given', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppChip(icon: Icons.star_rounded, label: '4.5'),
        ),
      );

      expect(find.text('4.5'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('sits on a photo by default', (tester) async {
      await tester.pumpWidget(_host(const AppChip(label: 'Grilled')));

      expect(_chipFill(tester), kFillOnPhoto);
    });

    testWidgets('onPhoto: false paints the opaque panel surface',
        (tester) async {
      await tester.pumpWidget(
        _host(const AppChip(label: 'Grilled', onPhoto: false)),
      );

      expect(_chipFill(tester), kSurfacePanel);
    });

    testWidgets('a tint colours the icon and the label', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppChip(
            icon: Icons.cloud_off_rounded,
            label: 'Offline',
            tint: kAccentEmber,
          ),
        ),
      );

      expect(
        tester.widget<Icon>(find.byIcon(Icons.cloud_off_rounded)).color,
        kAccentEmber,
      );
      expect(
        tester.widget<Text>(find.text('Offline')).style?.color,
        kAccentEmber,
      );
    });

    testWidgets('ellipsises a label wider than the available space',
        (tester) async {
      useViewport(tester, _phoneViewport);
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: _chipHostWidth,
            child: AppChip(
              icon: Icons.local_dining_rounded,
              label: _longLabel,
            ),
          ),
        ),
      );

      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(_longLabel),
      );
      expect(paragraph.didExceedMaxLines, isTrue);
      expect(tester.takeException(), isNull);
      // The chip stays inside the box it was given instead of overflowing.
      expect(
        tester.getSize(find.byType(AppChip)).width,
        lessThanOrEqualTo(_chipHostWidth),
      );
    });
  });

  group('photo scrims', () {
    testWidgets('PhotoWash covers the whole stack', (tester) async {
      await _pumpStack(tester, const [PhotoWash()]);

      expect(
        find.descendant(
          of: find.byType(PhotoWash),
          matching: find.byType(Positioned),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byType(PhotoWash)),
        _stackSize,
      );
    });

    testWidgets('PhotoTopScrim is pinned to the top at its given height',
        (tester) async {
      await _pumpStack(tester, const [PhotoTopScrim(height: _topScrimHeight)]);

      expect(
        find.descendant(
          of: find.byType(PhotoTopScrim),
          matching: find.byType(Positioned),
        ),
        findsOneWidget,
      );

      final stackRect = tester.getRect(find.byKey(_hostStackKey));
      final scrimRect = tester.getRect(find.byType(PhotoTopScrim));
      expect(scrimRect.top, stackRect.top);
      expect(scrimRect.width, _stackSize.width);
      expect(scrimRect.height, _topScrimHeight);
    });

    testWidgets('PhotoBottomScrim is pinned to the bottom at its given height',
        (tester) async {
      await _pumpStack(
        tester,
        const [PhotoBottomScrim(height: _bottomScrimHeight)],
      );

      expect(
        find.descendant(
          of: find.byType(PhotoBottomScrim),
          matching: find.byType(Positioned),
        ),
        findsOneWidget,
      );

      final stackRect = tester.getRect(find.byKey(_hostStackKey));
      final scrimRect = tester.getRect(find.byType(PhotoBottomScrim));
      expect(scrimRect.bottom, stackRect.bottom);
      expect(scrimRect.width, _stackSize.width);
      expect(scrimRect.height, _bottomScrimHeight);
    });

    testWidgets('every scrim lets taps through to the content beneath it',
        (tester) async {
      for (final scrim in const <Widget>[
        PhotoWash(),
        PhotoTopScrim(),
        PhotoBottomScrim(),
      ]) {
        var taps = 0;
        await _pumpStack(tester, [
          Positioned.fill(
            child: Center(
              child: AppCircleButton(
                icon: Icons.favorite_rounded,
                onTap: () => taps++,
              ),
            ),
          ),
          scrim,
        ]);

        // Structural guarantee: the scrim opts out of hit testing entirely,
        // rather than relying on its painter happening not to absorb taps.
        expect(
          find.descendant(
            of: find.byWidget(scrim),
            matching: find.byType(IgnorePointer),
          ),
          findsOneWidget,
          reason: '${scrim.runtimeType}',
        );

        await tester.tap(find.byIcon(Icons.favorite_rounded));
        await tester.pump();

        expect(taps, 1, reason: '${scrim.runtimeType}');
      }
    });
  });
}
