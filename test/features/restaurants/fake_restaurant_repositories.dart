import 'package:swipe_eat/core/ui/design_tokens.dart';

import 'package:swipe_eat/features/restaurants/data/restaurant_repository.dart';
import 'package:swipe_eat/features/restaurants/data/swipe_repository.dart';
import 'package:swipe_eat/features/restaurants/models/cuisine_count.dart';
import 'package:swipe_eat/features/restaurants/models/restaurant.dart';

/// A minimal but real [Restaurant] for list/like fixtures.
Restaurant testRestaurant(int id, {String? name}) {
  return Restaurant(
    id: id,
    name: name ?? 'Restaurant $id',
    tag: 'Malay',
    details: 'Test restaurant $id',
    brandColor: kBrandColorFallback,
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

  /// What `get_cuisine_counts` would return, biggest category first.
  List<CuisineCount> cuisineRows = const [];

  /// What `get_visited_restaurants` / `get_reviewed_restaurants` /
  /// `get_super_liked_ids` would return.
  List<Restaurant> visitedRows = const [];
  List<Restaurant> reviewedRows = const [];
  Set<int> superLikedRows = const {};

  bool failDeck = false;
  bool failLiked = false;
  bool failSearch = false;
  bool failFetchById = false;
  bool failCuisines = false;
  bool failVisited = false;
  bool failReviewed = false;
  bool failSuperLiked = false;

  /// The cuisineId of the latest [search] call, null included.
  int? lastSearchCuisineId;

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
    int? cuisineId,
    int limit = 100,
  }) async {
    lastSearchCuisineId = cuisineId;
    if (failSearch) {
      throw Exception('search unavailable');
    }
    return searchRows;
  }

  @override
  Future<List<CuisineCount>> cuisineCounts() async {
    if (failCuisines) {
      throw Exception('cuisines unavailable');
    }
    return List.of(cuisineRows);
  }

  @override
  Future<List<Restaurant>> visitedRestaurants({
    int limit = 50,
    int offset = 0,
  }) async {
    if (failVisited) {
      throw Exception('visited unavailable');
    }
    return List.of(visitedRows);
  }

  @override
  Future<List<Restaurant>> reviewedRestaurants({
    int limit = 50,
    int offset = 0,
  }) async {
    if (failReviewed) {
      throw Exception('reviewed unavailable');
    }
    return List.of(reviewedRows);
  }

  @override
  Future<Set<int>> superLikedIds() async {
    if (failSuperLiked) {
      throw Exception('super likes unavailable');
    }
    return Set.of(superLikedRows);
  }
}

class SwipeCall {
  const SwipeCall({
    required this.restaurantId,
    required this.liked,
    required this.source,
    this.superLike = false,
    this.latitude,
    this.longitude,
  });

  final int restaurantId;
  final bool liked;
  final bool superLike;
  final String source;
  final double? latitude;
  final double? longitude;
}

class FakeSwipeRepository implements SwipeRepository {
  final List<SwipeCall> calls = [];

  /// Restaurant ids handed to [undo], in call order.
  final List<int> undoCalls = [];

  bool fail = false;
  bool failUndo = false;

  /// Lets a test act as the backend: e.g. mirror a successful swipe into a
  /// [FakeRestaurantRepository.likedRows] so the follow-up refresh agrees
  /// with the optimistic update, the way the real swipes table would.
  void Function(SwipeCall call)? onRecord;
  void Function(int restaurantId)? onUndo;

  @override
  Future<void> record({
    required int restaurantId,
    required bool liked,
    bool superLike = false,
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
      superLike: superLike,
      source: source,
      latitude: latitude,
      longitude: longitude,
    );
    calls.add(call);
    onRecord?.call(call);
  }

  @override
  Future<void> undo({required int restaurantId}) async {
    if (failUndo) {
      throw Exception('undo refused');
    }
    undoCalls.add(restaurantId);
    onUndo?.call(restaurantId);
  }

  /// Restaurant ids handed to [markVisited], in call order.
  final List<int> markVisitedCalls = [];
  bool failMarkVisited = false;

  @override
  Future<void> markVisited({
    required int restaurantId,
    bool visited = true,
  }) async {
    if (failMarkVisited) {
      throw Exception('mark visited refused');
    }
    markVisitedCalls.add(restaurantId);
  }
}

/// Wires the two fakes together so they behave like one backend: a recorded
/// like inserts the restaurant at the top of [restaurants.likedRows], an
/// unlike or an undo removes it — mirroring `record_swipe` + `undo_swipe` +
/// `get_liked_restaurants`.
void wireFakeBackend(
  FakeRestaurantRepository restaurants,
  FakeSwipeRepository swipes,
) {
  List<Restaurant> without(int restaurantId) => [
        for (final row in restaurants.likedRows)
          if (row.id != restaurantId) row,
      ];

  swipes.onRecord = (call) {
    restaurants.likedRows = call.liked
        ? [testRestaurant(call.restaurantId), ...without(call.restaurantId)]
        : without(call.restaurantId);
  };
  swipes.onUndo = (restaurantId) {
    restaurants.likedRows = without(restaurantId);
  };
}
