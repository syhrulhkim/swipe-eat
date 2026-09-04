import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/restaurants/presentation/restaurant_grid_card.dart';

import '../../support/widget_test_support.dart';
import 'fake_restaurant_repositories.dart';

/// The narrowest phone the app supports, and the tile it produces in the Bites
/// grid: two columns inside 12 pt of screen padding with 10 pt between them.
const double _narrowScreen = 320;
const double _tileWidth = (_narrowScreen - 12 * 2 - 10) / 2;
const double _tileHeight = _tileWidth / 0.78;

/// The badge row a bitten tile carries today: the super-like star and the two
/// row actions, each 30 pt with 6 pt between them.
const double _badgeRowWidth = 30 * 3 + 6 * 2;
const double _badgeInset = 8;

/// Where the bite's left edge falls on a tile of [width].
///
/// The notch is a circle of [radius] centred [kBiteNotchInset] inside the
/// corner, so it first touches the top edge where the circle crosses it.
double _biteLeftEdge(double width, double radius) {
  final halfChord =
      math.sqrt(radius * radius - kBiteNotchInset * kBiteNotchInset);
  return width - kBiteNotchInset - halfChord;
}

Future<void> _pumpTile(
  WidgetTester tester, {
  required bool isSaved,
  Widget? badge,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: _tileWidth,
            height: _tileHeight,
            child: RestaurantGridCard(
              restaurant: testRestaurant(1, name: 'Warung Kak Ros'),
              distanceText: '1.2 km',
              onTap: () {},
              isSaved: isSaved,
              badge: badge,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() => HttpOverrides.global = ImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  group('RestaurantGridCard', () {
    testWidgets('an unsaved tile keeps its badge in the top right',
        (tester) async {
      await _pumpTile(
        tester,
        isSaved: false,
        badge: const SizedBox(width: _badgeRowWidth, height: 30),
      );

      final tile = tester.getRect(find.byType(RestaurantGridCard));
      final badge = tester.getRect(find.byType(SizedBox).last);

      expect(badge.right, closeTo(tile.right - _badgeInset, 0.01));
    });

    testWidgets('a bitten tile moves its badge clear of the notch',
        (tester) async {
      // The badge row holds real buttons — Mark visited, Remove from likes —
      // so the bite cannot be allowed to clip it. It moves to the left corner
      // rather than being cut in half.
      await _pumpTile(
        tester,
        isSaved: true,
        badge: const SizedBox(width: _badgeRowWidth, height: 30),
      );

      final tile = tester.getRect(find.byType(RestaurantGridCard));
      final badge = tester.getRect(find.byType(SizedBox).last);

      expect(badge.left, closeTo(tile.left + _badgeInset, 0.01));
    });

    test('the bite clears the badge row on the narrowest tile', () {
      // This is the invariant kBiteNotchTileScale exists to hold. It is thin —
      // about 8 pt — and it is the only thing standing between the notch and
      // the "Remove from likes" button, so it is asserted rather than left to
      // whoever next changes either number.
      final biteEdge = _biteLeftEdge(
        _tileWidth,
        kBiteNotchRadius * kBiteNotchTileScale,
      );

      expect(biteEdge, greaterThan(_badgeInset + _badgeRowWidth));
    });

    test('the prototype radius is what the badge row is costing us', () {
      // Not a wish: the full-size bite the design actually specifies for tiles
      // *would* clip the badge row. This documents the price of keeping the
      // badges the design deletes, and fails the day D82 makes it wrong.
      final fullBiteEdge = _biteLeftEdge(_tileWidth, kBiteNotchRadius);

      expect(fullBiteEdge, lessThan(_badgeInset + _badgeRowWidth));
    });
  });
}
