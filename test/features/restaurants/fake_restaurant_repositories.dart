import 'dart:ui';

import 'package:swipe_eat/features/restaurants/data/restaurant_repository.dart';
import 'package:swipe_eat/features/restaurants/data/swipe_repository.dart';
import 'package:swipe_eat/features/restaurants/models/restaurant.dart';

/// A minimal but real [Restaurant] for list/like fixtures.
Restaurant testRestaurant(int id, {String? name}) {
  return Restaurant(
    id: id,
    name: name ?? 'Restaurant $id',
    tag: 'Malay',
    details: 'Test restaurant $id',
    brandColor: const Color(0xFF141922),
    rating: 0,
    latitude: 1.85,
    longitude: 102.93,
    imageUrls: const [],
    reviews: const [],
  );
}

class FakeRestaurantRepository implements RestaurantRepository {
  List<Restaurant> deckRows = const [];

  /// What `get_liked_restaurants` would return, newest like first.
  List<Restaurant> likedRows = const [];
  List<Restaurant> searchRows = const [];

  /// Rows the detail route can open by id.
  List<Restaurant> catalogRows = const [];

  bool failDeck = false;
  bool failLiked = false;
  bool failSearch = false;
  bool failFetchById = false;

  int likedFetches = 0;

  @override
  Future<List<Restaurant>> fetchDeck({
    double? latitude,
    double? longitude,
    int limit = 30,
  }) async {
    if (failDeck) {
      throw Exception('deck unavailable');
    }
    return deckRows;
  }

  @override
  Future<Restaurant?> fetchById(int id) async {
    if (failFetchById) {
      throw Exception('restaurant unavailable');
    }
    for (final restaurant in catalogRows) {
      if (restaurant.id == id) {
        return restaurant;
      }
    }
    return null;
  }

  @override
  Future<List<Restaurant>> likedRestaurants({int limit = 200}) async {
    likedFetches++;
    if (failLiked) {
      throw Exception('likes unavailable');
    }
    return List.of(likedRows);
  }

  @override
  Future<List<Restaurant>> search({
    String? query,
    double? latitude,
    double? longitude,
    int limit = 100,
  }) async {
    if (failSearch) {
      throw Exception('search unavailable');
    }
    return searchRows;
  }
}

class SwipeCall {
  const SwipeCall({
    required this.restaurantId,
    required this.liked,
    required this.source,
    this.latitude,
    this.longitude,
  });

  final int restaurantId;
  final bool liked;
  final String source;
  final double? latitude;
  final double? longitude;
}

class FakeSwipeRepository implements SwipeRepository {
  final List<SwipeCall> calls = [];
  bool fail = false;

  /// Lets a test act as the backend: e.g. mirror a successful swipe into a
  /// [FakeRestaurantRepository.likedRows] so the follow-up refresh agrees
  /// with the optimistic update, the way the real swipes table would.
  void Function(SwipeCall call)? onRecord;

  @override
  Future<void> record({
    required int restaurantId,
    required bool liked,
    String source = 'deck',
    double? latitude,
    double? longitude,
  }) async {
    if (fail) {
      throw Exception('swipe write refused');
    }
    final call = SwipeCall(
      restaurantId: restaurantId,
      liked: liked,
      source: source,
      latitude: latitude,
      longitude: longitude,
    );
    calls.add(call);
    onRecord?.call(call);
  }
}

/// Wires the two fakes together so they behave like one backend: a recorded
/// like inserts the restaurant at the top of [restaurants.likedRows], an
/// unlike removes it — mirroring `record_swipe` + `get_liked_restaurants`.
void wireFakeBackend(
  FakeRestaurantRepository restaurants,
  FakeSwipeRepository swipes,
) {
  swipes.onRecord = (call) {
    final without = [
      for (final row in restaurants.likedRows)
        if (row.id != call.restaurantId) row,
    ];
    restaurants.likedRows = call.liked
        ? [testRestaurant(call.restaurantId), ...without]
        : without;
  };
}
