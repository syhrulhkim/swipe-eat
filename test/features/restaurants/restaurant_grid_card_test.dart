import 'dart:io';

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
const double _tileHeight = _tileWidth / 0.9;

/// How far a corner mark sits in from the tile's edges — the design's
/// `top: 8; right: 8`.
const double _markInset = 8;

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
              plannedLabel: plannedLabel,
            ),
          ),
        ),
      ),
    ),
  );
}

/// The saved check, found by the one icon only it draws.
Finder get _savedCheck => find.byIcon(Icons.check_rounded);

/// The photo half of the tile — the one Stack, holding the picture (or its
/// placeholder) and the corner marks.
Finder get _photo => find
    .descendant(
      of: find.byType(RestaurantGridCard),
      matching: find.byType(Stack),
    )
    .first;

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

  group('RestaurantGridCard layout', () {
    testWidgets('the caption sits below the photo, not over it',
        (tester) async {
      // The whole point of the split tile (D125): the text has its own dark
      // ground under the picture. If someone lays it back over the photo, the
      // name's top climbs above the photo's bottom edge and this fails.
      await _pumpTile(tester, isSaved: true);

      final photo = tester.getRect(_photo);
      final name = tester.getRect(find.text('Warung Kak Ros'));
      final tile = tester.getRect(find.byType(RestaurantGridCard));

      expect(name.top, greaterThanOrEqualTo(photo.bottom));
      expect(photo.top, closeTo(tile.top, 1.5), reason: 'photo starts at the top');
      // Near the reference's 60/40 split at the default text size.
      expect(photo.height / tile.height, inInclusiveRange(0.55, 0.75));
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
                  plannedLabel: 'Fri 4',
                ),
              ),
            ),
          ),
        ),
      );

      // The check and the pill are marks, not controls: a tap on either has to
      // reach the tile underneath.
      await tester.tap(find.text('Warung Kak Ros'));
      expect(taps, 1, reason: 'the name');

      await tester.tap(find.text('Fri 4'), warnIfMissed: false);
      expect(taps, 2, reason: 'the planned pill');

      await tester.tap(_savedCheck, warnIfMissed: false);
      expect(taps, 3, reason: 'the saved check');
    });
  });

  group('RestaurantGridCard saved check', () {
    testWidgets('appears on a saved tile only', (tester) async {
      await _pumpTile(tester);
      expect(_savedCheck, findsNothing);

      await _pumpTile(tester, isSaved: true);
      expect(_savedCheck, findsOneWidget);
    });

    testWidgets('sits in the top-right corner of the photo', (tester) async {
      await _pumpTile(tester, isSaved: true);

      final photo = tester.getRect(_photo);
      final check = tester.getRect(find.ancestor(
        of: _savedCheck,
        matching: find.byType(DecoratedBox),
      ).first);

      expect(check.right, closeTo(photo.right - _markInset, 0.01));
      expect(check.top, closeTo(photo.top + _markInset, 0.01));
      expect(check.width, kCheckCircleSize);
    });

    testWidgets('the bookmark is gone', (tester) async {
      // Removed, not hidden (D84, D125).
      await _pumpTile(tester, isSaved: true);

      expect(find.byIcon(Icons.bookmark_outline_rounded), findsNothing);
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
  });
}
