import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swipe_eat/features/onboarding/data/onboarding_repository.dart';
import 'package:swipe_eat/features/onboarding/models/onboarding_draft.dart';

import '../../support/fake_supabase_http.dart';

void main() {
  group('OnboardingRepository', () {
    test('constructs from an injected client without initialising Supabase',
        () {
      final client = SupabaseClient(
        'https://stub.supabase.co',
        'stub-anon-key',
      );
      addTearDown(client.dispose);

      expect(() => OnboardingRepository(client: client), returnsNormally);
    });

    test('construction is free; only the request needs the singleton', () {
      final repository = OnboardingRepository();

      expect(repository.loadCatalog(), throwsA(isA<Error>()));
      expect(
        repository.complete(OnboardingDraft(name: 'Aisyah')),
        throwsA(isA<Error>()),
      );
    });
  });

  group('OnboardingRepository over the wire', () {
    late FakeSupabaseHttp fake;
    late SupabaseClient client;
    late OnboardingRepository repository;

    setUp(() {
      fake = FakeSupabaseHttp();
      client = fakeSupabaseClient(fake);
      addTearDown(client.dispose);
      repository = OnboardingRepository(client: client);
    });

    RecordedCall callTo(String path) =>
        fake.calls.firstWhere((call) => call.path == path);

    test('both pick lists go out together, only cuisines filtered to active',
        () async {
      fake.on('GET', '/rest/v1/cuisines', [
        {'id': 3, 'slug': 'nasi', 'label': 'Nasi'},
      ]);
      fake.on('GET', '/rest/v1/dietary_tags', [
        {'id': 9, 'slug': 'halal', 'label': 'Halal'},
      ]);

      final catalog = await repository.loadCatalog();

      expect(fake.calls, hasLength(2));
      final cuisines = callTo('/rest/v1/cuisines');
      expect(cuisines.query['select'], 'id,slug,label');
      expect(cuisines.query['is_active'], 'eq.true');
      // postgrest-dart's `order()` defaults to *descending*, unlike SQL, so
      // `.order('position')` with no `ascending:` sends `position.desc`. This
      // asserts what actually goes out; see the note in the phase report.
      expect(cuisines.query['order'], 'position.desc.nullslast');

      final dietary = callTo('/rest/v1/dietary_tags');
      expect(dietary.query['select'], 'id,slug,label');
      expect(dietary.query.containsKey('is_active'), isFalse);
      expect(dietary.query['order'], 'position.desc.nullslast');

      expect(catalog.cuisines.single.id, 3);
      expect(catalog.cuisines.single.slug, 'nasi');
      expect(catalog.cuisines.single.label, 'Nasi');
      expect(catalog.dietaryTags.single.id, 9);
    });

    test('complete sends the whole draft and returns the profile it made',
        () async {
      await seedSession(client, userId: 'user-1', email: 'aisyah@test.my');

      final draft = OnboardingDraft(name: '  Aisyah  ')
        ..cuisineIds.addAll([5, 2])
        ..radiusKm = 15
        ..latitude = 3.1
        ..longitude = 101.6
        ..spiceLevel = SpiceLevel.pedas;

      fake.on('POST', '/rest/v1/rpc/complete_onboarding', {
        'id': 'user-1',
        'name': 'Aisyah',
        'onboarded_at': '2026-09-11T10:00:00Z',
        'search_radius_km': 15,
      });

      final user = await repository.complete(draft);

      final call = fake.single;
      expect(call.path, '/rest/v1/rpc/complete_onboarding');
      expect(call.json, draft.toRpcParams());
      expect((call.json as Map)['p_name'], 'Aisyah');
      expect((call.json as Map)['p_cuisine_ids'], [2, 5]);

      expect(user.id, 'user-1');
      expect(user.name, 'Aisyah');
      expect(user.needsOnboarding, isFalse);
      expect(user.searchRadiusKm, 15);
      // `profiles` has no email column — it comes off the session.
      expect(user.email, 'aisyah@test.my');
    });

    test('a row wrapped in an array still reads as the profile', () async {
      fake.on('POST', '/rest/v1/rpc/complete_onboarding', [
        {'id': 'user-2', 'name': 'Farah', 'onboarded_at': '2026-09-11T10:00:00Z'},
      ]);

      final user = await repository.complete(OnboardingDraft(name: 'Farah'));

      expect(user.id, 'user-2');
      expect(user.onboardedAt, isNotNull);
    });
  });
}
