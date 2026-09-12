import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swipe_eat/features/nearby/data/nearby_repository.dart';

import '../../support/fake_supabase_http.dart';

void main() {
  group('NearbyRepository', () {
    test('constructs from an injected client without initialising Supabase',
        () {
      final client = SupabaseClient(
        'https://stub.supabase.co',
        'stub-anon-key',
      );
      addTearDown(client.dispose);

      expect(() => NearbyRepository(client: client), returnsNormally);
    });

    test('construction is free; only the request needs the singleton', () {
      final repository = NearbyRepository();

      expect(
        repository.fetchNearby(latitude: 3.1, longitude: 101.6, radiusKm: 5),
        throwsA(isA<Error>()),
      );
    });
  });

  group('NearbyRepository over the wire', () {
    late FakeSupabaseHttp fake;
    late SupabaseClient client;
    late NearbyRepository repository;

    setUp(() {
      fake = FakeSupabaseHttp();
      client = fakeSupabaseClient(fake);
      addTearDown(client.dispose);
      repository = NearbyRepository(client: client);
    });

    test('get_nearby carries the origin, the radius and the cap', () async {
      fake.on('POST', '/rest/v1/rpc/get_nearby', [
        {
          'id': 7,
          'name': 'Nasi Kandar Pelita',
          'rating': 4.4,
          'latitude': 3.15,
          'longitude': 101.71,
          'restaurant_images': [
            {'url': 'https://img.test/7.jpg', 'position': 0},
          ],
          'distance_km': 1.2,
          'open_now': true,
          'swiped': true,
        },
      ]);

      final places = await repository.fetchNearby(
        latitude: 3.1,
        longitude: 101.6,
        radiusKm: 5,
        limit: 40,
      );

      expect(fake.single.path, '/rest/v1/rpc/get_nearby');
      expect(fake.single.json, {
        'p_latitude': 3.1,
        'p_longitude': 101.6,
        'p_radius_km': 5.0,
        'p_limit': 40,
      });

      final place = places.single;
      expect(place.id, 7);
      expect(place.restaurant.name, 'Nasi Kandar Pelita');
      expect(place.distanceKm, 1.2);
      expect(place.openNow, isTrue);
      expect(place.swiped, isTrue);
      expect(place.coverUrl, 'https://img.test/7.jpg');
    });

    test('a refused read surfaces as a PostgrestException', () async {
      fake.onError(
        'POST',
        '/rest/v1/rpc/get_nearby',
        status: 403,
        code: '42501',
        message: 'permission denied for function get_nearby',
      );

      await expectLater(
        repository.fetchNearby(latitude: 3.1, longitude: 101.6, radiusKm: 5),
        throwsA(
          isA<PostgrestException>()
              .having((error) => error.code, 'code', '42501'),
        ),
      );
      // 403 is not in PostgREST's retry set, so it goes out exactly once.
      expect(fake.calls, hasLength(1));
    });
  });
}
