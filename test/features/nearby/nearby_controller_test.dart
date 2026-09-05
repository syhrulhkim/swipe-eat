import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/location/user_location.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/nearby/data/nearby_repository.dart';
import 'package:swipe_eat/features/nearby/domain/nearby_format.dart';
import 'package:swipe_eat/features/nearby/state/nearby_controller.dart';
import 'package:swipe_eat/features/restaurants/state/deck_handoff.dart';

import '../auth/fake_auth_repository.dart';
import '../profile/fake_profile_repository.dart';
import 'fake_nearby_repository.dart';

AppUser _user({int? searchRadiusKm}) {
  return AppUser(
    id: 'user-1',
    name: 'Aisyah',
    email: 'aisyah@example.com',
    searchRadiusKm: searchRadiusKm,
  );
}

void main() {
  late FakeNearbyRepository repository;
  late FakeAuthRepository auth;
  late AuthController authController;
  late DeckHandoff handoff;

  NearbyController build({int? searchRadiusKm, bool realFix = true}) {
    authController = AuthController(auth);
    authController.applyUser(_user(searchRadiusKm: searchRadiusKm));

    return NearbyController(
      authController: authController,
      repository: repository,
      profiles: FakeProfileRepository(_user(searchRadiusKm: searchRadiusKm)),
      handoff: handoff,
      resolvePosition: () async =>
          realFix ? testPosition() : fallbackUserPosition(),
      now: () => DateTime(2026, 9, 8, 19, 41),
    );
  }

  setUp(() {
    repository = FakeNearbyRepository();
    auth = FakeAuthRepository();
    handoff = DeckHandoff();
  });

  tearDown(() async {
    await auth.dispose();
  });

  group('NearbyController radius', () {
    test('opens at 3 km when the profile has no radius', () async {
      final nearby = build();
      await nearby.load();

      expect(nearby.radiusKm, kNearbyDefaultRadiusKm);
      expect(repository.queries.single.radiusKm, 3);
    });

    test('opens at the profile radius, snapped to a step', () async {
      final nearby = build(searchRadiusKm: 10);
      await nearby.load();

      // 10 ties between 8 and 12; the smaller step wins.
      expect(nearby.radiusKm, 8);
    });

    test('widening walks the steps and refetches with the new radius',
        () async {
      final nearby = build();
      await nearby.load();

      await nearby.widen();
      expect(nearby.radiusKm, 5);
      await nearby.widen();
      expect(nearby.radiusKm, 8);

      expect(
        repository.queries.map((query) => query.radiusKm).toList(),
        [3, 5, 8],
      );
    });

    test('narrowing stops at the smallest step', () async {
      final nearby = build();
      await nearby.load();

      await nearby.narrow(); // 2
      await nearby.narrow(); // 1
      await nearby.narrow(); // 0.5
      expect(nearby.radiusKm, 0.5);
      expect(nearby.canNarrow, isFalse);

      await nearby.narrow();
      expect(nearby.radiusKm, 0.5);
      // The refused tap must not have queried.
      expect(repository.queries.length, 4);
    });

    test('widening stops at the largest step', () async {
      final nearby = build(searchRadiusKm: 20);
      await nearby.load();

      expect(nearby.radiusKm, 20);
      expect(nearby.canWiden, isFalse);
      await nearby.widen();
      expect(repository.queries.length, 1);
    });

    test('the radius is never written to the profile', () async {
      final profiles = FakeProfileRepository(_user());
      authController = AuthController(auth)..applyUser(_user());
      final nearby = NearbyController(
        authController: authController,
        repository: repository,
        profiles: profiles,
        handoff: handoff,
        resolvePosition: () async => testPosition(),
      );

      await nearby.load();
      await nearby.widen();

      expect(profiles.radiusCalls, isEmpty);
    });
  });

  group('NearbyController results', () {
    test('counts only the places the server says are open now', () async {
      repository.rows = [
        testPlace(1, distanceKm: 0.2, openNow: true),
        testPlace(2, distanceKm: 0.4, openNow: false),
        // Unknown hours are not counted: the bar says how many are open, not
        // how many might be.
        testPlace(3, distanceKm: 0.6),
        testPlace(4, distanceKm: 0.8, openNow: true),
      ];

      final nearby = build();
      await nearby.load();

      expect(nearby.places.length, 4);
      expect(nearby.openNowCount, 2);
    });

    test('quotes the cheapest price any result names', () async {
      repository.rows = [
        testPlace(1, distanceKm: 0.2, priceFrom: 28),
        testPlace(2, distanceKm: 0.4),
        testPlace(3, distanceKm: 0.6, priceFrom: 8),
      ];

      final nearby = build();
      await nearby.load();

      expect(nearby.minPriceFrom, 8);
    });

    test('names no price when none of the results does', () async {
      repository.rows = [
        testPlace(1, distanceKm: 0.2),
        testPlace(2, distanceKm: 0.4),
      ];

      final nearby = build();
      await nearby.load();

      expect(nearby.minPriceFrom, isNull);
    });

    test('draws at most the nearest 30 pins of a full result set', () async {
      repository.rows = [
        for (var index = 0; index < 60; index++)
          testPlace(index, distanceKm: index * 0.05),
      ];

      final nearby = build();
      await nearby.load();

      expect(nearby.places.length, 60);
      expect(nearby.pins.length, kNearbyPinLimit);
      expect(nearby.pins.last.id, kNearbyPinLimit - 1);
    });

    test('marks the two closest results prominent, and nothing else',
        () async {
      repository.rows = [
        testPlace(1, distanceKm: 0.2),
        testPlace(2, distanceKm: 0.4),
        testPlace(3, distanceKm: 0.6),
      ];

      final nearby = build();
      await nearby.load();

      expect(nearby.isProminent(nearby.places[0]), isTrue);
      expect(nearby.isProminent(nearby.places[1]), isTrue);
      expect(nearby.isProminent(nearby.places[2]), isFalse);
    });

    test('a failed fetch clears the pins and offers a message', () async {
      repository.fail = true;

      final nearby = build();
      await nearby.load();

      expect(nearby.places, isEmpty);
      expect(nearby.error, isNotNull);
      expect(nearby.needsLocation, isFalse);
    });
  });

  group('NearbyController location', () {
    test('queries around the device fix when there is one', () async {
      final nearby = build();
      await nearby.load();

      expect(nearby.needsLocation, isFalse);
      expect(nearby.origin!.latitude, 1.4655);
      expect(repository.queries.single.latitude, 1.4655);
    });

    test('falls back to the coordinates the profile stored', () async {
      repository.stored = const NearbyOrigin(5.4141, 100.3288);

      final nearby = build(realFix: false);
      await nearby.load();

      expect(nearby.needsLocation, isFalse);
      expect(nearby.origin!.latitude, 5.4141);
      expect(repository.queries.single.longitude, 100.3288);
    });

    test('asks for location when neither the device nor the profile knows',
        () async {
      final nearby = build(realFix: false);
      await nearby.load();

      expect(nearby.needsLocation, isTrue);
      expect(nearby.places, isEmpty);
      // Nothing to measure from is an empty map, not a query around nowhere.
      expect(repository.queries, isEmpty);
    });

    test('a profile read that fails is still "we do not know where you are"',
        () async {
      repository.failStored = true;

      final nearby = build(realFix: false);
      await nearby.load();

      expect(nearby.needsLocation, isTrue);
    });
  });

  group('NearbyController swipe-all', () {
    test('hands every result to the deck, labelled', () async {
      repository.rows = [
        testPlace(1, distanceKm: 0.2),
        testPlace(2, distanceKm: 0.4),
      ];

      final nearby = build();
      await nearby.load();

      var notified = 0;
      handoff.addListener(() => notified += 1);
      nearby.swipeAll();

      expect(notified, 1);
      expect(handoff.restaurants.map((row) => row.id).toList(), [1, 2]);
      expect(handoff.label, 'Nearby · 2 places');
      expect(handoff.revision, 1);
    });

    test('says "place" for one result', () async {
      repository.rows = [testPlace(1, distanceKm: 0.2)];

      final nearby = build();
      await nearby.load();
      nearby.swipeAll();

      expect(handoff.label, 'Nearby · 1 place');
    });

    test('an empty map hands over nothing', () async {
      final nearby = build();
      await nearby.load();
      nearby.swipeAll();

      expect(handoff.revision, 0);
      expect(handoff.restaurants, isEmpty);
    });

    test('a second hand-off of the same places still counts as a change',
        () async {
      repository.rows = [testPlace(1, distanceKm: 0.2)];

      final nearby = build();
      await nearby.load();
      nearby.swipeAll();
      nearby.swipeAll();

      expect(handoff.revision, 2);
    });
  });

  group('NearbyController filters', () {
    test('a changed discovery filter refetches the map', () async {
      final nearby = build();
      await nearby.load();
      expect(repository.queries.length, 1);

      authController.applyUser(
        const AppUser(
          id: 'user-1',
          name: 'Aisyah',
          email: 'aisyah@example.com',
          filterCuisineIds: [3],
        ),
      );
      // The reload is fire-and-forget off the auth notification.
      await Future<void>.delayed(Duration.zero);

      expect(repository.queries.length, 2);
    });

    test('a changed search radius in Settings does not move the map',
        () async {
      final nearby = build();
      await nearby.load();

      authController.applyUser(_user(searchRadiusKm: 12));
      await Future<void>.delayed(Duration.zero);

      expect(nearby.radiusKm, kNearbyDefaultRadiusKm);
      expect(repository.queries.length, 1);
    });
  });
}
