import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/restaurants/presentation/swipe_deck.dart';

import '../../support/widget_test_support.dart';

/// The smallest phone the design is asked to survive.
const Size _narrowViewport = Size(320, 640);

/// A location label longer than any real one, for the squeeze test.
const String _longLocation =
    'Bandar Baru Bangi Seksyen 9 Selangor Darul Ehsan, Malaysia';

/// Apple's floor for a touch target, which the deck's controls are the app's
/// most-used examples of.
const double _minTapTarget = 44;

Future<void> _pumpHeader(
  WidgetTester tester, {
  String locationLabel = 'Kampung Baru',
  int? radiusKm,
  String? mealLabel,
  String? stalenessLabel,
  String? handoffLabel,
  int activeFilterCount = 0,
  VoidCallback? onFilterTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: kBackgroundDark,
        body: DeckHeader(
          locationLabel: locationLabel,
          radiusKm: radiusKm,
          mealLabel: mealLabel,
          stalenessLabel: stalenessLabel,
          handoffLabel: handoffLabel,
          activeFilterCount: activeFilterCount,
          onFilterTap: onFilterTap,
        ),
      ),
    ),
  );
}

Future<void> _pumpActionBar(
  WidgetTester tester, {
  VoidCallback? onPass,
  VoidCallback? onLike,
  VoidCallback? onLater,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: kBackgroundDark,
        body: Center(
          child: DeckActionBar(
            onPass: onPass ?? () {},
            onLike: onLike ?? () {},
            onLater: onLater ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('DeckHeader', () {
    testWidgets('says where you are', (tester) async {
      await _pumpHeader(tester);

      expect(find.text('Kampung Baru'), findsOneWidget);
      expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    });

    testWidgets('the subline names the radius and the meal', (tester) async {
      await _pumpHeader(tester, radiusKm: 3, mealLabel: 'dinner');

      expect(find.text('within 3 km · dinner'), findsOneWidget);
    });

    testWidgets('no radius means no limit, not a missing line',
        (tester) async {
      await _pumpHeader(tester, mealLabel: 'lunch');

      expect(find.text('any distance · lunch'), findsOneWidget);
    });

    testWidgets('the meal is dropped when the caller has none', (tester) async {
      await _pumpHeader(tester, radiusKm: 5);

      expect(find.text('within 5 km'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('the Filters button reads as one and fires', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await _pumpHeader(tester, onFilterTap: () => taps++);

      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Filters'), findsOneWidget);

      await tester.tap(find.byType(AppIconButton));
      await tester.pump();
      expect(taps, 1);

      handle.dispose();
    });

    testWidgets('no filter handler, no filter button', (tester) async {
      await _pumpHeader(tester);

      expect(find.byType(AppIconButton), findsNothing);
      expect(find.byIcon(Icons.tune_rounded), findsNothing);
    });

    testWidgets('the badge counts the filters that are on', (tester) async {
      await _pumpHeader(tester, activeFilterCount: 2, onFilterTap: () {});

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('no filters on, no badge', (tester) async {
      await _pumpHeader(tester, onFilterTap: () {});

      // The badge is the only [Text] inside the button — an [Icon] paints
      // through a [RichText] — so no Text there means no badge.
      expect(
        find.descendant(
          of: find.byType(AppIconButton),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });

    testWidgets('the staleness chip shows only when there is one',
        (tester) async {
      await _pumpHeader(tester);
      expect(find.byType(AppChip), findsNothing);

      await _pumpHeader(tester, stalenessLabel: 'Saved 2 h ago');
      expect(find.byType(AppChip), findsOneWidget);
      expect(find.text('Saved 2 h ago'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('carries no Settings control — that lives in Profile',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpHeader(
        tester,
        stalenessLabel: 'Saved 2 h ago',
        activeFilterCount: 3,
        radiusKm: 3,
        mealLabel: 'dinner',
        onFilterTap: () {},
      );

      expect(find.text('Settings'), findsNothing);
      expect(find.bySemanticsLabel('Settings'), findsNothing);
      expect(find.byIcon(Icons.settings_rounded), findsNothing);
      expect(find.byIcon(Icons.settings_outlined), findsNothing);

      handle.dispose();
    });

    testWidgets('a long location does not overflow a 320 px phone',
        (tester) async {
      useViewport(tester, _narrowViewport);
      await _pumpHeader(
        tester,
        locationLabel: _longLocation,
        radiusKm: 3,
        mealLabel: 'dinner',
        stalenessLabel: 'Saved 2 h ago',
        activeFilterCount: 12,
        onFilterTap: () {},
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(DeckHeader)).width,
        lessThanOrEqualTo(_narrowViewport.width),
      );
      // The label is cut rather than pushing the filter button off screen.
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(
        tester.getTopRight(find.byType(AppIconButton)).dx,
        lessThanOrEqualTo(_narrowViewport.width),
      );
    });
  });

  group('DeckHeader handoff chip', () {
    testWidgets('names the handed-over list, without the offline cloud',
        (tester) async {
      await _pumpHeader(tester, handoffLabel: 'Nearby · 6 places');

      expect(find.text('Nearby · 6 places'), findsOneWidget);
      expect(find.byIcon(Icons.near_me_rounded), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
    });

    testWidgets('sits beside the offline chip when both apply', (tester) async {
      await _pumpHeader(
        tester,
        handoffLabel: 'Nearby · 6 places',
        stalenessLabel: 'Offline · saved deck',
      );

      expect(find.text('Nearby · 6 places'), findsOneWidget);
      expect(find.text('Offline · saved deck'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is absent when nothing was handed over', (tester) async {
      await _pumpHeader(tester);

      expect(find.byIcon(Icons.near_me_rounded), findsNothing);
    });
  });

  group('DeckActionBar', () {
    testWidgets('offers three moves, no more', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpActionBar(tester);

      expect(find.bySemanticsLabel('Skip'), findsOneWidget);
      expect(find.bySemanticsLabel('Ngap'), findsOneWidget);
      expect(find.bySemanticsLabel('Save for later'), findsOneWidget);
      expect(find.byType(AppIconButton), findsNWidgets(2));
      expect(find.byType(AppNgapButton), findsOneWidget);

      handle.dispose();
    });

    testWidgets('the ones that are gone stay gone', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpActionBar(tester);

      // Rewind and the super-like went with the features behind them.
      expect(find.bySemanticsLabel('Rewind'), findsNothing);
      expect(find.bySemanticsLabel('Super like'), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.replay_rounded), findsNothing);

      handle.dispose();
    });

    testWidgets('Skip fires only onPass', (tester) async {
      var pass = 0;
      var like = 0;
      var later = 0;
      await _pumpActionBar(
        tester,
        onPass: () => pass++,
        onLike: () => like++,
        onLater: () => later++,
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect([pass, like, later], [1, 0, 0]);
    });

    testWidgets('Ngap fires only onLike', (tester) async {
      var pass = 0;
      var like = 0;
      var later = 0;
      await _pumpActionBar(
        tester,
        onPass: () => pass++,
        onLike: () => like++,
        onLater: () => later++,
      );

      await tester.tap(find.byType(AppNgapButton));
      await tester.pump();

      expect([pass, like, later], [0, 1, 0]);
    });

    testWidgets('Save for later fires only onLater', (tester) async {
      var pass = 0;
      var like = 0;
      var later = 0;
      await _pumpActionBar(
        tester,
        onPass: () => pass++,
        onLike: () => like++,
        onLater: () => later++,
      );

      await tester.tap(find.byIcon(Icons.schedule_rounded));
      await tester.pump();

      expect([pass, like, later], [0, 0, 1]);
    });

    testWidgets('every button clears the 44 pt touch target', (tester) async {
      await _pumpActionBar(tester);

      final targets = <Finder>[
        find.byType(AppIconButton).at(0),
        find.byType(AppNgapButton),
        find.byType(AppIconButton).at(1),
      ];
      for (final target in targets) {
        final size = tester.getSize(target);
        expect(size.width, greaterThanOrEqualTo(_minTapTarget));
        expect(size.height, greaterThanOrEqualTo(_minTapTarget));
      }
    });

    testWidgets('Ngap is the biggest thing on the bar', (tester) async {
      await _pumpActionBar(tester);

      final ngap = tester.getSize(find.byType(AppNgapButton)).width;
      expect(ngap, greaterThan(tester.getSize(find.byType(AppIconButton).at(0)).width));
      expect(ngap, greaterThan(tester.getSize(find.byType(AppIconButton).at(1)).width));
    });

    testWidgets('sits in the middle, in reading order', (tester) async {
      await _pumpActionBar(tester);

      final skip = tester.getCenter(find.byIcon(Icons.close_rounded)).dx;
      final ngap = tester.getCenter(find.byType(AppNgapButton)).dx;
      final later = tester.getCenter(find.byIcon(Icons.schedule_rounded)).dx;

      expect(skip, lessThan(ngap));
      expect(ngap, lessThan(later));
    });
  });
}
