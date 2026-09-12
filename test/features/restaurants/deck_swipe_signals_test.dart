import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/restaurants/state/deck_controller.dart';
import 'package:swipe_eat/features/restaurants/state/likes_controller.dart';

import '../auth/fake_auth_repository.dart';
import 'fake_restaurant_repositories.dart';

/// D149: every deck swipe carries how long the card sat on top and whether
/// its clip had sound on. Nothing reads them yet, so the only thing standing
/// between a wiring mistake and a column of nulls forever is this test.
void main() {
  group('the two implicit signals', () {
    late AuthController auth;
    late FakeAuthRepository authRepository;
    late FakeRestaurantRepository restaurants;
    late FakeSwipeRepository swipes;
    late DeckController deck;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      authRepository = FakeAuthRepository()
        ..sessionPresent = true
        ..profile = AppUser(
          id: 'e2f1c0a2-0000-4000-8000-000000000003',
          name: 'Aisyah',
          email: 'aisyah@ngap.test',
          onboardedAt: DateTime(2026, 3, 4),
        );
      auth = AuthController(authRepository);
      await auth.bootstrap();

      restaurants = FakeRestaurantRepository()
        ..deckRows = [testRestaurant(1), testRestaurant(2)];
      swipes = FakeSwipeRepository();
      wireFakeBackend(restaurants, swipes);

      deck = DeckController(
        authController: auth,
        restaurants: restaurants,
        swipes: swipes,
        likes: LikesController(followAuthChanges: false),
      );
      await deck.load();

      addTearDown(() async {
        deck.dispose();
        auth.dispose();
        await authRepository.dispose();
      });
    });

    test('a pass carries a dwell, and no sound state without a player',
        () async {
      await deck.recordSwipe(deck.current!, liked: false);

      final call = swipes.calls.single;
      expect(call.dwellMs, isNotNull);
      expect(call.dwellMs, greaterThanOrEqualTo(0));
      expect(call.dwellMs, lessThanOrEqualTo(10 * 60 * 1000));
      // No warmed player for this card, which is not the same as muted.
      expect(call.unmuted, isNull);
    });

    test('the dwell clock restarts on the next card', () async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await deck.recordSwipe(deck.current!, liked: false);
      deck.advance();
      await deck.recordSwipe(deck.current!, liked: false);

      expect(swipes.calls.first.dwellMs, greaterThanOrEqualTo(250));
      // The second card's clock started when it became the top card, so its
      // dwell cannot include the quarter second the first one was watched.
      expect(swipes.calls.last.dwellMs, lessThan(250));
    });
  });
}
