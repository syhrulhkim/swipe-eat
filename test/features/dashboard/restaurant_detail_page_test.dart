import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:swipe_eat/core/location/user_location.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/core/ui/tiktok_thumbnail_placeholder.dart';
import 'package:swipe_eat/features/restaurants/data/tiktok_player_factory.dart';
import 'package:swipe_eat/features/restaurants/domain/opening_hours.dart';
import 'package:swipe_eat/features/restaurants/models/dish.dart';
import 'package:swipe_eat/features/restaurants/models/restaurant_detail_data.dart';
import 'package:swipe_eat/features/restaurants/presentation/detail/dish_list.dart';
import 'package:swipe_eat/features/restaurants/presentation/detail/facts_strip.dart';
import 'package:swipe_eat/features/restaurants/presentation/detail/friends_bite_row.dart';
import 'package:swipe_eat/features/restaurants/presentation/restaurant_detail_page.dart';
import 'package:swipe_eat/features/restaurants/presentation/restaurant_detail_route.dart';
import 'package:swipe_eat/features/restaurants/state/likes_controller.dart';
import 'package:swipe_eat/features/wishlist/state/wishlist_controller.dart';

import '../../support/widget_test_support.dart';
import '../restaurants/fake_restaurant_repositories.dart';
import '../wishlist/fake_wishlist_repository.dart';

/// Peserai, Batu Pahat — the same origin the production fallback uses, so a
/// restaurant placed on these coordinates is "0 m" away.
const double _userLat = 1.85;
const double _userLng = 102.933333;

/// The id every [_detailData] carries, so like assertions can name it.
const int _detailRestaurantId = 7;

/// Stands in for the geolocator plugin, which is not registered under
/// `flutter test`.
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
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async =>
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

late FakeRestaurantRepository _restaurants;
late FakeSwipeRepository _swipes;
late FakeWishlistRepository _wishlistBacking;
late WishlistController _wishlist;

/// Seeds the backend as if an earlier session had liked [ids].
void _seedLikes(List<int> ids) {
  _restaurants.likedRows = [for (final id in ids) testRestaurant(id)];
}

/// A clip that never arrives, so no test ever starts a real WebView.
Future<TikTokPlayerHandle> _stalledPlayer() =>
    Completer<TikTokPlayerHandle>().future;

RestaurantDetailData _detailData({
  String title = 'Warung Ayam Bakar',
  String tag = 'Grilled chicken',
  String details = '',
  double latitude = _userLat,
  double longitude = _userLng,
  List<String> imageUrls = const [],
  String? videoUrl,
  OpeningHours hours = OpeningHours.unknown,
  int? priceFrom,
  bool? isHalal,
  String? neighbourhood,
  List<Dish> dishes = const [],
}) {
  return RestaurantDetailData(
    id: _detailRestaurantId,
    title: title,
    tag: tag,
    details: details,
    color: kBrandColorFallback,
    rating: 0,
    latitude: latitude,
    longitude: longitude,
    reviewName: '',
    reviewText: '',
    imageUrls: imageUrls,
    videoUrl: videoUrl,
    hours: hours,
    priceFrom: priceFrom,
    isHalal: isHalal,
    neighbourhood: neighbourhood,
    dishes: dishes,
  );
}

/// Opens 17:30, closes 02:00 — the design's "open till 2 am".
const OpeningHours _lateNight = OpeningHours(
  opensAtMinutes: 17 * 60 + 30,
  closesAtMinutes: 2 * 60,
);

/// Where the pushed `/plans/new` route reports what it was handed.
Object? _lastPlansExtra;

