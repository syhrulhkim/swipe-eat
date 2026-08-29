import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/core/ui/tiktok_thumbnail_placeholder.dart';
import 'package:swipe_eat/features/dashboard/presentation/likes_tab_view.dart';
import 'package:swipe_eat/features/restaurants/models/restaurant.dart';

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
    brandColor: const Color(0xFF141922),
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

Future<void> _pumpLikesTab(
  WidgetTester tester, {
  required List<Restaurant> liked,
  Size viewport = _phoneViewport,
  double dpr = 1.0,
  TextScaler textScaler = TextScaler.noScaling,
  String Function(Restaurant restaurant)? distanceLabel,
  void Function(Restaurant restaurant)? onOpenRestaurant,
  void Function(Restaurant restaurant)? onUnlike,
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
          distanceLabel: distanceLabel ?? (_) => _distanceLabel,
          onOpenRestaurant: onOpenRestaurant ?? (_) {},
          onUnlike: onUnlike ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The circular thumbnails of the switcher strip. Only the strip clips photos
/// into a circle — the hero is full-bleed and the action circles hold icons —
/// so this isolates the strip without reaching into private widgets.
Finder _stripThumbnails() {
  return find.descendant(
    of: find.byType(ClipOval),
    matching: find.byType(Image),
  );
}

/// The key the hero puts on its [AnimatedSwitcher] child.
Finder _hero(Restaurant restaurant) {
  return find.byKey(
    ValueKey('${restaurant.id}-${restaurant.imageUrls.first}'),
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
      expect(find.byType(AppCircleButton), findsNothing);
    });
  });

  group('LikesTabView hero card', () {
    testWidgets('shows the newest liked restaurant', (tester) async {
      final liked = [
        _restaurant(id: 1, name: 'Newest Warung'),
        _restaurant(id: 2, name: 'Older Kopitiam'),
      ];
      await _pumpLikesTab(tester, liked: liked);

      // The whole heading is one Text.rich: name plus the muted rating.
      expect(find.text('Newest Warung  4.5'), findsOneWidget);
      expect(find.textContaining('Older Kopitiam'), findsNothing);
      expect(_hero(liked.first), findsOneWidget);
    });

    testWidgets('shows the distance label, the chips and four actions',
        (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [
          _restaurant(
            id: 1,
            name: 'Warung Ayam Bakar',
            videoUrl: 'https://www.tiktok.com/@johorfoodie/video/12345',
          ),
        ],
      );

      expect(find.text(_distanceLabel), findsOneWidget);
      expect(find.byIcon(Icons.place_rounded), findsOneWidget);

      expect(find.byType(AppChip), findsNWidgets(3));
      expect(find.text('Grilled chicken'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('TikTok Review'), findsOneWidget);

      expect(find.byType(AppCircleButton), findsNWidgets(4));
      for (final icon in const [
        Icons.favorite_rounded,
        Icons.chat_bubble_rounded,
        Icons.route_rounded,
        Icons.close_rounded,
      ]) {
        expect(find.byIcon(icon), findsOneWidget, reason: '$icon');
      }
    });

    testWidgets('omits the tag chip when the restaurant has no tag',
        (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [_restaurant(id: 1, tag: '')],
      );

      expect(find.byIcon(Icons.local_dining_rounded), findsNothing);
      expect(find.byType(AppChip), findsOneWidget);
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

    testWidgets('badges the reviews button with the review count',
        (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [
          _restaurant(
            id: 1,
            reviews: const [
              RestaurantReview(author: 'Aisyah', text: 'Great sambal.'),
              RestaurantReview(author: 'Ben', text: 'Strong kopi o.'),
            ],
          ),
        ],
      );

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('leaves the reviews button unbadged with no reviews',
        (tester) async {
      await _pumpLikesTab(tester, liked: [_restaurant(id: 1)]);

      expect(find.text('0'), findsNothing);
    });
  });

  group('LikesTabView unrated restaurant', () {
    testWidgets('renders neither a trailing dash nor a star chip',
        (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [_restaurant(id: 1, name: 'Warung Baru', rating: 0)],
      );

      // ratingLabel(0) is '–'; it must not leak into the heading or the chips.
      expect(find.text('Warung Baru'), findsOneWidget);
      expect(find.textContaining('–'), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      // Only the tag chip is left.
      expect(find.byType(AppChip), findsOneWidget);
    });
  });

  group('LikesTabView thumbnail strip', () {
    testWidgets('is hidden for a single liked restaurant', (tester) async {
      await _pumpLikesTab(tester, liked: [_restaurant(id: 1)]);

      expect(_stripThumbnails(), findsNothing);
    });

    testWidgets('shows one thumbnail per liked restaurant', (tester) async {
      await _pumpLikesTab(tester, liked: _restaurants(3));

      expect(_stripThumbnails(), findsNWidgets(3));
    });

    testWidgets('caps the strip at five thumbnails', (tester) async {
      await _pumpLikesTab(tester, liked: _restaurants(9));

      expect(_stripThumbnails(), findsNWidgets(5));
    });

    testWidgets('tapping a thumbnail switches the hero', (tester) async {
      final liked = [
        _restaurant(id: 1, name: 'Newest Warung'),
        _restaurant(id: 2, name: 'Older Kopitiam'),
        _restaurant(id: 3, name: 'Oldest Mamak'),
      ];
      await _pumpLikesTab(tester, liked: liked);

      await tester.tap(_stripThumbnails().at(2));
      await tester.pumpAndSettle();

      expect(find.textContaining('Oldest Mamak'), findsOneWidget);
      expect(find.textContaining('Newest Warung'), findsNothing);
      expect(_hero(liked[2]), findsOneWidget);
      expect(_hero(liked.first), findsNothing);
    });

    testWidgets('rings only the active thumbnail with the lime accent',
        (tester) async {
      await _pumpLikesTab(tester, liked: _restaurants(3));

      Color ringColor(int index) {
        final container = tester.widget<Container>(
          find
              .ancestor(
                of: _stripThumbnails().at(index),
                matching: find.byType(Container),
              )
              .first,
        );
        return ((container.decoration! as BoxDecoration).border! as Border)
            .top
            .color;
      }

      expect(ringColor(0), kAccentEmber);
      expect(ringColor(1), Colors.transparent);

      await tester.tap(_stripThumbnails().at(1));
      await tester.pumpAndSettle();

      expect(ringColor(0), Colors.transparent);
      expect(ringColor(1), kAccentEmber);
    });
  });

  group('LikesTabView callbacks', () {
    testWidgets('the heart and the close button both unlike', (tester) async {
      final unliked = <int>[];
      final restaurant = _restaurant(id: 4);
      await _pumpLikesTab(
        tester,
        liked: [restaurant],
        onUnlike: (value) => unliked.add(value.id),
      );

      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(unliked, [4, 4]);
    });

    testWidgets('the chat and route buttons open the restaurant',
        (tester) async {
      final opened = <int>[];
      await _pumpLikesTab(
        tester,
        liked: [_restaurant(id: 4)],
        onOpenRestaurant: (value) => opened.add(value.id),
      );

      await tester.tap(find.byIcon(Icons.chat_bubble_rounded));
      await tester.tap(find.byIcon(Icons.route_rounded));
      await tester.pump();

      expect(opened, [4, 4]);
    });

    testWidgets('acts on the selected restaurant, not the newest one',
        (tester) async {
      final unliked = <int>[];
      await _pumpLikesTab(
        tester,
        liked: _restaurants(3),
        onUnlike: (value) => unliked.add(value.id),
      );

      await tester.tap(_stripThumbnails().at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pump();

      expect(unliked, [3]);
    });

    testWidgets('the distance label is computed for the selected restaurant',
        (tester) async {
      await _pumpLikesTab(
        tester,
        liked: _restaurants(2),
        distanceLabel: (restaurant) => '${restaurant.id} km away',
      );

      expect(find.text('1 km away'), findsOneWidget);

      await tester.tap(_stripThumbnails().at(1));
      await tester.pumpAndSettle();

      expect(find.text('2 km away'), findsOneWidget);
    });
  });

  group('LikesTabView layout', () {
    /// A name long enough to need all three of the heading's lines.
    const longName = 'Restoran Nasi Kandar Pelita Simpang Empat Batu Pahat';

    Future<void> pumpBusyCard(
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
        // Six likes so the strip is capped, plus every optional chip.
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
      );
    }

    testWidgets('does not overflow on a narrow phone', (tester) async {
      await pumpBusyCard(tester, viewport: _narrowViewport);

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow on a tablet', (tester) async {
      await pumpBusyCard(tester, viewport: _tabletViewport, dpr: 2.0);

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at a large text scale', (tester) async {
      await pumpBusyCard(
        tester,
        viewport: _phoneViewport,
        textScaler: _largeTextScale,
      );

      expect(tester.takeException(), isNull);

      // Guard against a vacuous pass: the scaler really did grow the text.
      final scaledHeight = tester.getSize(find.text(_distanceLabel)).height;
      await pumpBusyCard(tester, viewport: _phoneViewport);
      expect(
        tester.getSize(find.text(_distanceLabel)).height,
        lessThan(scaledHeight),
      );
    });

    testWidgets('keeps the actions inside the viewport', (tester) async {
      await pumpBusyCard(tester, viewport: _narrowViewport);

      final viewport = logicalViewport(tester);
      for (final icon in const [
        Icons.favorite_rounded,
        Icons.close_rounded,
      ]) {
        final rect = tester.getRect(find.byIcon(icon));
        expect(rect.left, greaterThanOrEqualTo(0), reason: '$icon');
        expect(rect.right, lessThanOrEqualTo(viewport.width), reason: '$icon');
        expect(
          rect.bottom,
          lessThanOrEqualTo(viewport.height),
          reason: '$icon',
        );
      }
    });
  });
}
