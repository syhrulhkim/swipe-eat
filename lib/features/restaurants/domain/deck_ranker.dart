import 'dart:math';

import '../models/restaurant.dart';

/// Ranks the swipe deck the way Tinder ranks its card stack: a scoring model
/// decides which cards come first instead of a fixed catalog order.
///
/// Signals (adapted from how Tinder describes its post-Elo ranking):
/// - proximity: closer restaurants score higher (exponential distance decay);
///   restaurants with an unknown location get a neutral half-credit so a
///   missing geocode never locks them out of the deck front,
/// - freshness: newer content gets a discovery boost, the way new profiles
///   do — ranked by the TikTok video id (which increases with post time)
///   when every card has one, otherwise by row id,
/// - quality: rating contributes when one exists (scraped rows have none),
/// - exploration: per-session random jitter so every session sees a rotated
///   order rather than the same list,
/// - recently swiped cards sink to the back of the deck instead of being
///   re-shown immediately.
class DeckRanker {
  DeckRanker({
    this.proximityWeight = 0.30,
    this.freshnessWeight = 0.20,
    this.ratingWeight = 0.15,
    this.explorationWeight = 0.35,
    this.recentlySeenPenalty = 1.25,
    this.distanceHalfLifeKm = 12,
  });

  final double proximityWeight;
  final double freshnessWeight;
  final double ratingWeight;
  final double explorationWeight;

  /// Subtracted from the score of cards swiped recently. Must stay strictly
  /// larger than the sum of the four weights so a perfect-scoring seen card
  /// still ranks behind the worst unseen card (they keep their relative
  /// order among themselves).
  final double recentlySeenPenalty;

  /// Distance at which the proximity score halves.
  final double distanceHalfLifeKm;

  /// Returns a new list, ranked best-first. [seed] fixes the exploration
  /// jitter: pass a per-session seed so the order is stable within a session
  /// but rotates between sessions. Restaurants at (0, 0) are treated as
  /// "location unknown" and receive a neutral half proximity score.
  List<Restaurant> rank(
    List<Restaurant> restaurants, {
    double? userLatitude,
    double? userLongitude,
    Set<int> recentlySeenIds = const {},
    int? seed,
  }) {
    if (restaurants.isEmpty) {
      return const [];
    }

    final random = Random(seed);
    final freshnessById = _freshnessPercentiles(restaurants);

    final scored = [
      for (final restaurant in restaurants)
        (
          restaurant: restaurant,
          score: _score(
            restaurant,
            userLatitude: userLatitude,
            userLongitude: userLongitude,
            recentlySeenIds: recentlySeenIds,
            freshness: freshnessById[restaurant.id] ?? 0.5,
            jitter: random.nextDouble(),
          ),
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));

    return [for (final entry in scored) entry.restaurant];
  }

  /// Rank-based freshness percentile (0 = oldest, 1 = newest) per restaurant
  /// id. Content recency comes from the TikTok video id embedded in the video
  /// URL — TikTok ids increase with post time — so a bulk backfill inserted in
  /// any row order still ranks the newest video highest. Falls back to row id
  /// order when any card lacks a parseable video id, so decks without videos
  /// keep newer rows first. Rank (not value) spacing makes the signal immune
  /// to id gaps.
  static Map<int, double> _freshnessPercentiles(List<Restaurant> restaurants) {
    final keys = <int, int>{
      for (final restaurant in restaurants)
        restaurant.id: _tiktokVideoId(restaurant.videoUrl) ?? -1,
    };
    final useRowIds = keys.values.any((key) => key < 0);

    final ordered = restaurants.map((r) => r.id).toList()
      ..sort(
          (a, b) => useRowIds ? a.compareTo(b) : keys[a]!.compareTo(keys[b]!));
    final span = max(1, ordered.length - 1);
    return {
      for (var i = 0; i < ordered.length; i++) ordered[i]: i / span,
    };
  }

  /// TikTok video URLs end in the numeric video id, which is snowflake-like:
  /// higher id = posted later.
  static int? _tiktokVideoId(String? videoUrl) {
    if (videoUrl == null) {
      return null;
    }
    final match = RegExp(r'(\d{6,})\s*$').firstMatch(videoUrl.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  double _score(
    Restaurant restaurant, {
    required double? userLatitude,
    required double? userLongitude,
    required Set<int> recentlySeenIds,
    required double freshness,
    required double jitter,
  }) {
    var score = explorationWeight * jitter;

    final hasRestaurantLocation =
        restaurant.latitude != 0 || restaurant.longitude != 0;
    if (userLatitude != null && userLongitude != null) {
      if (hasRestaurantLocation) {
        final km = _haversineKm(
          userLatitude,
          userLongitude,
          restaurant.latitude,
          restaurant.longitude,
        );
        // exp2(-km/halfLife): 1.0 at 0 km, 0.5 at the half-life, ~0 far away.
        score += proximityWeight * pow(2, -km / distanceHalfLifeKm);
      } else {
        // Location unknown: neutral half-credit, so an ungeocoded restaurant
        // competes like one sitting at the half-life distance instead of
        // being pushed permanently behind every geocoded card.
        score += proximityWeight * 0.5;
      }
    }

    score += freshnessWeight * freshness;
    score += ratingWeight * (restaurant.rating.clamp(0, 5) / 5);

    if (recentlySeenIds.contains(restaurant.id)) {
      score -= recentlySeenPenalty;
    }

    return score;
  }

  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _radians(lat2 - lat1);
    final dLng = _radians(lng2 - lng1);
    // Clamped: floating point can nudge `a` past 1 for near-antipodal points,
    // which would make asin return NaN and float the card to the deck front.
    final a = (pow(sin(dLat / 2), 2) +
            cos(_radians(lat1)) * cos(_radians(lat2)) * pow(sin(dLng / 2), 2))
        .toDouble()
        .clamp(0.0, 1.0);
    return 2 * earthRadiusKm * asin(sqrt(a));
  }

  static double _radians(double degrees) => degrees * pi / 180;
}
