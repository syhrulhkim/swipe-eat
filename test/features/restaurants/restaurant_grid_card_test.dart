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

/// The badge row a bitten tile carries: the two row actions, each 30 pt with
/// 6 pt between them. The super-like star used to make it a third wider — it
/// went with the feature, which is what let the bite go to full size.
const double _badgeRowWidth = 30 * 2 + 6;
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

    test('the full-size bite clears the badge row on the narrowest tile', () {
      // The tile now carries the prototype's full 30 pt bite. That only fits
      // because the super-like star is gone; the assertion is what stops a
      // third badge from quietly reintroducing the collision.
      final biteEdge = _biteLeftEdge(_tileWidth, kBiteNotchRadius);

      expect(biteEdge, greaterThan(_badgeInset + _badgeRowWidth));
    });

    test('a third badge would collide with the bite', () {
      // The margin is real but not generous, and it is the reason the star
      // could not simply have been left in place next to a full-size notch.
      const withThirdBadge = _badgeInset + _badgeRowWidth + 6 + 30;

      expect(_biteLeftEdge(_tileWidth, kBiteNotchRadius),
          lessThan(withThirdBadge));
    });
  });
}
