
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/restaurants/domain/deck_ranker.dart';
import 'package:swipe_eat/features/restaurants/models/restaurant.dart';

Restaurant _restaurant(
  int id, {
  double latitude = 0,
  double longitude = 0,
  double rating = 0,
  String? videoUrl,
}) {
  return Restaurant(
    id: id,
    name: 'Restaurant $id',
    tag: 'Tag',
    details: '',
    brandColor: kBrandColorFallback,
    rating: rating,
    latitude: latitude,
    longitude: longitude,
    imageUrls: const [],
    reviews: const [],
    videoUrl: videoUrl,
  );
}

List<int> _ids(List<Restaurant> restaurants) =>
    restaurants.map((r) => r.id).toList();

void main() {
  group('DeckRanker', () {
    test('returns an empty list for an empty deck', () {
      expect(DeckRanker().rank([]), isEmpty);
    });

    test('is deterministic for the same seed', () {
      final deck = [for (var i = 1; i <= 20; i++) _restaurant(i)];
      final ranker = DeckRanker();

      final a = ranker.rank(deck, seed: 42);
      final b = ranker.rank(deck, seed: 42);

      expect(_ids(a), _ids(b));
    });

    test('rotates the order between sessions (different seeds)', () {
      final deck = [for (var i = 1; i <= 20; i++) _restaurant(i)];
      final ranker = DeckRanker();

      final baseline = _ids(ranker.rank(deck, seed: 1));
      final anyDifferent = [for (var seed = 2; seed <= 6; seed++) seed].any(
          (seed) =>
              _ids(ranker.rank(deck, seed: seed)).toString() !=
              baseline.toString());

      expect(anyDifferent, isTrue,
          reason: 'five reshuffles of 20 cards should not all match');
    });

    test('recently seen restaurants sink to the back of the deck', () {
      final deck = [for (var i = 1; i <= 10; i++) _restaurant(i)];
      final ranked = DeckRanker().rank(
        deck,
        recentlySeenIds: {3, 7},
        seed: 7,
      );

      expect(_ids(ranked).sublist(8), unorderedEquals([3, 7]));
    });

    test('closer restaurants rank first when exploration is off', () {
      // User in central Johor Bahru.
      const userLat = 1.4655;
      const userLng = 103.7578;
      final near = _restaurant(1, latitude: 1.4667, longitude: 103.7525);
      final far = _restaurant(2, latitude: 1.8522, longitude: 102.9254);

      final ranked = DeckRanker(explorationWeight: 0, freshnessWeight: 0)
          .rank([far, near], userLatitude: userLat, userLongitude: userLng);

      expect(_ids(ranked), [1, 2]);
    });

    test('restaurants at (0,0) get neutral proximity: behind nearby cards', () {
      const userLat = 1.4655;
      const userLng = 103.7578;
      final located = _restaurant(1, latitude: 1.4667, longitude: 103.7525);
      final unknown = _restaurant(2); // 0,0 = location unknown

      final ranked = DeckRanker(explorationWeight: 0, freshnessWeight: 0).rank(
          [unknown, located],
          userLatitude: userLat, userLongitude: userLng);

      expect(_ids(ranked), [1, 2]);
    });

    test('restaurants at (0,0) get neutral proximity: ahead of distant cards',
        () {
      const userLat = 1.4655;
      const userLng = 103.7578;
      // ~330 km away: proximity decays to ~0, well below the 0.5 half-credit.
      final distant = _restaurant(1, latitude: 4.2105, longitude: 101.9758);
      final unknown = _restaurant(2); // 0,0 = location unknown

      final ranked = DeckRanker(explorationWeight: 0, freshnessWeight: 0).rank(
          [distant, unknown],
          userLatitude: userLat, userLongitude: userLng);

      expect(_ids(ranked), [2, 1],
          reason: 'a missing geocode must not lock a card out of the deck');
    });

    test('newer restaurants outrank older ones when other signals tie', () {
      final deck = [_restaurant(1), _restaurant(100)];
      final ranked =
          DeckRanker(explorationWeight: 0, ratingWeight: 0).rank(deck);

      expect(_ids(ranked), [100, 1]);
    });

    test('freshness follows TikTok video recency, not row id', () {
      // Backfill scenario: the newest video was inserted first (lowest row
      // id), so id order and content recency are opposed.
      final newestContent = _restaurant(1,
          videoUrl:
              'https://www.tiktok.com/@johorfoodie/video/7670000000000000000');
      final oldestContent = _restaurant(100,
          videoUrl:
              'https://www.tiktok.com/@johorfoodie/video/7470000000000000000');

      final ranked = DeckRanker(explorationWeight: 0, ratingWeight: 0)
          .rank([oldestContent, newestContent]);

      expect(_ids(ranked), [1, 100],
          reason: 'the newer video should get the discovery boost');
    });

    test('freshness falls back to row ids when any video id is unparseable',
        () {
      final withVideo = _restaurant(1,
          videoUrl:
              'https://www.tiktok.com/@johorfoodie/video/7670000000000000000');
      final withoutVideo = _restaurant(100);

      final ranked = DeckRanker(explorationWeight: 0, ratingWeight: 0)
          .rank([withVideo, withoutVideo]);

      expect(_ids(ranked), [100, 1],
          reason: 'mixed decks rank by row id so the key space stays uniform');
    });

    test('rating contributes when present', () {
      final unrated = _restaurant(1);
      final rated = _restaurant(1, rating: 4.5);
      final ranker = DeckRanker(explorationWeight: 0, freshnessWeight: 0);

      final unratedFirst = ranker.rank([rated, unrated]);
      expect(unratedFirst.first.rating, 4.5);
    });

    test('a single-restaurant deck ranks without dividing by zero', () {
      // min id == max id, so the freshness denominator would be 0 unless the
      // span is floored at 1.
      final ranked = DeckRanker().rank([_restaurant(42)], seed: 3);

      expect(_ids(ranked), [42]);
    });

    test('a deck of identical ids keeps every card', () {
      final deck = [for (var i = 0; i < 5; i++) _restaurant(7)];
      final ranked = DeckRanker().rank(deck, seed: 3);

      expect(ranked, hasLength(5));
      expect(_ids(ranked), everyElement(7));
    });

    test('a deck where every card was recently seen keeps them all', () {
      final deck = [for (var i = 1; i <= 6; i++) _restaurant(i)];
      final ranked = DeckRanker().rank(
        deck,
        recentlySeenIds: {1, 2, 3, 4, 5, 6},
        seed: 11,
      );

      expect(_ids(ranked), unorderedEquals([1, 2, 3, 4, 5, 6]));
    });

    test('recentlySeenIds referring to absent restaurants is harmless', () {
      final deck = [for (var i = 1; i <= 4; i++) _restaurant(i)];
      final ranked = DeckRanker().rank(
        deck,
        recentlySeenIds: {900, 901},
        seed: 5,
      );

      expect(_ids(ranked), unorderedEquals([1, 2, 3, 4]));
    });

    test('no unseen card ever ranks behind a seen card, across many seeds', () {
      final deck = [
        for (var i = 1; i <= 12; i++)
          _restaurant(i, latitude: 1.46 + i / 100, longitude: 103.75, rating: 5)
      ];
      final seen = {2, 5, 9};

      for (var seed = 0; seed < 50; seed++) {
        final ranked = _ids(DeckRanker().rank(
          deck,
          userLatitude: 1.4655,
          userLongitude: 103.7578,
          recentlySeenIds: seen,
          seed: seed,
        ));
        final lastUnseen = ranked.lastIndexWhere((id) => !seen.contains(id));
        final firstSeen = ranked.indexWhere(seen.contains);

        expect(firstSeen, greaterThan(lastUnseen),
            reason: 'seed $seed produced $ranked');
      }
    });

    test('a null user position skips proximity without crashing', () {
      final near = _restaurant(1, latitude: 1.4667, longitude: 103.7525);
      final far = _restaurant(2, latitude: 1.8522, longitude: 102.9254);
      final ranker = DeckRanker(explorationWeight: 0, freshnessWeight: 0);

      // Only one coordinate supplied is also "no position".
      for (final ranked in [
        ranker.rank([near, far]),
        ranker.rank([near, far], userLatitude: 1.4655),
        ranker.rank([near, far], userLongitude: 103.7578),
      ]) {
        expect(_ids(ranked), unorderedEquals([1, 2]));
      }
    });

    test('negative and absurd ratings are clamped into the 0..5 band', () {
      final ranker = DeckRanker(explorationWeight: 0, freshnessWeight: 0);

      // -10 must score no better than 0, and 1000 no better than 5.
      final withNegative = ranker.rank([
        _restaurant(1, rating: -10),
        _restaurant(2, rating: 0.1),
      ]);
      expect(_ids(withNegative), [2, 1]);

      final withHuge = ranker.rank([
        _restaurant(1, rating: 4.9),
        _restaurant(2, rating: 1000),
      ]);
      expect(_ids(withHuge), [2, 1]);

      // Clamping means 1000 and 5 tie rather than 1000 running away.
      final tied = ranker.rank([
        _restaurant(1, rating: 5),
        _restaurant(2, rating: 1e9),
      ]);
      expect(_ids(tied), unorderedEquals([1, 2]));
    });

    test('antipodal coordinates still produce a finite ranking', () {
      // The haversine `asin(sqrt(a))` is where a naive implementation can
      // yield NaN (a drifts just above 1.0), and NaN sorts ahead of every
      // real score in Dart.
      final ranker = DeckRanker(explorationWeight: 0, freshnessWeight: 0);
      final antipode = _restaurant(1, latitude: -1.4655, longitude: -76.2422);
      final next = _restaurant(2, latitude: 1.4667, longitude: 103.7525);

      final ranked = ranker.rank(
        [antipode, next],
        userLatitude: 1.4655,
        userLongitude: 103.7578,
      );

      expect(_ids(ranked), [2, 1]);
    });

    test('out-of-range coordinates do not crash the ranker', () {
      final ranker = DeckRanker(explorationWeight: 0);
      final ranked = ranker.rank(
        [_restaurant(1, latitude: 500, longitude: 900), _restaurant(2)],
        userLatitude: -400,
        userLongitude: 1000,
      );

      expect(_ids(ranked), unorderedEquals([1, 2]));
    });

    test('rank does not mutate or alias the input list', () {
      final deck = [for (var i = 1; i <= 6; i++) _restaurant(i)];
      final original = _ids(deck);

      final ranked = DeckRanker().rank(deck, seed: 9);

      expect(_ids(deck), original);
      expect(ranked, isNot(same(deck)));
    });

    test('a zero half-life leaves proximity finite', () {
      // pow(2, -km/0) is -infinity in the exponent for any km > 0, which must
      // not surface as NaN for a restaurant sitting exactly on the user.
      final ranker = DeckRanker(explorationWeight: 0, distanceHalfLifeKm: 0);
      final onTop = _restaurant(1, latitude: 1.4655, longitude: 103.7578);
      final away = _restaurant(2, latitude: 1.8522, longitude: 102.9254);

      final ranked = ranker.rank(
        [away, onTop],
        userLatitude: 1.4655,
        userLongitude: 103.7578,
      );

      expect(_ids(ranked), unorderedEquals([1, 2]));
    });
  });
}
