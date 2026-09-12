import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/profile/data/profile_cache.dart';

const String _id = '39c39a30-c8fb-4e08-8e13-c90212f68e59';
const String _otherId = '8c0f6f2e-1c53-4b2d-9c1e-6f8a2b7d4e11';

AppUser _user({String id = _id}) {
  return AppUser(
    id: id,
    name: 'Hana Abdullah',
    email: 'demo@swipeeat.test',
    avatarUrl: 'https://example.test/hana.jpg',
    onboardedAt: DateTime.utc(2026, 8, 23, 9, 30),
    createdAt: DateTime.utc(2026, 3, 4, 1, 15),
    searchRadiusKm: 10,
    lastPlaceName: 'Bangsar',
    filterCuisineIds: const [2, 5],
    filterDietaryTagIds: const [7],
    filterMinRating: 4.5,
    halalOnly: true,
    vegetarian: true,
    spiceLevel: 3,
    budgetMin: 15,
    budgetMax: 60,
  );
}

void main() {
  const cache = ProfileCache();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ProfileCache', () {
    test('a saved profile comes back whole', () async {
      // The whole point of the cache: a cold offline launch has to know the
      // rules that shape the deck, not just the name.
      await cache.save(_user());

      final restored = await cache.read(_id);

      expect(restored, isNotNull);
      expect(restored!.id, _id);
      expect(restored.name, 'Hana Abdullah');
      expect(restored.email, 'demo@swipeeat.test');
      expect(restored.avatarUrl, 'https://example.test/hana.jpg');
      expect(restored.searchRadiusKm, 10);
      expect(restored.lastPlaceName, 'Bangsar');
      expect(restored.filterCuisineIds, [2, 5]);
      expect(restored.filterDietaryTagIds, [7]);
      expect(restored.filterMinRating, 4.5);
      expect(restored.halalOnly, isTrue);
      expect(restored.vegetarian, isTrue);
      expect(restored.spiceLevel, 3);
      expect(restored.budgetMin, 15);
      expect(restored.budgetMax, 60);
      // Stored as ISO-8601 and read back in local time: the instant survives
      // the trip even though the zone does not.
      expect(restored.onboardedAt!.toUtc(), DateTime.utc(2026, 8, 23, 9, 30));
      expect(restored.createdAt!.toUtc(), DateTime.utc(2026, 3, 4, 1, 15));
    });

    test('an unanswered rules step survives as unanswered', () async {
      // "Skipped the step" and "answered every question with a default" are
      // different states, and the cache must not turn one into the other.
      await cache.save(const AppUser(
        id: _id,
        name: 'Hana',
        email: 'demo@swipeeat.test',
      ));

      final restored = await cache.read(_id);

      expect(restored!.halalOnly, isFalse);
      expect(restored.vegetarian, isFalse);
      expect(restored.spiceLevel, isNull);
      expect(restored.budgetMin, isNull);
      expect(restored.budgetMax, isNull);
      expect(restored.hasBudget, isFalse);
    });

    test('a floor with no ceiling stays uncapped', () async {
      // "RM 15 and up". A cache that restored a 100 cap would quietly hide
      // every place above it from someone who said money was not the issue.
      await cache.save(const AppUser(
        id: _id,
        name: 'Hana',
        email: 'demo@swipeeat.test',
        budgetMin: 15,
      ));

      final restored = await cache.read(_id);

      expect(restored!.budgetMin, 15);
      expect(restored.budgetMax, isNull);
    });

    test('another account\'s cache is not this account\'s profile', () async {
      await cache.save(_user(id: _otherId));

      expect(await cache.read(_id), isNull);
    });

    test('an empty id neither writes nor reads', () async {
      await cache.save(_user(id: ''));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('profile_cache_v1'), isNull);
      expect(await cache.read(''), isNull);
    });

    test('no cache at all is not an error', () async {
      expect(await cache.read(_id), isNull);
    });

    test('a corrupt cache reads as none rather than throwing', () async {
      // The cache never throws: the alternative to an old name is no name,
      // not a crashed launch.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'profile_cache_v1': 'not json',
      });

      expect(await cache.read(_id), isNull);
    });

    test('clearing it leaves nothing behind', () async {
      await cache.save(_user());
      await cache.clear();

      expect(await cache.read(_id), isNull);
    });

    test('a later save replaces the earlier one', () async {
      await cache.save(_user());
      await cache.save(_user().copyWith(spiceLevel: 1, halalOnly: false));

      final restored = await cache.read(_id);

      expect(restored!.spiceLevel, 1);
      expect(restored.halalOnly, isFalse);
    });

    test('is stored as the json AppUser.fromCache reads', () async {
      // The stored shape is the contract between save and read; snake_case
      // keys are what a hand-written migration would have to match.
      await cache.save(_user());

      final prefs = await SharedPreferences.getInstance();
      final payload = jsonDecode(prefs.getString('profile_cache_v1')!)
          as Map<String, dynamic>;

      expect(payload['halal_only'], isTrue);
      expect(payload['vegetarian'], isTrue);
      expect(payload['spice_level'], 3);
      expect(payload['budget_min'], 15);
      expect(payload['budget_max'], 60);
    });
  });
}
