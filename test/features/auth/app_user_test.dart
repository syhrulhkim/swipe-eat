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
}
