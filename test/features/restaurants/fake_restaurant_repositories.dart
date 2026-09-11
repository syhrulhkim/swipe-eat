import 'package:swipe_eat/core/ui/design_tokens.dart';

import 'package:swipe_eat/features/restaurants/data/deck_cache.dart';
import 'package:swipe_eat/features/restaurants/data/restaurant_repository.dart';
import 'package:swipe_eat/features/restaurants/data/swipe_repository.dart';
import 'package:swipe_eat/features/restaurants/data/visit_prompt_cache.dart';
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

  /// Which restaurants are still on the wishlist — what `laterIds` would
  /// return. It reads `wishlist_items` now, not `get_super_liked_ids` (D94),
  /// but the question the fake answers is unchanged.
  Set<int> laterRows = const {};

  /// Reads [laterRows] from somewhere else, so a test can point this at a
  /// wishlist fake and have a Later written through one repository show up in
  /// the other — which is what the real two tables do, both being one
  /// database. See `wireFakeBackend`.
  Set<int> Function()? laterSource;

  bool failDeck = false;
  bool failLiked = false;
  bool failSearch = false;
  bool failFetchById = false;
  bool failLater = false;

  /// The cuisineId of the latest [search] call, null included.
  int? lastSearchCuisineId;

  int likedFetches = 0;

  /// How many times a deck has been asked for, so a test can assert that a
  /// changed profile rule really did re-deal.
  int deckFetches = 0;

  @override
  Future<List<Restaurant>> fetchDeck({
    double? latitude,
    double? longitude,
    int limit = 30,
  }) async {
    deckFetches++;
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

  final Map<int, int> ngapCounts = {};

  @override
  Future<int> ngapCount(int restaurantId) async =>
      ngapCounts[restaurantId] ?? 0;

  @override
  Future<Set<int>> laterIds() async {
    if (failLater) {
      throw Exception('wishlist unavailable');
    }
    return laterSource?.call() ?? Set.of(laterRows);
  }
}

class SwipeCall {
  const SwipeCall({
    required this.restaurantId,
    required this.liked,
    required this.source,
    this.latitude,
    this.longitude,
    this.dwellMs,
    this.unmuted,
  });

  final int restaurantId;
  final bool liked;
  final String source;
  final double? latitude;
  final double? longitude;
  final int? dwellMs;
  final bool? unmuted;
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
    int? dwellMs,
    bool? unmuted,
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
      dwellMs: dwellMs,
      unmuted: unmuted,
    );
    calls.add(call);
    onRecord?.call(call);
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

  /// Every answer handed to [recordVisitAnswer], in call order (D147).
  final List<VisitAnswerCall> visitAnswers = [];

  /// What [nextVisitPrompt] hands back. Null is "no past plan to ask about".
  PendingVisit? planPrompt;

  @override
  Future<void> recordVisitAnswer({
    required int restaurantId,
    required bool went,
    int? rating,
    String? body,
    int? planId,
  }) async {
    if (failMarkVisited) {
      throw Exception('visit answer refused');
    }
    visitAnswers.add(
      VisitAnswerCall(
        restaurantId: restaurantId,
        went: went,
        rating: rating,
        body: body,
        planId: planId,
      ),
    );
  }

  @override
  Future<PendingVisit?> nextVisitPrompt({
    required String userId,
    required DateTime today,
  }) async {
    return planPrompt;
  }
}

/// One call to [FakeSwipeRepository.recordVisitAnswer].
class VisitAnswerCall {
  const VisitAnswerCall({
    required this.restaurantId,
    required this.went,
    this.rating,
    this.body,
    this.planId,
  });

  final int restaurantId;
  final bool went;
  final int? rating;
  final String? body;
  final int? planId;
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
}

/// Stands in for the on-device deck cache. `implements` rather than extends,
/// so an interface change breaks the fake instead of silently diverging from
/// it (D69).
class FakeDeckCache implements DeckCache {
  /// What a read answers with — null is a cache miss.
  CachedDeck? cached;

  final List<List<Restaurant>> saves = [];
  int clears = 0;

  @override
  Future<CachedDeck?> read(String userId) async => cached;

  @override
  Future<void> save({
    required String userId,
    required List<Restaurant> restaurants,
  }) async {
    saves.add(List.of(restaurants));
  }

  @override
  Future<void> clear() async {
    clears += 1;
  }
}
