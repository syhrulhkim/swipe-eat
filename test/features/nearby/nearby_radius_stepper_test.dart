import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/nearby/presentation/nearby_radius_stepper.dart';

import '../../support/widget_test_support.dart';

const Size _phone = Size(390, 844);

/// The smallest phone the design is asked to survive.
const Size _narrow = Size(320, 640);

/// The accessibility setting the layout has to survive intact (D73).
const TextScaler _hugeTextScale = TextScaler.linear(2);

/// Apple's floor for a touch target.
const double _minTapTarget = 44;

/// The stepper on its own, laid out where the tab puts it: bottom right, with
/// the map's 20 px inset either side.
Future<void> _pumpStepper(
  WidgetTester tester, {
  double radiusKm = 3,
  bool canNarrow = true,
  bool canWiden = true,
  VoidCallback? onNarrow,
  VoidCallback? onWiden,
  Size viewport = _phone,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  useViewport(tester, viewport);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: Scaffold(
            backgroundColor: kBackgroundDark,
            body: Stack(
              children: [
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: NearbyRadiusStepper(
                    radiusKm: radiusKm,
                    canNarrow: canNarrow,
                    canWiden: canWiden,
                    onNarrow: onNarrow ?? () {},
                    onWiden: onWiden ?? () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('NearbyRadiusStepper value', () {
    testWidgets('names the radius as a number over its caption',
        (tester) async {
      await _pumpStepper(tester);

      expect(find.text('Away from you'), findsOneWidget);
      expect(find.textContaining('3.0'), findsOneWidget);
    });

    testWidgets('reads metres below a kilometre', (tester) async {
      await _pumpStepper(tester, radiusKm: 0.5);

      expect(find.textContaining('500'), findsOneWidget);
    });

    testWidgets('reads the whole block as one sentence', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpStepper(tester, radiusKm: 12);

      expect(
        find.bySemanticsLabel('Radius 12.0 km away from you'),
        findsOneWidget,
      );

      handle.dispose();
    });
  });

  group('NearbyRadiusStepper buttons', () {
    testWidgets('both steps are labelled buttons that can be activated',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpStepper(tester);

      for (final label in ['Smaller radius', 'Larger radius']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          matchesSemantics(
            label: label,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
          reason: label,
        );
      }

      handle.dispose();
    });

    testWidgets('each step calls its own way', (tester) async {
      var narrowed = 0;
      var widened = 0;
      await _pumpStepper(
        tester,
        onNarrow: () => narrowed += 1,
        onWiden: () => widened += 1,
      );

      await tester.tap(find.bySemanticsLabel('Smaller radius'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Larger radius'));
      await tester.pump();

      expect(narrowed, 1);
      expect(widened, 1);
    });

    testWidgets('the smallest step refuses to narrow further', (tester) async {
      final handle = tester.ensureSemantics();
      var narrowed = 0;
      await _pumpStepper(
        tester,
        radiusKm: 0.5,
        canNarrow: false,
        onNarrow: () => narrowed += 1,
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Smaller radius')),
        matchesSemantics(
          label: 'Smaller radius',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );

      await tester.tap(
        find.bySemanticsLabel('Smaller radius'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(narrowed, 0);

      handle.dispose();
    });

    testWidgets('the largest step refuses to widen further', (tester) async {
      var widened = 0;
      await _pumpStepper(
        tester,
        radiusKm: 20,
        canWiden: false,
        onWiden: () => widened += 1,
      );

      await tester.tap(
        find.bySemanticsLabel('Larger radius'),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(widened, 0);
    });

    testWidgets('both steps are 44 pt tap targets', (tester) async {
      await _pumpStepper(tester);

      for (final label in ['Smaller radius', 'Larger radius']) {
        final size = tester.getSize(find.bySemanticsLabel(label));
        expect(size.width, greaterThanOrEqualTo(_minTapTarget), reason: label);
        expect(size.height, greaterThanOrEqualTo(_minTapTarget), reason: label);
      }
    });
  });

  group('NearbyRadiusStepper layout', () {
    testWidgets('fits a narrow phone', (tester) async {
      await _pumpStepper(tester, viewport: _narrow, radiusKm: 20);

      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a narrow phone at a huge text scale', (tester) async {
      await _pumpStepper(
        tester,
        viewport: _narrow,
        radiusKm: 20,
        textScaler: _hugeTextScale,
      );

      expect(tester.takeException(), isNull);
      // The steps are still the size a thumb needs.
      expect(
        tester.getSize(find.bySemanticsLabel('Larger radius')).width,
        greaterThanOrEqualTo(_minTapTarget),
      );
    });
  });
}
