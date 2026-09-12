import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:swipe_eat/features/dashboard/presentation/likes_tab.dart';
import 'package:swipe_eat/features/restaurants/presentation/restaurant_grid_card.dart';
import 'package:swipe_eat/features/restaurants/state/likes_controller.dart';

import '../../support/widget_test_support.dart';
import '../restaurants/fake_restaurant_repositories.dart';
import '../wishlist/fake_wishlist_repository.dart';

/// Reference phone viewport.
const Size _phoneViewport = Size(390, 844);

/// Everything the tab reads, held together so a test can drive the backend
/// after the tab is on screen.
class _Harness {
  _Harness({
    required this.restaurants,
    required this.swipes,
    required this.wishlist,
    required this.likes,
    required this.router,
  });

  final FakeRestaurantRepository restaurants;
  final FakeSwipeRepository swipes;
  final FakeWishlistRepository wishlist;
  final LikesController likes;
  final GoRouter router;
}

/// Pumps the real [LikesTab] under a router, because the Wishlist chip pushes
/// a route and a bare MaterialApp would throw rather than navigate.
Future<_Harness> _pumpTab(
  WidgetTester tester, {
  int likedCount = 2,
}) async {
  useViewport(tester, _phoneViewport);

  final restaurants = FakeRestaurantRepository()
    ..likedRows = [
      for (var id = 1; id <= likedCount; id++) testRestaurant(id),
    ];
  final swipes = FakeSwipeRepository();
  final wishlist = FakeWishlistRepository();
  wireFakeBackend(restaurants, swipes);

  final likes = LikesController(
    restaurants: restaurants,
    swipes: swipes,
    wishlist: wishlist,
    followAuthChanges: false,
  );
  LikesController.replaceForTests(likes);
  addTearDown(likes.dispose);

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LikesTab()),
      GoRoute(
        path: '/wishlist',
        builder: (context, state) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.pop(),
              child: const Text('wishlist route'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/restaurant/:id',
        builder: (context, state) => Scaffold(
          body: Text('restaurant ${state.pathParameters['id']}'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();

  return _Harness(
    restaurants: restaurants,
    swipes: swipes,
    wishlist: wishlist,
    likes: likes,
    router: router,
  );
}

/// Taps a chip, scrolling the row sideways first — it is wider than the phone
/// by design.
Future<void> _tapChip(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => HttpOverrides.global = ImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  group('LikesTab header', () {
    testWidgets('titles the tab and counts what is saved', (tester) async {
      await _pumpTab(tester, likedCount: 3);

      expect(find.text('Your bites'), findsOneWidget);
      expect(find.text('3 saved'), findsOneWidget);
    });

    testWidgets('says "1 saved", not "1 saveds"', (tester) async {
      await _pumpTab(tester, likedCount: 1);

      expect(find.text('1 saved'), findsOneWidget);
    });
  });

  group('LikesTab wishlist chip', () {
    testWidgets('pushes the wishlist route', (tester) async {
      final harness = await _pumpTab(tester);

      await _tapChip(tester, 'Wishlist →');

      expect(find.text('wishlist route'), findsOneWidget);
      expect(
        harness.router.routerDelegate.currentConfiguration.matches.last
            .matchedLocation,
        '/wishlist',
      );
      // Pushed, not replaced: the Bites tab is still underneath.
      expect(find.text('Your bites'), findsNothing);
    });
  });

  group('LikesTab tiles', () {
    testWidgets('tapping a tile opens the restaurant route', (tester) async {
      await _pumpTab(tester, likedCount: 2);

      await tester.tap(find.text('Restaurant 1'));
      await tester.pumpAndSettle();

      expect(find.text('restaurant 1'), findsOneWidget);
    });
  });

  group('LikesTab failure', () {
    testWidgets('a failed load offers a retry that recovers', (tester) async {
      useViewport(tester, _phoneViewport);
      final restaurants = FakeRestaurantRepository()
        ..likedRows = [testRestaurant(1)]
        ..failLiked = true;
      final swipes = FakeSwipeRepository();
      final likes = LikesController(
        restaurants: restaurants,
        swipes: swipes,
        wishlist: FakeWishlistRepository(),
        followAuthChanges: false,
      );
      LikesController.replaceForTests(likes);
      addTearDown(likes.dispose);

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const LikesTab()),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Could not load your bites.'), findsOneWidget);

      restaurants.failLiked = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.byType(RestaurantGridCard), findsOneWidget);
    });
  });
}
