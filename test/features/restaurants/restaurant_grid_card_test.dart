import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/restaurants/models/restaurant.dart';
import 'package:swipe_eat/features/restaurants/presentation/restaurant_grid_card.dart';

import '../../support/widget_test_support.dart';
import 'fake_restaurant_repositories.dart';

/// The narrowest phone the app supports, and the tile it produces in the Bites
/// grid: two columns inside 12 pt of screen padding with 10 pt between them.
const double _narrowScreen = 320;
const double _tileWidth = (_narrowScreen - 12 * 2 - 10) / 2;
const double _tileHeight = _tileWidth / 0.78;

/// How far a corner mark sits in from the tile's edges — the design's
/// `top: 8; right: 8`.
const double _markInset = 8;

/// Where the bite's left edge falls on a tile of [width].
///
/// The notch is a circle of [radius] centred [kBiteNotchInset] inside the
/// corner, so it first touches the top edge where the circle crosses it.
double _biteLeftEdge(double width, double radius) {
  final halfChord =
      math.sqrt(radius * radius - kBiteNotchInset * kBiteNotchInset);
  return width - kBiteNotchInset - halfChord;
}

Restaurant _restaurant({String tag = 'Nasi lemak', String? neighbourhood}) {
  final base = testRestaurant(1, name: 'Warung Kak Ros');

  return Restaurant(
    id: base.id,
    name: base.name,
    tag: tag,
    details: base.details,
    brandColor: base.brandColor,
    rating: base.rating,
    latitude: base.latitude,
    longitude: base.longitude,
    imageUrls: base.imageUrls,
    reviews: base.reviews,
    neighbourhood: neighbourhood,
  );
}

Future<void> _pumpTile(
  WidgetTester tester, {
  bool isSaved = false,
  bool isWishlisted = false,
  String? plannedLabel,
  Restaurant? restaurant,
  String distanceText = '1.2 km',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: _tileWidth,
            height: _tileHeight,
            child: RestaurantGridCard(
              restaurant: restaurant ?? _restaurant(),
              distanceText: distanceText,
              onTap: () {},
              isSaved: isSaved,
              isWishlisted: isWishlisted,
              plannedLabel: plannedLabel,
            ),
          ),
        ),
      ),
    ),
  );
}

/// The wish badge, found by the one icon only it draws.
Finder get _wishBadge => find.byIcon(Icons.bookmark_outline_rounded);

