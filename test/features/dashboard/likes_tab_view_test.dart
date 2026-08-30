import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/core/ui/tiktok_thumbnail_placeholder.dart';
import 'package:swipe_eat/features/dashboard/presentation/likes_tab_view.dart';
import 'package:swipe_eat/features/restaurants/models/restaurant.dart';
import 'package:swipe_eat/features/restaurants/presentation/restaurant_grid_card.dart';
import 'package:swipe_eat/features/restaurants/state/restaurant_list_controller.dart';

import '../../support/widget_test_support.dart';

/// Reference phone viewport used unless a case cares about the size.
const Size _phoneViewport = Size(390, 844);

/// The narrowest phone the design has to survive.
const Size _narrowViewport = Size(320, 568);

const Size _tabletViewport = Size(1024, 1366);

/// Accessibility scale the layout has to survive.
const TextScaler _largeTextScale = TextScaler.linear(1.6);

/// The distance string the host normally computes; injected here so the tests
/// do not need the geolocator.
const String _distanceLabel = '1.2 km away';

/// A restaurant photo URL. Every image request is answered by the fake HTTP
/// client with a real (transparent) PNG, so these never hit the network.
String _photo(int id) => 'https://example.com/photo-$id.jpg';

Restaurant _restaurant({
  required int id,
  String? name,
  String tag = 'Grilled chicken',
  double rating = 4.5,
  List<String>? imageUrls,
  List<RestaurantReview> reviews = const [],
  String? videoUrl,
}) {
  return Restaurant(
    id: id,
    name: name ?? 'Restaurant $id',
    tag: tag,
    details: 'A tiny shophouse stall with a very big charcoal grill.',
    brandColor: kBrandColorFallback,
    rating: rating,
    latitude: 1.85,
    longitude: 102.933333,
    imageUrls: imageUrls ?? [_photo(id)],
    reviews: reviews,
    videoUrl: videoUrl,
  );
}

List<Restaurant> _restaurants(int count) {
  return List<Restaurant>.generate(
    count,
    (index) => _restaurant(id: index + 1),
  );
}

/// A controller whose fetch resolves immediately with [rows] (or throws).
RestaurantListController _listController({
  List<Restaurant> rows = const [],
  bool fail = false,
}) {
  return RestaurantListController(() async {
    if (fail) {
      throw Exception('list unavailable');
    }
    return rows;
  });
}

