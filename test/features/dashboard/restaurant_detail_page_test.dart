import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:swipe_eat/core/location/user_location.dart';
import 'package:swipe_eat/core/ui/tiktok_thumbnail_placeholder.dart';
import 'package:swipe_eat/features/restaurants/models/restaurant_detail_data.dart';
import 'package:swipe_eat/features/restaurants/presentation/restaurant_detail_page.dart';
import 'package:swipe_eat/features/restaurants/state/likes_controller.dart';

import '../../support/widget_test_support.dart';
import '../restaurants/fake_restaurant_repositories.dart';

/// Lime accent used for active/selected state in the redesign.
const Color _kAccent = Color(0xFFB4E33D);

/// Peserai, Batu Pahat — the same origin the production fallback uses, so a
/// restaurant placed on these coordinates is "0 m away".
const double _userLat = 1.85;
const double _userLng = 102.933333;

/// Stands in for the geolocator plugin, which is not registered under
/// `flutter test`. Swapping the platform interface (rather than the raw method
/// channel) keeps the fake independent of which federated implementation the
/// host platform would pick.
class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  _FakeGeolocatorPlatform(this.position);

  final Position position;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition(
          {LocationSettings? locationSettings}) async =>
      position;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async =>
      position;
}

Position _fixedPosition() {
  return Position(
    longitude: _userLng,
    latitude: _userLat,
    timestamp: DateTime.utc(2026, 1, 1),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

/// The id every [_detailData] carries, so like assertions can name it.
const int _detailRestaurantId = 7;

/// The fake backend behind [LikesController.instance] for the current test.
late FakeRestaurantRepository _restaurants;
late FakeSwipeRepository _swipes;

/// Seeds the backend as if an earlier session had liked [ids].
void _seedLikes(List<int> ids) {
  _restaurants.likedRows = [for (final id in ids) testRestaurant(id)];
}

RestaurantDetailData _detailData({
  String title = 'Warung Ayam Bakar',
  String tag = 'Grilled chicken',
  String details = 'A tiny shophouse stall with a very big charcoal grill.',
  double rating = 0,
  double latitude = _userLat,
  double longitude = _userLng,
  String reviewName = 'Aisyah',
  String reviewText = 'The sambal alone is worth the drive.',
  List<String> imageUrls = const [],
  String? videoUrl,
}) {
  return RestaurantDetailData(
    id: _detailRestaurantId,
    title: title,
    tag: tag,
    details: details,
    color: const Color(0xFF141922),
    rating: rating,
    latitude: latitude,
    longitude: longitude,
    reviewName: reviewName,
    reviewText: reviewText,
    imageUrls: imageUrls,
    videoUrl: videoUrl,
  );
}

List<String> _images(int count) {
  return List<String>.generate(
    count,
    (index) => 'https://example.com/photo-$index.jpg',
  );
}

Future<void> _pumpDetailPage(
  WidgetTester tester,
  RestaurantDetailData data,
) async {
  await tester.pumpWidget(
    MaterialApp(home: RestaurantDetailPage(data: data)),
  );
  await tester.pumpAndSettle();
}

/// The thumbnails inside the frosted photo-switcher pill. Only the strip nests
/// [Image] widgets inside a [BackdropFilter] — the glass circle buttons hold
/// icons — so this isolates the strip without reaching into private widgets.
Finder _stripThumbnails() {
  return find.descendant(
    of: find.byType(BackdropFilter),
    matching: find.byType(Image),
  );
}

/// The selection-ring colour of the nth strip thumbnail.
Color _ringColor(WidgetTester tester, int index) {
  final container = tester.widget<Container>(
    find
        .ancestor(
          of: _stripThumbnails().at(index),
          matching: find.byType(Container),
        )
        .first,
  );
  final decoration = container.decoration! as BoxDecoration;
  return (decoration.border! as Border).top.color;
}

void main() {
  setUpAll(() {
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(_fixedPosition());
    HttpOverrides.global = ImageHttpOverrides();
  });

  setUp(() {
    // resolveUserPosition() caches for the app session; a future cached in an
    // earlier test belongs to that test's (dead) fake-async zone and would
    // never deliver here.
    resetUserPositionCache();
    // The like button writes through LikesController.instance, a singleton:
    // give every test its own controller over a fresh fake backend.
    _restaurants = FakeRestaurantRepository();
    _swipes = FakeSwipeRepository();
    wireFakeBackend(_restaurants, _swipes);
    LikesController.replaceForTests(LikesController(
      restaurants: _restaurants,
      swipes: _swipes,
      followAuthChanges: false,
    ));
  });

  group('RestaurantDetailData.fromPayload', () {
    test('round-trips every field', () {
      final data = RestaurantDetailData.fromPayload({
        'id': 12,
        'title': 'Kopitiam Lama',
        'tag': 'Coffee',
        'details': 'Old-school kopi.',
        'color': 0xFF123456,
        'rating': 4.25,
        'latitude': 1.5,
        'longitude': 103.1,
        'reviewName': 'Ben',
        'reviewText': 'Strong kopi o.',
        'imageUrls': ['https://example.com/a.jpg'],
        'videoUrl': 'https://www.tiktok.com/@johorfoodie/video/12345',
      });

      expect(data.id, 12);
      expect(data.title, 'Kopitiam Lama');
      expect(data.tag, 'Coffee');
      expect(data.details, 'Old-school kopi.');
      expect(data.color, const Color(0xFF123456));
      expect(data.rating, 4.25);
      expect(data.latitude, 1.5);
      expect(data.longitude, 103.1);
      expect(data.reviewName, 'Ben');
      expect(data.reviewText, 'Strong kopi o.');
      expect(data.imageUrls, ['https://example.com/a.jpg']);
      expect(data.videoUrl, 'https://www.tiktok.com/@johorfoodie/video/12345');
    });

    test('falls back to safe defaults for an empty payload', () {
      final data = RestaurantDetailData.fromPayload(const {});

      expect(data.id, 0);
      expect(data.title, 'Restaurant');
      expect(data.tag, isEmpty);
      expect(data.details, isEmpty);
      expect(data.color, const Color(0xFF141922));
      expect(data.rating, 0);
      expect(data.latitude, 0);
      expect(data.longitude, 0);
      expect(data.imageUrls, isEmpty);
      expect(data.videoUrl, isNull);
    });

    test('stringifies non-string image URL entries', () {
      final data = RestaurantDetailData.fromPayload(const {
        'imageUrls': ['https://example.com/a.jpg', 42],
      });

      expect(data.imageUrls, ['https://example.com/a.jpg', '42']);
    });
  });

  group('RestaurantDetailPage title', () {
    testWidgets('omits the rating dash when the rating is 0', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(rating: 0));

      // The whole heading is one Text.rich; with no rating it is just the name.
      expect(find.text('Warung Ayam Bakar'), findsOneWidget);
      expect(find.textContaining('–'), findsNothing);
    });

    testWidgets('appends the rating when it is above 0', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(rating: 4.5));

      expect(find.text('Warung Ayam Bakar  4.5'), findsOneWidget);
      expect(find.text('Warung Ayam Bakar'), findsNothing);
      // ...and the rating also shows as its own chip.
      expect(find.text('4.5'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('hides the rating chip when the rating is 0', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(rating: 0));

      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });
  });

  group('RestaurantDetailPage hero', () {
    testWidgets('shows the TikTok placeholder when there are no photos',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(
        tester,
        _detailData(
          videoUrl: 'https://www.tiktok.com/@johorfoodie/video/12345',
        ),
      );

      // Only the hero: the "More photos" card is skipped with no images.
      expect(find.byType(TikTokThumbnailPlaceholder), findsOneWidget);
      expect(find.text('@johorfoodie'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('renders the first photo as the hero', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(imageUrls: _images(3)));

      expect(
        find.byKey(const ValueKey('https://example.com/photo-0.jpg')),
        findsOneWidget,
      );
      expect(find.byType(TikTokThumbnailPlaceholder), findsNothing);
    });
  });

  group('RestaurantDetailPage thumbnail strip', () {
    testWidgets('is hidden for a single photo', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(imageUrls: _images(1)));

      expect(_stripThumbnails(), findsNothing);
    });

    testWidgets('is hidden when there are no photos', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      expect(_stripThumbnails(), findsNothing);
    });

    testWidgets('shows one thumbnail per photo for a small gallery',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(imageUrls: _images(3)));

      expect(_stripThumbnails(), findsNWidgets(3));
    });

    testWidgets('caps the strip at five thumbnails', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(imageUrls: _images(9)));

      expect(_stripThumbnails(), findsNWidgets(5));
    });

    testWidgets('tapping a thumbnail swaps the hero image', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(imageUrls: _images(4)));

      await tester.tap(_stripThumbnails().at(2));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('https://example.com/photo-2.jpg')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('https://example.com/photo-0.jpg')),
        findsNothing,
      );
    });

    testWidgets('rings only the active thumbnail with the lime accent',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(imageUrls: _images(4)));

      expect(_ringColor(tester, 0), _kAccent);
      expect(_ringColor(tester, 1), Colors.transparent);
      expect(_ringColor(tester, 3), Colors.transparent);

      await tester.tap(_stripThumbnails().at(3));
      await tester.pumpAndSettle();

      expect(_ringColor(tester, 0), Colors.transparent);
      expect(_ringColor(tester, 3), _kAccent);
    });

    testWidgets('sits in the top control bar, not mid-screen', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(imageUrls: _images(3)));

      final viewport = logicalViewport(tester);
      final backRect = tester.getRect(find.byIcon(Icons.arrow_back_rounded));
      final stripRect = tester.getRect(_stripThumbnails().first);

      // The controls are described as "fixed top controls"; anything past the
      // first fifth of the screen means they were vertically centred instead.
      expect(backRect.top, lessThan(viewport.height * 0.2));
      expect(stripRect.top, lessThan(viewport.height * 0.2));
    });
  });

  group('RestaurantDetailPage actions', () {
    testWidgets('the like button toggles to the lime accent', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      Color? likeColor() {
        return tester.widget<Icon>(find.byIcon(Icons.favorite_rounded)).color;
      }

      expect(likeColor(), Colors.white);

      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pumpAndSettle();
      expect(likeColor(), _kAccent);

      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pumpAndSettle();
      expect(likeColor(), Colors.white);
    });

    testWidgets('the reviews button scrolls the Top review card into view',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(imageUrls: _images(2)));

      final viewport = logicalViewport(tester);
      expect(
        tester.getRect(find.text('Top review')).top,
        greaterThan(viewport.height),
        reason: 'the review card should start below the fold',
      );

      await tester.tap(find.byIcon(Icons.chat_bubble_rounded));
      await tester.pumpAndSettle();

      final reviewRect = tester.getRect(find.text('Top review'));
      expect(reviewRect.top, greaterThanOrEqualTo(0));
      expect(reviewRect.bottom, lessThanOrEqualTo(viewport.height));
      expect(find.text('The sambal alone is worth the drive.'), findsOneWidget);
    });

    testWidgets('the route button scrolls the Location card into view',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(imageUrls: _images(2)));

      final viewport = logicalViewport(tester);
      expect(
        tester.getRect(find.text('Location')).top,
        greaterThan(viewport.height),
      );

      await tester.tap(find.byIcon(Icons.route_rounded));
      await tester.pumpAndSettle();

      final locationRect = tester.getRect(find.text('Location'));
      expect(locationRect.top, greaterThanOrEqualTo(0));
      expect(locationRect.bottom, lessThanOrEqualTo(viewport.height));
    });

    testWidgets('shows the empty-review copy when there is no review text',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(reviewText: ''));

      await tester.tap(find.byIcon(Icons.chat_bubble_rounded));
      await tester.pumpAndSettle();

      expect(find.text('No reviews yet'), findsOneWidget);
      expect(find.text('Aisyah'), findsNothing);
    });
  });

  group('RestaurantDetailPage like button', () {
    Color? heartColor(WidgetTester tester) {
      return tester.widget<Icon>(find.byIcon(Icons.favorite_rounded)).color;
    }

    testWidgets('starts unlit when the restaurant is not liked',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      expect(heartColor(tester), Colors.white);
    });

    testWidgets('starts lime when the backend already holds the like',
        (tester) async {
      _seedLikes([_detailRestaurantId]);
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      expect(heartColor(tester), _kAccent);
    });

    testWidgets('ignores likes belonging to other restaurants', (tester) async {
      _seedLikes([_detailRestaurantId + 1]);
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      expect(heartColor(tester), Colors.white);
    });

    testWidgets('tapping it records a liked swipe from the detail page',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pumpAndSettle();

      expect(LikesController.instance.isLiked(_detailRestaurantId), isTrue);
      expect(_swipes.calls, hasLength(1));
      expect(_swipes.calls.single.restaurantId, _detailRestaurantId);
      expect(_swipes.calls.single.liked, isTrue);
      expect(_swipes.calls.single.source, 'detail');
    });

    testWidgets('tapping it again records the unlike', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pumpAndSettle();

      expect(LikesController.instance.isLiked(_detailRestaurantId), isFalse);
      expect(_swipes.calls, hasLength(2));
      expect(_swipes.calls.last.liked, isFalse);
      expect(_swipes.calls.last.source, 'detail');
    });

    testWidgets('a refused write leaves the heart unlit and explains itself',
        (tester) async {
      _swipes.fail = true;
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pumpAndSettle();

      // The optimistic fill must roll back — a lit heart over a write the
      // backend never saw would be a lie that survives until the next fetch.
      expect(heartColor(tester), Colors.white);
      expect(find.text('Could not save that change.'), findsOneWidget);
    });

    testWidgets('follows a like made elsewhere in the app', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());
      expect(heartColor(tester), Colors.white);

      // Liked elsewhere (e.g. a right swipe on the deck) while this page is
      // still mounted: no pumpWidget, so only the controller listener can
      // update it.
      await LikesController.instance.like(_detailRestaurantId);
      await tester.pumpAndSettle();
      expect(heartColor(tester), _kAccent);

      await LikesController.instance.unlike(_detailRestaurantId);
      await tester.pumpAndSettle();
      expect(heartColor(tester), Colors.white);
    });

    testWidgets('relabels itself for screen readers when liked',
        (tester) async {
      final handle = tester.ensureSemantics();
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      expect(find.bySemanticsLabel('Like'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Liked'), findsOneWidget);
      expect(find.bySemanticsLabel('Like'), findsNothing);

      handle.dispose();
    });
  });

  group('RestaurantDetailPage navigation', () {
    Future<GlobalKey<NavigatorState>> pushDetail(
      WidgetTester tester,
      RestaurantDetailData data,
    ) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Center(child: Text('deck-behind'))),
        ),
      );
      unawaitedPush(navigatorKey, data);
      await tester.pumpAndSettle();
      expect(find.text('deck-behind'), findsNothing);
      return navigatorKey;
    }

    testWidgets('the close button pops the route', (tester) async {
      useViewport(tester, const Size(390, 844));
      await pushDetail(tester, _detailData());

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('deck-behind'), findsOneWidget);
      expect(find.byType(RestaurantDetailPage), findsNothing);
    });

    testWidgets('the back button pops the route', (tester) async {
      useViewport(tester, const Size(390, 844));
      await pushDetail(tester, _detailData());

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('deck-behind'), findsOneWidget);
      expect(find.byType(RestaurantDetailPage), findsNothing);
    });

    testWidgets('as a root route the close button is a no-op', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // maybePop on the only route must not tear the app down.
      expect(find.byType(RestaurantDetailPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('RestaurantDetailPage TikTok affordance', () {
    testWidgets('hides the play button when there is no video', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(imageUrls: _images(2)));

      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.text('TikTok Review'), findsNothing);
    });

    testWidgets('hides the play button for an empty video URL', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(videoUrl: ''));

      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('shows the play button and chip when a video exists',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(
        tester,
        _detailData(
          imageUrls: _images(2),
          videoUrl: 'https://www.tiktok.com/@johorfoodie/video/12345',
        ),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('TikTok Review'), findsOneWidget);
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });

    testWidgets('tapping play pushes a player route', (tester) async {
      useViewport(tester, const Size(390, 844));
      final observer = _RouteLog();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: RestaurantDetailPage(
            data: _detailData(
              videoUrl: 'https://www.tiktok.com/@johorfoodie/video/12345',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      observer.pushes.clear();

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      expect(observer.pushes, hasLength(1));
    });
  });

  group('RestaurantDetailPage semantics', () {
    testWidgets('labels the icon-only controls for screen readers',
        (tester) async {
      final handle = tester.ensureSemantics();
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(
        tester,
        _detailData(
          imageUrls: _images(3),
          videoUrl: 'https://www.tiktok.com/@johorfoodie/video/12345',
        ),
      );

      for (final label in const [
        'Like',
        'Reviews',
        'Close',
        'Back',
        'Watch TikTok review',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }

      // 'Location' is also the heading of the location card further down.
      expect(find.bySemanticsLabel('Location'), findsAtLeastNWidgets(1));

      handle.dispose();
    });
  });

  group('RestaurantDetailPage distance', () {
    testWidgets('replaces the loading label once the position resolves',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(home: RestaurantDetailPage(data: _detailData())),
      );

      // First frame: the geolocator future has not completed yet.
      expect(find.text('Distance loading'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Distance loading'), findsNothing);
      expect(find.text('0 m away'), findsOneWidget);
    });

    testWidgets('formats a kilometre-scale distance', (tester) async {
      useViewport(tester, const Size(390, 844));
      // ~0.045 degrees of latitude is roughly 5 km.
      await _pumpDetailPage(tester, _detailData(latitude: _userLat + 0.045));

      // Once in the header, once inside the Location card.
      expect(find.text('5.0 km away'), findsOneWidget);
      expect(find.text('5.0 km away from your location'), findsOneWidget);
    });

    testWidgets('clamps very distant restaurants', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(latitude: _userLat + 20));

      expect(find.text('100km +'), findsOneWidget);
    });
  });

  group('RestaurantDetailPage directions', () {
    testWidgets('offers directions for a restaurant with a real fix',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(
        tester,
        _detailData(latitude: 1.5078255, longitude: 103.7434649),
      );

      expect(find.text('Get directions'), findsOneWidget);
    });

    testWidgets('hides directions for a restaurant seeded without a fix',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      // 0,0 is the "no coordinates" sentinel, not a place to route to.
      await _pumpDetailPage(tester, _detailData(latitude: 0, longitude: 0));

      expect(find.text('Get directions'), findsNothing);
    });

    testWidgets('says so instead of measuring to the 0,0 sentinel',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(latitude: 0, longitude: 0));

      expect(find.text('Distance unknown'), findsOneWidget);
      expect(find.text('No location on file for this place'), findsOneWidget);
      expect(find.text('100km +'), findsNothing);
    });
  });

  group('RestaurantDetailPage layout', () {
    testWidgets('lays out without overflow on a small phone', (tester) async {
      useViewport(tester, const Size(375, 667));
      await _pumpDetailPage(
        tester,
        _detailData(
          rating: 4.9,
          imageUrls: _images(5),
          videoUrl: 'https://www.tiktok.com/@johorfoodie/video/12345',
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out without overflow on a narrow phone', (tester) async {
      useViewport(tester, const Size(320, 568));
      await _pumpDetailPage(
        tester,
        _detailData(
          rating: 4.9,
          imageUrls: _images(5),
          videoUrl: 'https://www.tiktok.com/@johorfoodie/video/12345',
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out without overflow on a tablet', (tester) async {
      useViewport(tester, const Size(1024, 1366), dpr: 2.0);
      await _pumpDetailPage(
        tester,
        _detailData(
          rating: 4.9,
          imageUrls: _images(5),
          videoUrl: 'https://www.tiktok.com/@johorfoodie/video/12345',
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('survives a long title and a huge text scale', (tester) async {
      useViewport(tester, const Size(375, 667));
      await tester.pumpWidget(
        MaterialApp(
          // The scaler has to be applied below MaterialApp: its own
          // MediaQuery.fromView would otherwise overwrite an ancestor's data.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: RestaurantDetailPage(
            data: _detailData(
              title: 'Restoran Nasi Kandar Pelita Simpang Empat Batu Pahat',
              rating: 4.9,
              imageUrls: _images(5),
              videoUrl: 'https://www.tiktok.com/@johorfoodie/video/12345',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolls to reveal the detail cards', (tester) async {
      useViewport(tester, const Size(375, 667));
      await _pumpDetailPage(tester, _detailData(imageUrls: _images(2)));

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1200),
      );
      await tester.pumpAndSettle();

      expect(find.text('More photos'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Top review'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

void unawaitedPush(
  GlobalKey<NavigatorState> navigatorKey,
  RestaurantDetailData data,
) {
  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => RestaurantDetailPage(data: data),
    ),
  );
}

class _RouteLog extends NavigatorObserver {
  final List<Route<dynamic>> pushes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes.add(route);
  }
}