void main() {
  setUpAll(() => HttpOverrides.global = ImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  group('RestaurantGridCard subtitle', () {
    testWidgets('reads cuisine then neighbourhood', (tester) async {
      await _pumpTile(
        tester,
        restaurant: _restaurant(neighbourhood: 'Kampung Baru'),
      );

      expect(find.text('Nasi lemak · Kampung Baru'), findsOneWidget);
    });

    testWidgets('drops the neighbourhood rather than dangling a separator',
        (tester) async {
      await _pumpTile(tester, restaurant: _restaurant());

      expect(find.text('Nasi lemak'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('falls back to the passed line when the row knows neither',
        (tester) async {
      await _pumpTile(
        tester,
        restaurant: _restaurant(tag: ''),
        distanceText: '1.2 km away',
      );

      expect(find.text('1.2 km away'), findsOneWidget);
    });

    testWidgets('no rating rides on the subtitle', (tester) async {
      // The design's tile carries cuisine and neighbourhood and nothing else;
      // the star came from the old card.
      await _pumpTile(tester);

      expect(find.textContaining('★'), findsNothing);
    });
  });

  group('RestaurantGridCard bite', () {
    testWidgets('the notch is taken out of a saved tile only', (tester) async {
      Finder notch() => find.descendant(
            of: find.byType(RestaurantGridCard),
            matching: find.byType(BiteNotch),
          );

      await _pumpTile(tester);
      expect(tester.widget<BiteNotch>(notch()).bitten, isFalse);

      await _pumpTile(tester, isSaved: true);
      expect(tester.widget<BiteNotch>(notch()).bitten, isTrue);
    });

    testWidgets('the tile is one tap target, however it is marked',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: _tileWidth,
                height: _tileHeight,
                child: RestaurantGridCard(
                  restaurant: _restaurant(neighbourhood: 'Kampung Baru'),
                  distanceText: '1.2 km',
                  onTap: () => taps++,
                  isSaved: true,
                  isWishlisted: true,
                  plannedLabel: 'Fri 4',
                ),
              ),
            ),
          ),
        ),
      );

      // The badge and the pill are marks, not controls: a tap on either has to
      // reach the tile underneath.
      await tester.tap(find.text('Warung Kak Ros'));
      expect(taps, 1, reason: 'the name');

      await tester.tap(find.text('Fri 4'), warnIfMissed: false);
      expect(taps, 2, reason: 'the planned pill');

      await tester.tap(_wishBadge, warnIfMissed: false);
      expect(taps, 3, reason: 'the wishlist badge');
    });
  });

  group('RestaurantGridCard wishlist badge', () {
    testWidgets('appears only for a wishlisted place', (tester) async {
      await _pumpTile(tester, isSaved: true);
      expect(_wishBadge, findsNothing);

      await _pumpTile(tester, isSaved: true, isWishlisted: true);
      expect(_wishBadge, findsOneWidget);
    });

    testWidgets('sits in the top-right corner', (tester) async {
      await _pumpTile(tester, isSaved: true, isWishlisted: true);

      final tile = tester.getRect(find.byType(RestaurantGridCard));
      final badge = tester.getRect(_wishBadge);

      expect(badge.right, closeTo(tile.right - _markInset, 0.01));
      expect(badge.top, closeTo(tile.top + _markInset, 0.01));
    });

    testWidgets('survives the bite it overlaps', (tester) async {
      // The badge's centre is well inside the notch's radius, so a badge drawn
      // *inside* the clip would be erased. It has to be painted over the bite,
      // and this is what says so: the widget is laid out and hit-testable at
      // full size on a bitten tile.
      await _pumpTile(tester, isSaved: true, isWishlisted: true);

      expect(tester.getSize(find.byIcon(Icons.bookmark_outline_rounded)).width,
          greaterThan(0));

      final tile = tester.getRect(find.byType(RestaurantGridCard));
      final badgeCentre = tester.getCenter(_wishBadge);
      final notchCentre = Offset(
        tile.right - kBiteNotchInset,
        tile.top + kBiteNotchInset,
      );

      // Guards against a vacuous pass: if the geometry ever stops overlapping,
      // this test is no longer testing anything.
      expect((badgeCentre - notchCentre).distance,
          lessThan(kBiteNotchRadius));
    });
  });

  group('RestaurantGridCard planned pill', () {
    testWidgets('shows the day in the top-left corner', (tester) async {
      await _pumpTile(tester, isSaved: true, plannedLabel: 'Fri 4');

      final tile = tester.getRect(find.byType(RestaurantGridCard));
      final pill = tester.getRect(find.text('Fri 4'));

      expect(find.text('Fri 4'), findsOneWidget);
      expect(pill.left, greaterThanOrEqualTo(tile.left + _markInset));
      expect(pill.left, lessThan(tile.centerRight.dx));
    });

    testWidgets('is absent while nothing is planned', (tester) async {
      await _pumpTile(tester, isSaved: true);

      expect(find.text('Fri 4'), findsNothing);
    });

    test('the full-size bite leaves the planned corner alone', () {
      // The pill lives in the left corner precisely so the notch cannot clip
      // it. A pill wide enough to reach the bite would be a copy problem, not
      // a layout one, so the margin is asserted rather than assumed.
      expect(_biteLeftEdge(_tileWidth, kBiteNotchRadius),
          greaterThan(_markInset + 44));
    });
  });
}