Future<void> _pumpLikesTab(
  WidgetTester tester, {
  required List<Restaurant> liked,
  RestaurantListController? visited,
  RestaurantListController? reviewed,
  Size viewport = _phoneViewport,
  double dpr = 1.0,
  TextScaler textScaler = TextScaler.noScaling,
  String Function(Restaurant restaurant)? distanceLabel,
  double Function(Restaurant restaurant)? distanceMeters,
  bool Function(int restaurantId)? isSuperLiked,
  void Function(Restaurant restaurant)? onOpenRestaurant,
  void Function(Restaurant restaurant)? onUnlike,
  void Function(Restaurant restaurant)? onMarkVisited,
}) async {
  useViewport(tester, viewport, dpr: dpr);
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
        body: LikesTabView(
          liked: liked,
          visitedController: visited ?? _listController(),
          reviewedController: reviewed ?? _listController(),
          distanceLabel: distanceLabel ?? (_) => _distanceLabel,
          distanceMeters: distanceMeters ?? (_) => double.infinity,
          isSuperLiked: isSuperLiked ?? (_) => false,
          onOpenRestaurant: onOpenRestaurant ?? (_) {},
          onUnlike: onUnlike ?? (_) {},
          onMarkVisited: onMarkVisited ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _card(String name) {
  return find.ancestor(
    of: find.text(name),
    matching: find.byType(RestaurantGridCard),
  );
}

/// The tappable control inside one card, found by its semantic label.
Finder _cardAction(String name, String label) {
  return find.descendant(
    of: _card(name),
    matching: find.bySemanticsLabel(label),
  );
}

void main() {
  setUpAll(() {
    HttpOverrides.global = ImageHttpOverrides();
  });

  group('LikesTabView empty state', () {
    testWidgets('shows the no-likes copy for an empty list', (tester) async {
      await _pumpLikesTab(tester, liked: const []);

      expect(find.text('No likes yet'), findsOneWidget);
      expect(
        find.text(
          'Swipe right on restaurants you love and they will show up here.',
        ),
        findsOneWidget,
      );
      expect(find.byType(RestaurantGridCard), findsNothing);
    });
  });

  group('LikesTabView liked grid', () {
    testWidgets('renders one card per liked restaurant', (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [
          _restaurant(id: 1, name: 'Newest Warung'),
          _restaurant(id: 2, name: 'Older Kopitiam'),
        ],
      );

      expect(find.byType(RestaurantGridCard), findsNWidgets(2));
      expect(find.text('Newest Warung'), findsOneWidget);
      expect(find.text('Older Kopitiam'), findsOneWidget);
    });

    testWidgets('shows distance and rating on the card', (tester) async {
      await _pumpLikesTab(tester, liked: [_restaurant(id: 1)]);

      expect(find.text('$_distanceLabel  ·  ★ 4.5'), findsOneWidget);
    });

    testWidgets('an unrated restaurant shows only the distance',
        (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [_restaurant(id: 1, name: 'Warung Baru', rating: 0)],
      );

      // ratingLabel(0) is '–'; it must not leak onto the card.
      expect(find.text(_distanceLabel), findsOneWidget);
      expect(find.textContaining('–'), findsNothing);
    });

    testWidgets('falls back to the TikTok placeholder without a photo',
        (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [
          _restaurant(
            id: 1,
            imageUrls: const [],
            videoUrl: 'https://www.tiktok.com/@johorfoodie/video/12345',
          ),
        ],
      );

      expect(find.byType(TikTokThumbnailPlaceholder), findsOneWidget);
      expect(find.text('@johorfoodie'), findsOneWidget);
    });

    testWidgets('stars only the super-liked cards', (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [
          _restaurant(id: 1, name: 'Starred Stall'),
          _restaurant(id: 2, name: 'Plain Stall'),
        ],
        isSuperLiked: (id) => id == 1,
      );

      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(
        find.descendant(
          of: _card('Starred Stall'),
          matching: find.byIcon(Icons.star_rounded),
        ),
        findsOneWidget,
      );
    });
  });

  group('LikesTabView callbacks', () {
    testWidgets('tapping the card opens the restaurant', (tester) async {
      final opened = <int>[];
      await _pumpLikesTab(
        tester,
        liked: [_restaurant(id: 4, name: 'Warung Empat')],
        onOpenRestaurant: (value) => opened.add(value.id),
      );

      await tester.tap(find.text('Warung Empat'));
      await tester.pump();

      expect(opened, [4]);
    });

    testWidgets('the heart unlikes and the check marks visited',
        (tester) async {
      final unliked = <int>[];
      final visited = <int>[];
      await _pumpLikesTab(
        tester,
        liked: [_restaurant(id: 4, name: 'Warung Empat')],
        onUnlike: (value) => unliked.add(value.id),
        onMarkVisited: (value) => visited.add(value.id),
      );

      await tester.tap(_cardAction('Warung Empat', 'Remove from likes'));
      await tester.tap(_cardAction('Warung Empat', 'Mark visited'));
      await tester.pump();

      expect(unliked, [4]);
      expect(visited, [4]);
    });

    testWidgets('the distance label is computed per restaurant',
        (tester) async {
      await _pumpLikesTab(
        tester,
        liked: _restaurants(2),
        distanceLabel: (restaurant) => '${restaurant.id} km away',
      );

      // The rating shares the line, so match on the substring.
      expect(find.textContaining('1 km away'), findsOneWidget);
      expect(find.textContaining('2 km away'), findsOneWidget);
    });
  });

  group('LikesTabView segments', () {
    testWidgets('Visited loads lazily and lists its own rows', (tester) async {
      final visited = _listController(
        rows: [_restaurant(id: 9, name: 'Eaten There')],
      );
      await _pumpLikesTab(
        tester,
        liked: [_restaurant(id: 1, name: 'Liked Only')],
        visited: visited,
      );

      // Nothing fetched while the segment is closed.
      expect(visited.isLoaded, isFalse);

      await tester.tap(find.text('Visited'));
      await tester.pumpAndSettle();

      expect(visited.isLoaded, isTrue);
      expect(find.text('Eaten There'), findsOneWidget);
      expect(find.text('Liked Only'), findsNothing);
      // Visited cards carry no unlike/mark-visited controls.
      expect(find.bySemanticsLabel('Remove from likes'), findsNothing);
      expect(find.bySemanticsLabel('Mark visited'), findsNothing);
    });

    testWidgets('an empty Visited segment explains itself', (tester) async {
      await _pumpLikesTab(tester, liked: [_restaurant(id: 1)]);

      await tester.tap(find.text('Visited'));
      await tester.pumpAndSettle();

      expect(find.text('No visits logged'), findsOneWidget);
    });

    testWidgets('a failed segment load offers a retry that recovers',
        (tester) async {
      var fail = true;
      final reviewed = RestaurantListController(() async {
        if (fail) {
          throw Exception('reviewed unavailable');
        }
        return [_restaurant(id: 7, name: 'Reviewed Spot')];
      });
      await _pumpLikesTab(
        tester,
        liked: [_restaurant(id: 1)],
        reviewed: reviewed,
      );

      await tester.tap(find.text('Reviewed'));
      await tester.pumpAndSettle();
      expect(find.text('Something went wrong'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Reviewed Spot'), findsOneWidget);
    });

    testWidgets('switching back to Liked keeps the liked rows',
        (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [_restaurant(id: 1, name: 'Liked Only')],
      );

      await tester.tap(find.text('Visited'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Liked'));
      await tester.pumpAndSettle();

      expect(find.text('Liked Only'), findsOneWidget);
    });
  });

  group('LikesTabView sort and filters', () {
    testWidgets('Nearest reorders the grid by metres', (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [
          _restaurant(id: 1, name: 'Far Stall'),
          _restaurant(id: 2, name: 'Near Stall'),
        ],
        distanceMeters: (restaurant) => restaurant.id == 2 ? 100 : 5000,
      );

      await tester.tap(find.text('Latest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nearest'));
      await tester.pumpAndSettle();

      final nearTop = tester.getTopLeft(find.text('Near Stall'));
      final farTop = tester.getTopLeft(find.text('Far Stall'));
      // Two columns: the first row is left-to-right, so nearest is leftmost.
      expect(nearTop.dx, lessThan(farTop.dx));
    });

    testWidgets('Top rated puts the highest rating first', (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [
          _restaurant(id: 1, name: 'Okay Stall', rating: 3.1),
          _restaurant(id: 2, name: 'Great Stall', rating: 4.9),
        ],
      );

      await tester.tap(find.text('Latest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Top rated'));
      await tester.pumpAndSettle();

      final greatTop = tester.getTopLeft(find.text('Great Stall'));
      final okayTop = tester.getTopLeft(find.text('Okay Stall'));
      expect(greatTop.dx, lessThan(okayTop.dx));
    });

    testWidgets('the must-try filter narrows the grid and clears again',
        (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [
          _restaurant(id: 1, name: 'Starred Stall'),
          _restaurant(id: 2, name: 'Plain Stall'),
        ],
        isSuperLiked: (id) => id == 1,
      );

      await tester.tap(find.bySemanticsLabel('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Must try only'));
      await tester.pumpAndSettle();
      // Close the sheet.
      await tester.tapAt(const Offset(195, 100));
      await tester.pumpAndSettle();

      expect(find.text('Starred Stall'), findsOneWidget);
      expect(find.text('Plain Stall'), findsNothing);
    });

    testWidgets('filters that hide everything offer a clear action',
        (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [_restaurant(id: 1, name: 'Plain Stall')],
      );

      await tester.tap(find.bySemanticsLabel('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Must try only'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(195, 100));
      await tester.pumpAndSettle();

      expect(find.text('Nothing matches your filters'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      expect(find.text('Plain Stall'), findsOneWidget);
    });
  });

  group('LikesTabView layout', () {
    /// A name long enough to need the card's ellipsis.
    const longName = 'Restoran Nasi Kandar Pelita Simpang Empat Batu Pahat';

    Future<void> pumpBusyGrid(
      WidgetTester tester, {
      required Size viewport,
      double dpr = 1.0,
      TextScaler textScaler = TextScaler.noScaling,
    }) {
      return _pumpLikesTab(
        tester,
        viewport: viewport,
        dpr: dpr,
        textScaler: textScaler,
        liked: [
          _restaurant(
            id: 1,
            name: longName,
            tag: 'Charcoal-grilled chicken and sambal',
            videoUrl: 'https://www.tiktok.com/@johorfoodie/video/12345',
          ),
          ..._restaurants(5).map(
            (restaurant) => _restaurant(id: restaurant.id + 1),
          ),
        ],
        isSuperLiked: (_) => true,
      );
    }

    testWidgets('does not overflow on a narrow phone', (tester) async {
      await pumpBusyGrid(tester, viewport: _narrowViewport);

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow on a tablet', (tester) async {
      await pumpBusyGrid(tester, viewport: _tabletViewport, dpr: 2.0);

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at a large text scale', (tester) async {
      await pumpBusyGrid(
        tester,
        viewport: _phoneViewport,
        textScaler: _largeTextScale,
      );

      expect(tester.takeException(), isNull);

      // Guard against a vacuous pass: the scaler really did grow the text.
      final scaledHeight = tester.getSize(find.text('Latest')).height;
      await pumpBusyGrid(tester, viewport: _phoneViewport);
      expect(
        tester.getSize(find.text('Latest')).height,
        lessThan(scaledHeight),
      );
    });

    testWidgets('keeps the segment control inside the viewport',
        (tester) async {
      await pumpBusyGrid(tester, viewport: _narrowViewport);

      final viewport = logicalViewport(tester);
      for (final label in const ['Liked', 'Visited', 'Reviewed']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0), reason: label);
        expect(rect.right, lessThanOrEqualTo(viewport.width), reason: label);
      }
    });
  });
}
