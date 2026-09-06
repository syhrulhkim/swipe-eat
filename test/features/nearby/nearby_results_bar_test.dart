import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/nearby/presentation/nearby_results_bar.dart';

import '../../support/widget_test_support.dart';

const Size _phone = Size(390, 844);

/// The smallest phone the design is asked to survive.
const Size _narrow = Size(320, 640);

/// The accessibility setting the layout has to survive intact (D73).
const TextScaler _hugeTextScale = TextScaler.linear(2);

/// Apple's floor for a touch target.
const double _minTapTarget = 44;

/// The bar on its own, so the counts can be set to values the map fixtures
/// cannot reach — nought results above all, which the tab never renders.
Future<void> _pumpBar(
  WidgetTester tester, {
  int resultCount = 3,
  int openNowCount = 2,
  int? minPriceFrom = 8,
  VoidCallback? onSwipeAll,
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
            body: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                NearbyResultsBar(
                  resultCount: resultCount,
                  openNowCount: openNowCount,
                  minPriceFrom: minPriceFrom,
                  onSwipeAll: onSwipeAll ?? () {},
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
  group('NearbyResultsBar figures', () {
    testWidgets('quotes the cheapest price, the open count and the total',
        (tester) async {
      await _pumpBar(tester, resultCount: 12, openNowCount: 5, minPriceFrom: 8);

      expect(find.text('From'), findsOneWidget);
      expect(find.text('RM 8'), findsOneWidget);
      expect(find.text('Open now'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Swipe all 12'), findsOneWidget);
    });

    testWidgets('hides the whole price block rather than saying "RM —"',
        (tester) async {
      await _pumpBar(tester, minPriceFrom: null);

      expect(find.text('From'), findsNothing);
      expect(find.textContaining('RM'), findsNothing);
      expect(find.text('Open now'), findsOneWidget);
    });

    testWidgets('says "Open now 0" rather than hiding the count',
        (tester) async {
      // Nothing open is an answer; an absent figure would read as unknown.
      await _pumpBar(tester, resultCount: 4, openNowCount: 0);

      expect(find.text('Open now'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('reads each figure as one label, not two', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpBar(tester, openNowCount: 5, minPriceFrom: 8);

      expect(find.bySemanticsLabel('From RM 8'), findsOneWidget);
      expect(find.bySemanticsLabel('Open now 5'), findsOneWidget);

      handle.dispose();
    });
  });

  group('NearbyResultsBar swipe-all', () {
    testWidgets('hands over on a tap', (tester) async {
      var taps = 0;
      await _pumpBar(tester, resultCount: 3, onSwipeAll: () => taps += 1);

      await tester.tap(find.text('Swipe all 3'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('an empty circle leaves the button dead', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await _pumpBar(tester, resultCount: 0, onSwipeAll: () => taps += 1);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Swipe all 0')),
        matchesSemantics(
          label: 'Swipe all 0',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );

      await tester.tap(find.text('Swipe all 0'), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);

      handle.dispose();
    });

    testWidgets('is a tap target at least 44 pt tall', (tester) async {
      await _pumpBar(tester);

      final size = tester.getSize(find.text('Swipe all 3').hitTestable());
      expect(size.height, lessThanOrEqualTo(kNearbyResultButtonHeight));
      expect(
        tester.getSize(find.byType(InkWell)).height,
        greaterThanOrEqualTo(_minTapTarget),
      );
    });
  });

  group('NearbyResultsBar layout', () {
    testWidgets('survives a three-digit count on a narrow phone',
        (tester) async {
      await _pumpBar(
        tester,
        viewport: _narrow,
        resultCount: 128,
        openNowCount: 64,
        minPriceFrom: 128,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Swipe all 128'), findsOneWidget);
    });

    testWidgets('survives a huge text scale on a narrow phone', (tester) async {
      await _pumpBar(
        tester,
        viewport: _narrow,
        resultCount: 128,
        openNowCount: 64,
        minPriceFrom: 128,
        textScaler: _hugeTextScale,
      );

      expect(tester.takeException(), isNull);
      // The action is the thing that must never be cut.
      expect(find.text('Swipe all 128'), findsOneWidget);
    });

    testWidgets('survives a huge text scale on a phone', (tester) async {
      await _pumpBar(tester, textScaler: _hugeTextScale);

      expect(tester.takeException(), isNull);
      expect(find.text('Swipe all 3'), findsOneWidget);
    });
  });
}
