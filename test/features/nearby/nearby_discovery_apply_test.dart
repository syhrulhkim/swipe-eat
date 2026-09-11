
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/nearby/domain/nearby_format.dart';
import 'package:swipe_eat/features/nearby/state/nearby_controller.dart';
import 'package:swipe_eat/features/restaurants/state/deck_handoff.dart';

import '../auth/fake_auth_repository.dart';
import '../profile/fake_profile_repository.dart';
import 'fake_nearby_repository.dart';

void main() {
  group('NearbyController.applyDiscoveryFilters', () {
    late FakeNearbyRepository repository;
    late FakeProfileRepository profiles;
    late FakeAuthRepository auth;
    late AuthController authController;
    late NearbyController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      repository = FakeNearbyRepository()
        ..rows = [testPlace(1, distanceKm: 1.2)];
      auth = FakeAuthRepository();
      authController = AuthController(auth);
      const user = AppUser(
        id: 'user-1',
        name: 'Aisyah',
        email: 'aisyah@example.com',
        searchRadiusKm: 10,
      );
      authController.applyUser(user);
      profiles = FakeProfileRepository(user);

      controller = NearbyController(
        authController: authController,
        repository: repository,
        profiles: profiles,
        handoff: DeckHandoff(),
        resolvePosition: () async => testPosition(),
        now: () => DateTime(2026, 9, 8, 19, 41),
      );

      addTearDown(() async {
        controller.dispose();
        authController.dispose();
        await auth.dispose();
      });
    });

    test('a sheet with a new radius refetches the map once', () async {
      await controller.load();
      final before = repository.queries.length;

      final saved = await controller.applyDiscoveryFilters(
        cuisineIds: const [2],
        dietaryTagIds: const [],
        searchRadiusKm: 15,
      );
      // The refetch is kicked off by the profile change, not awaited by the
      // write, so let it run.
      await Future<void>.delayed(Duration.zero);

      expect(saved, isTrue);
      expect(profiles.radiusCalls, [15]);
      // Two writes, one profile change: applying the radius on its own would
      // draw a map under the new circle and the old filters, thrown away a
      // moment later.
      expect(repository.queries.length - before, 1);
      // The map draws the nearest step to the radius the sheet wrote, not
      // the one it opened with.
      expect(repository.queries.last.radiusKm, nearestNearbyRadiusStep(15));
    });

    test('a failed write leaves the profile alone', () async {
      await controller.load();
      profiles.fail = true;

      final saved = await controller.applyDiscoveryFilters(
        cuisineIds: const [2],
        dietaryTagIds: const [],
        searchRadiusKm: 15,
      );

      expect(saved, isFalse);
      expect(authController.user?.searchRadiusKm, 10);
    });
  });
}
