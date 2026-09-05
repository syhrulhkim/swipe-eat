import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
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

  setUp(() {
    handoff = DeckHandoff();
    auth = FakeAuthRepository();
    authController = AuthController(auth);
    restaurants = FakeRestaurantRepository();
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

    test('a disposed deck stops listening to the hand-off', () {
      final deck = buildDeck();
      deck.dispose();

      // Would throw "used after dispose" through notifyListeners if the
      // listener were still attached.
      handoff.handOff([testRestaurant(6)]);
    });
  });
}
