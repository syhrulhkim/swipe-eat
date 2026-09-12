import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swipe_eat/features/profile/data/profile_repository.dart';

import '../../support/fake_supabase_http.dart';

void main() {
  group('ProfileRepository', () {
    test('constructs from an injected client without initialising Supabase',
        () {
      final client = SupabaseClient(
        'https://stub.supabase.co',
        'stub-anon-key',
      );
      addTearDown(client.dispose);

      expect(() => ProfileRepository(client: client), returnsNormally);
    });

    test('construction is free; only the request needs the singleton', () {
      final repository = ProfileRepository();

      expect(
        repository.updateLocation(latitude: 3.1, longitude: 101.6),
        throwsA(isA<Error>()),
      );
      expect(repository.updateSearchRadius(10), throwsA(isA<Error>()));
      expect(repository.updatePreferences(halalOnly: true),
          throwsA(isA<Error>()));
      expect(
        repository.setDiscoveryFilters(cuisineIds: const [], dietaryTagIds: const []),
        throwsA(isA<Error>()),
      );
    });
  });

  group('ProfileRepository over the wire', () {
    late FakeSupabaseHttp fake;
    late SupabaseClient client;
    late ProfileRepository repository;

    setUp(() async {
      fake = FakeSupabaseHttp();
      client = fakeSupabaseClient(fake);
      addTearDown(client.dispose);
      await seedSession(client, userId: 'user-1', email: 'aisyah@test.my');
      repository = ProfileRepository(client: client);
    });

    /// Every one of these RPCs answers with the whole updated `profiles` row.
    void answers(String function, [Map<String, dynamic>? row]) {
      fake.on('POST', '/rest/v1/rpc/$function', row ?? {'id': 'user-1'});
    }

    test('a fix with no name still sends the name, so the header cannot lie',
        () async {
      answers('update_location', {
        'id': 'user-1',
        'last_place_name': null,
        'last_latitude': 3.1,
        'last_longitude': 101.6,
      });

      final user =
          await repository.updateLocation(latitude: 3.1, longitude: 101.6);

      expect(fake.single.path, '/rest/v1/rpc/update_location');
      expect(fake.single.json, {
        'p_latitude': 3.1,
        'p_longitude': 101.6,
        'p_place_name': null,
        'p_source': 'gps',
      });
      expect(user.lastPlaceName, isNull);
      expect(user.lastLatitude, 3.1);
    });

    test('"any distance" clears the radius rather than omitting it', () async {
      answers('update_preferences');

      await repository.updateSearchRadius(null);

      expect(fake.single.json, {'p_clear_radius': true});

      fake.calls.clear();
      await repository.updateSearchRadius(10);
      expect(fake.single.json, {'p_radius_km': 10, 'p_clear_radius': false});
    });

    test('a sheet that changes one thing sends one thing', () async {
      answers('update_preferences', {'id': 'user-1', 'halal_only': true});

      final user = await repository.updatePreferences(halalOnly: true);

      expect(fake.single.json, {'p_halal_only': true});
      expect(user.halalOnly, isTrue);
    });

    test('a new budget floor carries its ceiling, null included', () async {
      answers('update_preferences');

      await repository.updatePreferences(budgetMin: 10);

      // Omitting `p_budget_max` would read as "keep the old cap", which is the
      // opposite of what moving the range to "RM 10 and up" means.
      expect(fake.single.json, {'p_budget_min': 10, 'p_budget_max': null});

      // And `clearBudget` is the only way back to "Any" — a null pair on its
      // own is indistinguishable from "leave it alone".
      fake.calls.clear();
      await repository.updatePreferences(spiceLevel: 3, clearBudget: true);
      expect(fake.single.json, {'p_spice_level': 3, 'p_clear_budget': true});
    });

    test('the discovery sheet overwrites all three filters every time',
        () async {
      answers('set_discovery_filters', {
        'id': 'user-1',
        'filter_cuisine_ids': [2, 5],
        'filter_dietary_tag_ids': <int>[],
        'filter_min_rating': 4.0,
      });

      final user = await repository.setDiscoveryFilters(
        cuisineIds: const [2, 5],
        dietaryTagIds: const [],
        minRating: 4,
      );

      expect(fake.single.json, {
        'p_cuisine_ids': [2, 5],
        'p_dietary_tag_ids': <int>[],
        'p_min_rating': 4.0,
      });
      expect(user.filterCuisineIds, [2, 5]);
      expect(user.filterDietaryTagIds, isEmpty);
      expect(user.filterMinRating, 4.0);
    });

    test('an answer that is not a row throws instead of blanking the profile',
        () async {
      // A blank `AppUser` would have a null `onboarded_at` and would kick a
      // fully onboarded user back into the wizard with no error anywhere.
      fake.on('POST', '/rest/v1/rpc/update_preferences', <dynamic>[]);

      await expectLater(
        repository.updatePreferences(vegetarian: true),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