Future<void> _pumpDetailPage(
  WidgetTester tester,
  RestaurantDetailData data, {
  DateTime Function()? clock,
  double textScale = 1.0,
}) async {
  _lastPlansExtra = null;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => RestaurantDetailPage(
          data: data,
          repository: _restaurants,
          wishlist: _wishlist,
          tiktokPlayerFuture: _stalledPlayer(),
          clock: clock ?? OpeningHours.kualaLumpurNow,
        ),
      ),
      GoRoute(
        path: '/plans/new',
        builder: (context, state) {
          _lastPlansExtra = state.extra;
          return const Scaffold(body: Center(child: Text('plans-new')));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      // The scaler has to be applied below MaterialApp: its own
      // MediaQuery.fromView would otherwise overwrite an ancestor's data.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
  await _settle(tester, hasVideo: data.videoUrl != null);
}

/// Never `pumpAndSettle` with a clip on screen: the player future is the one
/// that never completes, so its spinner turns forever. Fixed pumps instead,
/// enough of them to let the position, the ngap count and the wishlist land.
Future<void> _settle(WidgetTester tester, {required bool hasVideo}) async {
  if (!hasVideo) {
    await tester.pumpAndSettle();
    return;
  }
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  setUpAll(() {
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(_fixedPosition());
    HttpOverrides.global = ImageHttpOverrides();
  });

  tearDownAll(() => HttpOverrides.global = null);

  setUp(() {
    // resolveUserPosition() caches for the app session; a future cached in an
    // earlier test belongs to that test's (dead) fake-async zone.
    resetUserPositionCache();
    _restaurants = FakeRestaurantRepository();
    _swipes = FakeSwipeRepository();
    wireFakeBackend(_restaurants, _swipes);
    LikesController.replaceForTests(LikesController(
      restaurants: _restaurants,
      swipes: _swipes,
      followAuthChanges: false,
    ));
    _wishlistBacking = FakeWishlistRepository();
    _wishlist = WishlistController(repository: _wishlistBacking);
  });

  tearDown(() => _wishlist.dispose());

  group('hero', () {
    testWidgets('shows the TikTok placeholder when there is no media',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      expect(find.byType(TikTokThumbnailPlaceholder), findsOneWidget);
    });

    testWidgets('renders the first photo as the hero', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(
        tester,
        _detailData(imageUrls: const [
          'https://example.com/a.jpg',
          'https://example.com/b.jpg',
        ]),
      );

      expect(find.byType(TikTokThumbnailPlaceholder), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('says the clip is muted and where sound lives', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(
        tester,
        _detailData(videoUrl: 'https://www.tiktok.com/@kl/video/12345'),
      );

      // Not "tap to unmute": the tap opens the player that can, it does not
      // unmute in place (D4/D89).
      expect(find.text('Tap for sound'), findsOneWidget);
    });

    testWidgets('no clip means no muted hint', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      expect(find.text('Tap for sound'), findsNothing);
    });

    testWidgets('a tap on the hero opens the fullscreen player',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(
        tester,
        _detailData(videoUrl: 'https://www.tiktok.com/@kl/video/12345'),
      );

      await tester.tap(find.bySemanticsLabel('Watch TikTok review'));
      await _settle(tester, hasVideo: true);

      expect(find.bySemanticsLabel('Close player'), findsOneWidget);
    });

    testWidgets('a restaurant with no clip has nothing to open',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      expect(find.bySemanticsLabel('Watch TikTok review'), findsNothing);
    });

    testWidgets('carries the bite only once the place is liked',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      BiteNotch notch() => tester.widget<BiteNotch>(find.byType(BiteNotch));
      expect(notch().bitten, isFalse);

      await LikesController.instance.like(_detailRestaurantId);
      await tester.pumpAndSettle();

      expect(notch().bitten, isTrue);
    });
  });

  group('title block', () {
    testWidgets('shows the cuisine and the halal chip', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(isHalal: true));

      expect(find.text('Grilled chicken'), findsOneWidget);
      expect(find.text('Halal'), findsOneWidget);
    });

    testWidgets('sits the chips side by side, each only as wide as its word',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(isHalal: true));

      // A chip that takes the width it is offered would stack one per line.
      final cuisine = tester.getRect(find.text('Grilled chicken'));
      final halal = tester.getRect(find.text('Halal'));
      expect(cuisine.top, halal.top, reason: 'the chips share one row');
      expect(halal.left, greaterThan(cuisine.right));
      // Each chip is the width of its own word: two chips offered the same
      // width would measure the same.
      expect(halal.width, lessThan(cuisine.width));
    });

    testWidgets('omits the halal chip when the caption never said so',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(isHalal: null));

      expect(find.text('Halal'), findsNothing);
    });

    testWidgets('joins neighbourhood, distance and the open state',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(
        tester,
        _detailData(neighbourhood: 'Kampung Baru', hours: _lateNight),
        clock: () => DateTime(2026, 9, 7, 19, 41),
      );

      expect(find.text('Kampung Baru · 0 m · open till 2 am'), findsOneWidget);
    });

    testWidgets('lower-cases "opens" before it has opened', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(
        tester,
        _detailData(neighbourhood: 'Masai', hours: _lateNight),
        clock: () => DateTime(2026, 9, 7, 9, 0),
      );

      expect(find.text('Masai · 0 m · opens 5:30 pm'), findsOneWidget);
    });

    testWidgets('lower-cases "closed today" on a closed weekday',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(
        tester,
        _detailData(
          hours: const OpeningHours(
            opensAtMinutes: 8 * 60,
            closesAtMinutes: 17 * 60,
            closedWeekdays: {DateTime.monday},
          ),
        ),
        clock: () => DateTime(2026, 9, 7, 12, 0),
      );

      expect(find.textContaining('closed today'), findsOneWidget);
    });

    testWidgets('drops every part it cannot answer', (tester) async {
      useViewport(tester, const Size(390, 844));
      // No neighbourhood, no coordinates, no hours: nothing but the name.
      await _pumpDetailPage(
        tester,
        _detailData(latitude: 0, longitude: 0),
      );

      expect(find.text('Warung Ayam Bakar'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });
  });

  group('facts strip', () {
    testWidgets('hides the strip when nothing is known', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      expect(find.byType(FactsStrip), findsNothing);
    });

    testWidgets('shows the cheapest dish as the price fact', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(priceFrom: 19));

      expect(find.text('From RM 19'), findsOneWidget);
      expect(find.text('cheapest dish'), findsOneWidget);
    });

    testWidgets('groups the ngap count in thousands', (tester) async {
      _restaurants.ngapCounts[_detailRestaurantId] = 1204;
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      expect(find.text('1,204'), findsOneWidget);
      expect(find.text('ngaps'), findsOneWidget);
    });

    testWidgets('hides the ngap tile when nobody has bitten it yet',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(priceFrom: 12));

      // "0 ngaps" is a discouragement, not a fact worth a tile (D111).
      expect(find.text('ngaps'), findsNothing);
      expect(find.text('From RM 12'), findsOneWidget);
    });

    testWidgets('a single known fact takes the whole row', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(priceFrom: 8));

      final strip = tester.getRect(find.byType(FactsStrip));
      final tile = tester.getRect(find.text('From RM 8'));
      expect(tile.left, lessThan(strip.left + strip.width * 0.5));
      expect(strip.width, greaterThan(200));
    });

    testWidgets('never shows a wait tile — we have no wait data',
        (tester) async {
      _restaurants.ngapCounts[_detailRestaurantId] = 40;
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(priceFrom: 8));

      expect(find.textContaining('wait'), findsNothing);
      expect(find.textContaining('min'), findsNothing);
    });
  });

  group('what people bite', () {
    testWidgets('is hidden entirely when there are no dishes', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      expect(find.byType(DishList), findsNothing);
      expect(find.text('What people bite'), findsNothing);
    });

    testWidgets('renders name, description and price per dish',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(
        tester,
        _detailData(dishes: const [
          Dish(
            id: 1,
            name: 'Nasi lemak ayam berempah',
            description: 'Coconut rice, spiced fried chicken, sambal',
            priceRm: 12,
          ),
          Dish(id: 2, name: 'Teh tarik', description: 'Pulled, frothy'),
        ]),
      );

      expect(find.text('What people bite'), findsOneWidget);
      expect(find.text('Nasi lemak ayam berempah'), findsOneWidget);
      expect(
        find.text('Coconut rice, spiced fried chicken, sambal'),
        findsOneWidget,
      );
      expect(find.text('RM 12'), findsOneWidget);
      // A dish with no price on file shows none rather than a made-up one.
      expect(find.text('Teh tarik'), findsOneWidget);
    });
  });

  group('about', () {
    testWidgets('is hidden when the caption is empty', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData(details: ''));

      expect(find.text('About'), findsNothing);
    });

    testWidgets('expands on More', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(
        tester,
        _detailData(details: 'A tiny shophouse stall with a big charcoal '
            'grill, open late, and a queue that never quite ends.'),
      );

      expect(find.text('More'), findsOneWidget);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Less'), findsOneWidget);
    });
  });

  group('friends', () {
    testWidgets('renders nothing until the social graph exists',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      expect(find.byType(FriendsBiteRow), findsOneWidget);
      expect(
        tester.getSize(find.byType(FriendsBiteRow)),
        Size.zero,
        reason: 'an empty friends row occupies no space',
      );
    });
  });

  group('wishlist bookmark', () {
    testWidgets('starts hollow and fills once the place is added',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Add to wishlist'));
      await tester.pumpAndSettle();

      expect(_wishlistBacking.calls, contains('addRestaurant:7'));
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.bookmark_rounded)).color,
        kAccentEmber,
      );
    });

    testWidgets('starts filled for a place already on the list',
        (tester) async {
      _wishlistBacking.seed([
        testWishlistItem(1, restaurantId: _detailRestaurantId),
      ]);
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      expect(find.bySemanticsLabel('Remove from wishlist'), findsOneWidget);
    });

    testWidgets('tapping a filled bookmark removes the row', (tester) async {
      _wishlistBacking.seed([
        testWishlistItem(1, restaurantId: _detailRestaurantId),
      ]);
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      await tester.tap(find.bySemanticsLabel('Remove from wishlist'));
      await tester.pumpAndSettle();

      expect(_wishlistBacking.calls, contains('remove:1'));
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    });

    testWidgets('a refused write explains itself', (tester) async {
      _wishlistBacking.failWrite = true;
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      await tester.tap(find.bySemanticsLabel('Add to wishlist'));
      await tester.pumpAndSettle();

      expect(find.text('Could not add that place.'), findsOneWidget);
    });
  });

  group('set a date', () {
    testWidgets('bites the place first when it is not liked yet',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      await tester.tap(find.text('Set a date'));
      await tester.pumpAndSettle();

      // A plan is always on a bitten place (D112).
      expect(LikesController.instance.isLiked(_detailRestaurantId), isTrue);
      expect(_swipes.calls.single.liked, isTrue);
      expect(_swipes.calls.single.source, 'detail');
      expect(find.text('plans-new'), findsOneWidget);
    });

    testWidgets('does not re-record a like the place already has',
        (tester) async {
      _seedLikes([_detailRestaurantId]);
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      await tester.tap(find.text('Set a date'));
      await tester.pumpAndSettle();

      expect(_swipes.calls, isEmpty);
      expect(find.text('plans-new'), findsOneWidget);
    });

    testWidgets('hands the planner the restaurant it is planning',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(
        tester,
        _detailData(
          neighbourhood: 'Kampung Baru',
          imageUrls: const ['https://example.com/a.jpg'],
        ),
      );

      await tester.tap(find.text('Set a date'));
      await tester.pumpAndSettle();

      expect(_lastPlansExtra, <String, dynamic>{
        'restaurantId': _detailRestaurantId,
        'title': 'Warung Ayam Bakar',
        'coverUrl': 'https://example.com/a.jpg',
        'neighbourhood': 'Kampung Baru',
        'tag': 'Grilled chicken',
      });
    });

    testWidgets('a refused like keeps the user here', (tester) async {
      _swipes.fail = true;
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, _detailData());

      await tester.tap(find.text('Set a date'));
      await tester.pumpAndSettle();

      // Arriving at the planner having silently failed the thing the planner
      // assumes is worse than not arriving.
      expect(find.text('plans-new'), findsNothing);
      expect(find.text('Could not save that change.'), findsOneWidget);
    });
  });

  group('directions', () {
    testWidgets('offers directions for a restaurant with a real fix',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(
        tester,
        _detailData(latitude: 1.5078255, longitude: 103.7434649),
      );

      expect(find.bySemanticsLabel('Directions'), findsOneWidget);
    });

    testWidgets('hides directions for a restaurant seeded without a fix',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      // 0,0 is the "no coordinates" sentinel, not a place to route to.
      await _pumpDetailPage(tester, _detailData(latitude: 0, longitude: 0));

      expect(find.bySemanticsLabel('Directions'), findsNothing);
      // …and the CTA still fills the bar.
      expect(find.text('Set a date'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('the back button pops the route', (tester) async {
      useViewport(tester, const Size(390, 844));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('deck-behind'))),
          ),
          GoRoute(
            path: '/restaurant',
            builder: (context, state) => RestaurantDetailPage(
              data: _detailData(),
              repository: _restaurants,
              wishlist: _wishlist,
              tiktokPlayerFuture: _stalledPlayer(),
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Pushed, not the initial location: a route with nothing under it has
      // nothing to pop back to, which would test the wrong thing.
      unawaited(router.push<void>('/restaurant'));
      await tester.pumpAndSettle();
      expect(find.text('deck-behind'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();

      expect(find.text('deck-behind'), findsOneWidget);
    });
  });

  group('semantics', () {
    testWidgets('labels every icon-only control', (tester) async {
      final handle = tester.ensureSemantics();
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(
        tester,
        _detailData(
          latitude: 1.5078255,
          longitude: 103.7434649,
          videoUrl: 'https://www.tiktok.com/@kl/video/12345',
        ),
      );

      for (final label in const [
        'Back',
        'Add to wishlist',
        'Directions',
        'Watch TikTok review',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }

      handle.dispose();
    });

    testWidgets('every control is at least a finger wide', (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(
        tester,
        _detailData(latitude: 1.5078255, longitude: 103.7434649),
      );

      for (final label in const ['Back', 'Add to wishlist', 'Directions']) {
        final size = tester.getSize(find.bySemanticsLabel(label));
        expect(size.width, greaterThanOrEqualTo(kMinTapTarget), reason: label);
        expect(size.height, greaterThanOrEqualTo(kMinTapTarget), reason: label);
      }
    });
  });

  group('layout', () {
    RestaurantDetailData full({String? title}) {
      return _detailData(
        title: title ?? 'Warung Ayam Bakar',
        neighbourhood: 'Kampung Baru',
        hours: _lateNight,
        priceFrom: 19,
        isHalal: true,
        details: 'A tiny shophouse stall with a very big charcoal grill.',
        imageUrls: const ['https://example.com/a.jpg'],
        dishes: const [
          Dish(
            id: 1,
            name: 'Nasi lemak ayam berempah',
            description: 'Coconut rice, spiced fried chicken, sambal',
            priceRm: 12,
          ),
        ],
      );
    }

    testWidgets('lays out without overflow on a small phone', (tester) async {
      _restaurants.ngapCounts[_detailRestaurantId] = 1204;
      useViewport(tester, const Size(375, 667));
      await _pumpDetailPage(tester, full());

      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out without overflow on a narrow phone', (tester) async {
      _restaurants.ngapCounts[_detailRestaurantId] = 1204;
      useViewport(tester, const Size(320, 568));
      await _pumpDetailPage(tester, full());

      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out without overflow on a tablet', (tester) async {
      _restaurants.ngapCounts[_detailRestaurantId] = 1204;
      useViewport(tester, const Size(1024, 1366), dpr: 2.0);
      await _pumpDetailPage(tester, full());

      expect(tester.takeException(), isNull);
    });

    testWidgets('survives a long name at 320 px and double text',
        (tester) async {
      _restaurants.ngapCounts[_detailRestaurantId] = 1204;
      useViewport(tester, const Size(320, 568));
      await _pumpDetailPage(
        tester,
        full(title: 'Restoran Nasi Kandar Pelita Simpang Empat Batu Pahat'),
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('the hero takes about two fifths of the screen',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, full());

      final hero = tester.getRect(find.byType(BiteNotch));
      expect(hero.top, 0);
      expect(hero.height, closeTo(844 * kDetailHeroFraction, 1));
    });

    testWidgets('the CTA bar stays on screen without scrolling',
        (tester) async {
      useViewport(tester, const Size(390, 844));
      await _pumpDetailPage(tester, full());

      final cta = tester.getRect(find.text('Set a date'));
      expect(cta.bottom, lessThanOrEqualTo(844));
    });
  });

  group('RestaurantDetailRoute', () {
    Future<void> pumpRoute(
      WidgetTester tester, {
      int? id,
      RestaurantDetailData? initialData,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RestaurantDetailRoute(
            restaurantId: id,
            initialData: initialData,
            repository: _restaurants,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('paints the payload without refetching', (tester) async {
      useViewport(tester, const Size(390, 844));
      await pumpRoute(
        tester,
        id: _detailRestaurantId,
        initialData: _detailData(title: 'Kopitiam Lama'),
      );

      expect(find.text('Kopitiam Lama'), findsOneWidget);
    });

    testWidgets('loads by id when it has only an id', (tester) async {
      _restaurants.catalogRows = [testRestaurant(9, name: 'Nasi Kandar Deen')];
      useViewport(tester, const Size(390, 844));
      await pumpRoute(tester, id: 9);

      expect(find.text('Nasi Kandar Deen'), findsOneWidget);
    });

    testWidgets('says so when the id resolves to nothing', (tester) async {
      useViewport(tester, const Size(390, 844));
      await pumpRoute(tester, id: 404);

      expect(find.text('Restaurant not found'), findsOneWidget);
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
    });

    testWidgets('offers a retry when the fetch fails', (tester) async {
      _restaurants.failFetchById = true;
      useViewport(tester, const Size(390, 844));
      await pumpRoute(tester, id: 9);

      expect(find.text('Could not open this restaurant'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      _restaurants.failFetchById = false;
      _restaurants.catalogRows = [testRestaurant(9, name: 'Nasi Kandar Deen')];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Nasi Kandar Deen'), findsOneWidget);
    });
  });
}
