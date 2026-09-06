import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';

void main() {
  group('AppUser.fromProfile', () {
    test('parses the radius and place name off the profile row', () {
      final user = AppUser.fromProfile(const {
        'id': '39c39a30-c8fb-4e08-8e13-c90212f68e59',
        'name': 'Aisyah',
        'search_radius_km': 10,
        'last_place_name': 'Peserai, Batu Pahat',
      });

      expect(user.searchRadiusKm, 10);
      expect(user.lastPlaceName, 'Peserai, Batu Pahat');
    });

    test('a null radius means no limit and an empty place name means none',
        () {
      final user = AppUser.fromProfile(const {
        'id': '39c39a30-c8fb-4e08-8e13-c90212f68e59',
        'search_radius_km': null,
        'last_place_name': '  ',
      });

      expect(user.searchRadiusKm, isNull);
      expect(user.lastPlaceName, isNull);
    });

    test('reads the diet and budget answers', () {
      final user = AppUser.fromProfile(const {
        'id': '39c39a30-c8fb-4e08-8e13-c90212f68e59',
        'created_at': '2026-03-04T09:00:00Z',
        'halal_only': true,
        'vegetarian': false,
        'spice_level': 4,
        'budget_min': 10,
        'budget_max': 40,
      });

      expect(user.halalOnly, isTrue);
      expect(user.vegetarian, isFalse);
      expect(user.spiceLevel, 4);
      expect(user.budgetMin, 10);
      expect(user.budgetMax, 40);
      expect(user.hasBudget, isTrue);
      expect(user.createdAt, isNotNull);
    });

    test('an unanswered rules step reads as off, unset and "Any"', () {
      // A profile written before this column existed, and one whose owner
      // skipped the step, have to look the same — neither said anything.
      final user = AppUser.fromProfile(const {
        'id': '39c39a30-c8fb-4e08-8e13-c90212f68e59',
      });

      expect(user.halalOnly, isFalse);
      expect(user.vegetarian, isFalse);
      expect(user.spiceLevel, isNull);
      expect(user.hasBudget, isFalse);
    });
  });

  group('AppUser round-trips', () {
    final user = AppUser(
      id: '39c39a30-c8fb-4e08-8e13-c90212f68e59',
      name: 'Aisyah',
      email: 'demo@swipeeat.test',
      onboardedAt: DateTime.utc(2026, 8, 23),
      createdAt: DateTime.utc(2026, 3, 4),
      searchRadiusKm: 10,
      lastPlaceName: 'Bangsar',
      halalOnly: true,
      vegetarian: true,
      spiceLevel: 3,
      budgetMin: 15,
      budgetMax: 60,
    );

    test('the cache keeps every answer', () {
      final restored = AppUser.fromCache(user.toCache());

      expect(restored.halalOnly, isTrue);
      expect(restored.vegetarian, isTrue);
      expect(restored.spiceLevel, 3);
      expect(restored.budgetMin, 15);
      expect(restored.budgetMax, 60);
      // The cache stores ISO-8601 and reads it back in local time, so the
      // instant survives the trip even though the zone does not.
      expect(restored.createdAt!.toUtc(), user.createdAt);
    });

    test('a new floor carries its own ceiling, null included', () {
      // "RM 15 and up". Without the pair rule the old RM 60 cap would survive
      // a change that was explicitly about removing it.
      final uncapped = user.copyWith(budgetMin: 15, budgetMax: null);

      expect(uncapped.budgetMin, 15);
      expect(uncapped.budgetMax, isNull);
    });

    test('clearing the budget takes both ends', () {
      final cleared = user.copyWith(clearBudget: true);

      expect(cleared.budgetMin, isNull);
      expect(cleared.budgetMax, isNull);
      expect(cleared.hasBudget, isFalse);
    });

    test('clearing the radius is "Any distance", not "leave it alone"', () {
      expect(user.copyWith(clearRadius: true).searchRadiusKm, isNull);
      expect(user.copyWith().searchRadiusKm, 10);
    });

    test('an untouched copy keeps the rules', () {
      final copy = user.copyWith(name: 'Hana');

      expect(copy.halalOnly, isTrue);
      expect(copy.spiceLevel, 3);
      expect(copy.budgetMax, 60);
    });
  });

  group('AppUser.copyWith carries every field', () {
    // A field the constructor gained and copyWith forgot is the classic silent
    // bug here: nothing fails, the value just disappears the next time any
    // sheet writes a different one. So this builds a user with nothing at its
    // default and checks the lot, twice.
    final full = AppUser(
      id: '39c39a30-c8fb-4e08-8e13-c90212f68e59',
      name: 'Aisyah',
      email: 'demo@swipeeat.test',
      avatarUrl: 'https://example.test/aisyah.jpg',
      onboardedAt: DateTime.utc(2026, 8, 23),
      searchRadiusKm: 10,
      lastPlaceName: 'Bangsar',
      filterCuisineIds: const [2, 5],
      filterDietaryTagIds: const [7],
      filterMinRating: 4.5,
      createdAt: DateTime.utc(2026, 3, 4),
      halalOnly: true,
      vegetarian: true,
      spiceLevel: 3,
      budgetMin: 15,
      budgetMax: 60,
    );

    void expectSameExcept(AppUser copy, {String? name}) {
      expect(copy.id, full.id);
      expect(copy.name, name ?? full.name);
      expect(copy.email, full.email);
      expect(copy.avatarUrl, full.avatarUrl);
      // Instants, not identical objects: the cache stores ISO-8601 and reads
      // it back in local time, so the zone flag legitimately differs.
      expect(copy.onboardedAt?.toUtc(), full.onboardedAt?.toUtc());
      expect(copy.searchRadiusKm, full.searchRadiusKm);
      expect(copy.lastPlaceName, full.lastPlaceName);
      expect(copy.filterCuisineIds, full.filterCuisineIds);
      expect(copy.filterDietaryTagIds, full.filterDietaryTagIds);
      expect(copy.filterMinRating, full.filterMinRating);
      expect(copy.createdAt?.toUtc(), full.createdAt?.toUtc());
      expect(copy.halalOnly, full.halalOnly);
      expect(copy.vegetarian, full.vegetarian);
      expect(copy.spiceLevel, full.spiceLevel);
      expect(copy.budgetMin, full.budgetMin);
      expect(copy.budgetMax, full.budgetMax);
    }

    test('a copy with no arguments changes nothing', () {
      expectSameExcept(full.copyWith());
    });

    test('a copy that renames changes only the name', () {
      expectSameExcept(full.copyWith(name: 'Hana'), name: 'Hana');
    });

    test('each rule can be set on its own', () {
      expect(full.copyWith(halalOnly: false).halalOnly, isFalse);
      expect(full.copyWith(halalOnly: false).vegetarian, isTrue,
          reason: 'the other rules are not collateral');
      expect(full.copyWith(vegetarian: false).vegetarian, isFalse);
      expect(full.copyWith(vegetarian: false).halalOnly, isTrue);
      expect(full.copyWith(spiceLevel: 1).spiceLevel, 1);
      expect(full.copyWith(spiceLevel: 1).budgetMax, 60);
    });

    test('a new floor and a new ceiling travel together', () {
      final capped = full.copyWith(budgetMin: 20, budgetMax: 80);

      expect(capped.budgetMin, 20);
      expect(capped.budgetMax, 80);
      expect(capped.halalOnly, isTrue);
      expect(capped.spiceLevel, 3);
    });

    test('a ceiling on its own leaves the floor where it was', () {
      final capped = full.copyWith(budgetMax: 80);

      expect(capped.budgetMin, 15);
      expect(capped.budgetMax, 80);
    });

    test('clearing one nullable pair does not clear the other', () {
      expect(full.copyWith(clearBudget: true).searchRadiusKm, 10);
      expect(full.copyWith(clearRadius: true).budgetMin, 15);
      expect(full.copyWith(clearRadius: true).budgetMax, 60);
    });

    test('the cache round-trips a fully answered profile', () {
      expectSameExcept(AppUser.fromCache(full.toCache()));
    });

    test('the cache round-trips an empty profile', () {
      const blank = AppUser(id: 'x', name: 'User', email: '');
      final restored = AppUser.fromCache(blank.toCache());

      expect(restored.avatarUrl, isNull);
      expect(restored.onboardedAt, isNull);
      expect(restored.createdAt, isNull);
      expect(restored.searchRadiusKm, isNull);
      expect(restored.lastPlaceName, isNull);
      expect(restored.filterCuisineIds, isEmpty);
      expect(restored.filterDietaryTagIds, isEmpty);
      expect(restored.filterMinRating, isNull);
      expect(restored.halalOnly, isFalse);
      expect(restored.vegetarian, isFalse);
      expect(restored.spiceLevel, isNull);
      expect(restored.budgetMin, isNull);
      expect(restored.budgetMax, isNull);
    });

    test('a profile row round-trips through the cache unchanged', () {
      // The two constructors read different shapes — a `profiles` row and the
      // assembled user — and a field read by one and not the other would be
      // lost on the first offline launch.
      final fromRow = AppUser.fromProfile(const {
        'id': '39c39a30-c8fb-4e08-8e13-c90212f68e59',
        'name': 'Aisyah',
        'avatar_url': 'https://example.test/aisyah.jpg',
        'onboarded_at': '2026-08-23T00:00:00Z',
        'created_at': '2026-03-04T00:00:00Z',
        'search_radius_km': 10,
        'last_place_name': 'Bangsar',
        'filter_cuisine_ids': [2, 5],
        'filter_dietary_tag_ids': [7],
        'filter_min_rating': 4.5,
        'halal_only': true,
        'vegetarian': true,
        'spice_level': 3,
        'budget_min': 15,
        'budget_max': 60,
      });

      final restored = AppUser.fromCache(fromRow.toCache());

      expect(restored.toCache(), fromRow.toCache());
      expect(restored.spiceLevel, 3);
      expect(restored.budgetMax, 60);
      expect(restored.filterCuisineIds, [2, 5]);
    });
  });

  group('AppUser.fromProfile edge values', () {
    AppUser userWith(Map<String, dynamic> extra) {
      return AppUser.fromProfile(<String, dynamic>{
        'id': '39c39a30-c8fb-4e08-8e13-c90212f68e59',
        ...extra,
      });
    }

    test('a null halal flag is off, not unknown', () {
      // `_bool` is deliberately strict: the column is `not null default
      // false`, but a row written before the migration reads as null and the
      // deck must not start hiding places over it.
      expect(userWith(const {'halal_only': null}).halalOnly, isFalse);
      expect(userWith(const {'halal_only': 'true'}).halalOnly, isFalse);
      expect(userWith(const {'halal_only': true}).halalOnly, isTrue);
    });

    test('numeric columns arriving as num are truncated to int', () {
      // PostgREST hands smallint back as int, but a json round trip through
      // an edge function can widen it to a double.
      final user = userWith(const {
        'spice_level': 3.0,
        'budget_min': 15.0,
        'budget_max': 60.0,
        'search_radius_km': 10.0,
      });

      expect(user.spiceLevel, 3);
      expect(user.budgetMin, 15);
      expect(user.budgetMax, 60);
      expect(user.searchRadiusKm, 10);
    });

    test('a floor with no ceiling is a budget, an absent floor is not', () {
      expect(userWith(const {'budget_min': 15}).hasBudget, isTrue);
      expect(userWith(const {'budget_min': 15}).budgetMax, isNull);
      expect(userWith(const {'budget_max': 60}).hasBudget, isFalse);
    });
  });

  group('AppUser.narrowingRules', () {
    test('a user with no rules narrows nothing', () {
      const user = AppUser(id: 'u1', email: 'a@b.co', name: 'A');
      expect(user.narrowingRules, isEmpty);
    });

    test('every rule that can empty a deck is named the way a screen names it',
        () {
      const user = AppUser(
        id: 'u1',
        email: 'a@b.co',
        name: 'A',
        halalOnly: true,
        vegetarian: true,
        budgetMin: 10,
        budgetMax: 25,
        filterCuisineIds: [3],
        filterDietaryTagIds: [4],
        filterMinRating: 4.5,
      );
      expect(user.narrowingRules, [
        'Halal only',
        'Vegetarian options',
        'a budget of RM 25',
        'a cuisine filter',
        'a dietary filter',
        'a rating filter',
      ]);
    });

    test('a budget with no ceiling rules nothing out', () {
      const user = AppUser(id: 'u1', email: 'a@b.co', name: 'A', budgetMin: 10);
      expect(user.narrowingRules, isEmpty);
    });
  });
}
