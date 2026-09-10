import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/restaurants/state/deck_controller.dart';

import '../auth/fake_auth_repository.dart';
import '../profile/fake_profile_repository.dart';
import 'fake_restaurant_repositories.dart';

Position _somewhereInKl() => Position(
      latitude: 3.139,
      longitude: 101.6869,
      timestamp: DateTime(2026, 9, 10),
      accuracy: 8,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  group('DeckController.applyDiscoveryFilters', () {
    late AuthController auth;
    late FakeAuthRepository authRepository;
    late FakeProfileRepository profiles;
    late FakeRestaurantRepository restaurants;
    late DeckController deck;
    late int notifications;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      authRepository = FakeAuthRepository()
        ..sessionPresent = true
        ..profile = AppUser(
          id: 'e2f1c0a2-0000-4000-8000-000000000002',
          name: 'Aisyah',
          email: 'aisyah@ngap.test',
          onboardedAt: DateTime(2026, 3, 4),
          searchRadiusKm: 10,
        );
      auth = AuthController(authRepository);
      await auth.bootstrap();

      profiles = FakeProfileRepository(auth.user!);
      restaurants = FakeRestaurantRepository()
        ..deckRows = [testRestaurant(1), testRestaurant(2)];
      final swipes = FakeSwipeRepository();
      wireFakeBackend(restaurants, swipes);

      deck = DeckController(
        authController: auth,
        restaurants: restaurants,
        swipes: swipes,
        profiles: profiles,
        resolvePosition: () async => _somewhereInKl(),
      );
      notifications = 0;
      deck.addListener(() => notifications++);

      addTearDown(() async {
        deck.dispose();
        auth.dispose();
        await authRepository.dispose();
      });
    });

    test('a new radius reaches its own RPC and the profile', () async {
      final saved = await deck.applyDiscoveryFilters(
        cuisineIds: const [1],
        dietaryTagIds: const [],
        searchRadiusKm: 5,
      );

      expect(saved, isTrue);
      expect(profiles.radiusCalls, [5]);
      expect(auth.user?.searchRadiusKm, 5);
      expect(auth.user?.filterCuisineIds, [1]);
    });

    test('an unchanged radius is not written again', () async {
      await deck.applyDiscoveryFilters(
        cuisineIds: const [],
        dietaryTagIds: const [],
        searchRadiusKm: auth.user?.searchRadiusKm,
      );

      expect(profiles.radiusCalls, isEmpty);
    });

    test('applying re-deals the deck, once', () async {
      // The deck the sheet was opened over.
      await deck.load();
      final dealtBefore = restaurants.deckFetches;
      final before = notifications;

      await deck.applyDiscoveryFilters(
        cuisineIds: const [2],
        dietaryTagIds: const [],
        searchRadiusKm: 15,
      );
      // The reload is kicked off by the profile change, not awaited by the
      // write, so let it run.
      await Future<void>.delayed(Duration.zero);

      expect(restaurants.deckFetches, greaterThan(dealtBefore),
          reason: 'the cards on screen were dealt under the old limits');
      expect(notifications, greaterThan(before));
      // Two writes, one profile change: applying the radius on its own would
      // deal a deck under the new radius and the old filters.
      expect(restaurants.deckFetches - dealtBefore, 1);
    });

    test('a failed write says so and leaves the profile alone', () async {
      profiles.fail = true;

      final saved = await deck.applyDiscoveryFilters(
        cuisineIds: const [1],
        dietaryTagIds: const [],
        searchRadiusKm: 5,
      );

      expect(saved, isFalse);
      expect(auth.user?.searchRadiusKm, isNot(5));
    });
  });
}
