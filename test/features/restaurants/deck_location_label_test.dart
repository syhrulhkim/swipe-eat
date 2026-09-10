import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_eat/core/location/user_location.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/restaurants/state/deck_controller.dart';

import '../auth/fake_auth_repository.dart';
import '../profile/fake_profile_repository.dart';
import 'fake_restaurant_repositories.dart';

Position _kulai() => Position(
      latitude: 1.6419,
      longitude: 103.6196,
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
  group('DeckController.locationLabel', () {
    late AuthController auth;
    late FakeAuthRepository authRepository;
    late FakeProfileRepository profiles;
    late FakeRestaurantRepository restaurants;

    Future<DeckController> build({
      required Future<String?> Function(Position) resolvePlace,
      Future<Position> Function()? resolvePosition,
    }) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      authRepository = FakeAuthRepository()
        ..sessionPresent = true
        ..profile = const AppUser(
          id: 'e2f1c0a2-0000-4000-8000-000000000003',
          name: 'Aisyah',
          email: 'aisyah@ngap.test',
          // Where they were the last time a geocode succeeded.
          lastPlaceName: 'Kulai',
          lastLatitude: 1.6419,
          lastLongitude: 103.6196,
        );
      auth = AuthController(authRepository);
      await auth.bootstrap();

      profiles = FakeProfileRepository(auth.user!);
      restaurants = FakeRestaurantRepository()..deckRows = [testRestaurant(1)];
      final swipes = FakeSwipeRepository();
      wireFakeBackend(restaurants, swipes);

      return DeckController(
        authController: auth,
        restaurants: restaurants,
        swipes: swipes,
        profiles: profiles,
        resolvePosition: resolvePosition ?? () async => _kulai(),
        resolvePlace: resolvePlace,
      );
    }

    tearDown(() async {
      await authRepository.dispose();
    });

    test('a fix that geocodes names where the user is', () async {
      final deck = await build(
        resolvePlace: (_) async => 'Bukit Bintang, Kuala Lumpur',
      );
      await deck.load();
      await pumpEventQueue();

      expect(deck.locationLabel, 'Bukit Bintang, Kuala Lumpur');
      deck.dispose();
    });

    test('a fix whose geocode fails drops the old name rather than wearing it',
        () async {
      final deck = await build(resolvePlace: (_) async => null);
      await deck.load();
      await pumpEventQueue();

      // The coordinates just moved. Keeping 'Kulai' would put a town the user
      // has left on the header, next to a deck dealt around somewhere else.
      expect(profiles.locationCalls.single.placeName, isNull);
      expect(deck.locationLabel, 'Nearby');
      deck.dispose();
    });

    test('a card is measured from the point the deck was dealt around',
        () async {
      // No device fix, so `deck_scored` ranks and applies the radius around
      // the profile's stored coordinates. The label has to use the same ones,
      // or a card the server picked as "within 15 km" wears a 90 km sticker.
      final deck = await build(
        resolvePlace: (_) async => fail('a fallback must not be geocoded'),
        resolvePosition: () async => fallbackUserPosition(),
      );
      await deck.load();
      await pumpEventQueue();

      // The seeded restaurant sits on the fallback coordinate itself, so the
      // old behaviour answered "0.0 km" for a place ~80 km from the stored
      // fix the deck was actually dealt around.
      final card = deck.cards.single;
      expect(deck.distanceLabelFor(card), isNot('0.0 km'));
      expect(deck.distanceLabelFor(card), '80.2 km');
      deck.dispose();
    });

    test('no real fix keeps the stored name out of the header', () async {
      final deck = await build(
        resolvePlace: (_) async => fail('a fallback must not be geocoded'),
        resolvePosition: () async => fallbackUserPosition(),
      );
      await deck.load();
      await pumpEventQueue();

      // Nothing was learned about where the user is, so nothing already known
      // is thrown away — but nothing is claimed either. 'Kulai' here is the
      // town of the last fix that worked, which can be days old, and printing
      // it plain would read as "you are in Kulai".
      expect(profiles.locationCalls, isEmpty);
      expect(auth.user?.lastPlaceName, 'Kulai');
      expect(deck.locationLabel, 'Location off');
      deck.dispose();
    });

    test('a fix granted after launch is picked up on the next resume',
        () async {
      // What the user actually does: launches with location off, sees
      // 'Location off', turns it on in Settings, comes back.
      var granted = false;
      final deck = await build(
        resolvePlace: (_) async => 'Johor Bahru',
        resolvePosition: () async =>
            granted ? _kulai() : fallbackUserPosition(),
      );
      await deck.load();
      await pumpEventQueue();
      expect(deck.locationLabel, 'Location off');

      granted = true;
      await deck.refreshLocation();
      await pumpEventQueue();

      expect(deck.locationLabel, 'Johor Bahru');
      deck.dispose();
    });

    test('a resume with a fix already in hand does not re-deal', () async {
      final deck = await build(resolvePlace: (_) async => 'Johor Bahru');
      await deck.load();
      await pumpEventQueue();
      final dealt = restaurants.deckFetches;

      // Losing the user's place in the stack on every app switch would be a
      // worse bug than the one refreshLocation exists to fix.
      await deck.refreshLocation();
      await pumpEventQueue();

      expect(restaurants.deckFetches, dealt);
      deck.dispose();
    });
  });
}
