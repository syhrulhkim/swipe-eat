import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/restaurants/data/deck_cache.dart';
import 'package:swipe_eat/features/restaurants/state/deck_controller.dart';
import 'package:swipe_eat/features/restaurants/state/deck_handoff.dart';
import 'package:swipe_eat/features/restaurants/state/likes_controller.dart';

import '../auth/fake_auth_repository.dart';
import 'fake_restaurant_repositories.dart';

void main() {
  late DeckHandoff handoff;
  late FakeAuthRepository auth;
  late AuthController authController;
  late FakeRestaurantRepository restaurants;
  late FakeDeckCache cache;

  setUp(() {
    handoff = DeckHandoff();
    auth = FakeAuthRepository();
    authController = AuthController(auth);
    restaurants = FakeRestaurantRepository();
    cache = FakeDeckCache();
  });

  tearDown(() async {
    await auth.dispose();
  });

  DeckController buildDeck() {
    return DeckController(
      authController: authController,
      restaurants: restaurants,
      swipes: FakeSwipeRepository(),
      likes: LikesController(followAuthChanges: false),
      cache: cache,
      handoff: handoff,
    );
  }

  group('DeckHandoff', () {
    test('starts empty and unversioned', () {
      expect(handoff.restaurants, isEmpty);
      expect(handoff.label, isNull);
      expect(handoff.revision, 0);
    });

    test('an empty hand-off is not a hand-off', () {
      var notified = 0;
      handoff.addListener(() => notified += 1);

      handoff.handOff(const []);

      expect(notified, 0);
      expect(handoff.revision, 0);
    });

    test('every hand-off bumps the revision, even for the same list', () {
      final rows = [testRestaurant(1), testRestaurant(2)];

      handoff.handOff(rows, label: 'Nearby · 2 places');
      handoff.handOff(rows, label: 'Nearby · 2 places');

      expect(handoff.revision, 2);
      expect(handoff.label, 'Nearby · 2 places');
    });

    test('the handed-over list cannot be mutated by its receiver', () {
      handoff.handOff([testRestaurant(1)]);

      expect(
        () => handoff.restaurants.add(testRestaurant(2)),
        throwsUnsupportedError,
      );
    });
  });

  group('DeckController.dealFrom', () {
    test('replaces the deck with the handed-over list', () {
      final deck = buildDeck();
      addTearDown(deck.dispose);

      deck.dealFrom(
        [testRestaurant(7, name: 'Warung Kak Ros'), testRestaurant(8)],
        label: 'Nearby · 2 places',
      );

      expect(deck.cards.map((card) => card.id).toList(), [7, 8]);
      expect(deck.current!.title, 'Warung Kak Ros');
      expect(deck.index, 0);
      expect(deck.loading, isFalse);
      expect(deck.error, isNull);
      // Server rows, not a saved deck: the offline chip must not appear.
      expect(deck.isStale, isFalse);
      expect(deck.stalenessLabel, isNull);
      expect(deck.handoffLabel, 'Nearby · 2 places');
    });

    test('an empty list leaves the deck alone', () {
      final deck = buildDeck();
      addTearDown(deck.dispose);

      deck.dealFrom([testRestaurant(1)]);
      deck.dealFrom(const []);

      expect(deck.cards.length, 1);
    });

    test('restarts the deck from the top even mid-swipe', () {
      final deck = buildDeck();
      addTearDown(deck.dispose);

      deck.dealFrom([testRestaurant(1), testRestaurant(2)]);
      deck.advance();
      expect(deck.index, 1);

      deck.dealFrom([testRestaurant(3)]);
      expect(deck.index, 0);
      expect(deck.current!.id, 3);
    });

    test('a load still in flight cannot land on top of a hand-off', () async {
      final deck = buildDeck();
      addTearDown(deck.dispose);
      restaurants.deckRows = [testRestaurant(99)];

      final loading = deck.load();
      deck.dealFrom([testRestaurant(1), testRestaurant(2)]);
      await loading;

      expect(deck.cards.map((card) => card.id).toList(), [1, 2]);
    });

    test('the deck deals whatever the hand-off publishes', () {
      final deck = buildDeck();
      addTearDown(deck.dispose);

      handoff.handOff(
        [testRestaurant(4), testRestaurant(5)],
        label: 'Nearby · 2 places',
      );

      expect(deck.cards.map((card) => card.id).toList(), [4, 5]);
      expect(deck.handoffLabel, 'Nearby · 2 places');
    });

    test('the offline fallback drops the hand-off label with the cards',
        () async {
      final deck = buildDeck();
      addTearDown(deck.dispose);

      deck.dealFrom([testRestaurant(1)], label: 'Nearby · 1 place');
      expect(deck.handoffLabel, 'Nearby · 1 place');

      // The server is unreachable, so the deck falls back to the saved one.
      restaurants.failDeck = true;
      cache.cached = CachedDeck(
        restaurants: [testRestaurant(2), testRestaurant(3)],
        savedAt: DateTime(2026, 9, 4, 12),
      );
      await deck.load();

      expect(deck.cards.map((card) => card.id).toList(), [2, 3]);
      expect(deck.isStale, isTrue);
      // These cards came off the device days ago, not off the map a moment
      // ago: crediting them to "Nearby · 1 place" would be a lie.
      expect(deck.handoffLabel, isNull);
    });

    test('a disposed deck stops listening to the hand-off', () {
      final deck = buildDeck();
      deck.dispose();

      // Would throw "used after dispose" through notifyListeners if the
      // listener were still attached.
      handoff.handOff([testRestaurant(6)]);
    });
  });

  group('DeckController re-deals when a hard rule changes', () {
    test('each of the three diet and budget answers re-deals the deck',
        () async {
      const user = AppUser(id: 'u1', name: 'Aisyah', email: 'a@example.com');
      authController.applyUser(user);
      final deck = buildDeck();
      addTearDown(deck.dispose);
      await deck.load();
      expect(restaurants.deckFetches, 1);

      // The reload is fire-and-forget off the auth notification.
      Future<void> settle() => Future<void>.delayed(Duration.zero);

      // Each is a hard rule in `deck_scored` (D105): flipping one changes
      // which places may be dealt at all, so stale cards would break its
      // promise.
      authController.applyUser(user.copyWith(halalOnly: true));
      await settle();
      expect(restaurants.deckFetches, 2);

      authController.applyUser(
        user.copyWith(halalOnly: true, vegetarian: true),
      );
      await settle();
      expect(restaurants.deckFetches, 3);

      authController.applyUser(
        user.copyWith(halalOnly: true, vegetarian: true, budgetMax: 30),
      );
      await settle();
      expect(restaurants.deckFetches, 4);
    });
  });
}
