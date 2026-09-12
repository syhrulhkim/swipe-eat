import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_eat/features/restaurants/data/deck_cache.dart';

import 'fake_restaurant_repositories.dart';

const String _key = 'deck_cache_v1';
const String _me = '39c39a30-c8fb-4e08-8e13-c90212f68e59';
const String _someoneElse = '8c0f6f2e-1c53-4b2d-9c1e-6f8a2b7d4e11';

/// Writes the stored blob by hand, so a test can date it.
///
/// [DeckCache.save] stamps `DateTime.now()`, which is exactly the field the
/// age rule reads — seeding is the only way to be a week old.
Future<void> seed({
  String userId = _me,
  required DateTime savedAt,
  List<int> ids = const [1, 2],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    _key: jsonEncode(<String, dynamic>{
      'user_id': userId,
      'saved_at': savedAt.toIso8601String(),
      'restaurants': ids.map((id) => testRestaurant(id).toJson()).toList(),
    }),
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cache = DeckCache();

  test('a deck saved for this account comes back', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await cache.save(
      userId: _me,
      restaurants: [testRestaurant(1, name: 'Warung Kak Ros')],
    );
    final cached = await cache.read(_me);

    expect(cached, isNotNull);
    expect(cached!.restaurants.map((row) => row.id), [1]);
    expect(cached.restaurants.single.name, 'Warung Kak Ros');
    // The stamp is what the staleness marker reads, so it has to be the
    // moment of the write, not the epoch a failed parse would give.
    expect(
      DateTime.now().difference(cached.savedAt),
      lessThan(const Duration(minutes: 1)),
    );
  });

  test('a deck belonging to another account is a miss', () async {
    // Preferences are device-global; the next person to sign in must not be
    // dealt a deck ranked from someone else's taste.
    await seed(userId: _someoneElse, savedAt: DateTime.now());

    expect(await cache.read(_me), isNull);
  });

  test('a deck older than a week is a miss', () async {
    await seed(
      savedAt: DateTime.now().subtract(const Duration(days: 7, minutes: 1)),
    );

    expect(await cache.read(_me), isNull);
  });

  test('a deck a day old is still served', () async {
    await seed(savedAt: DateTime.now().subtract(const Duration(days: 1)));

    expect((await cache.read(_me))!.restaurants.map((row) => row.id), [1, 2]);
  });

  test('a blob that is not the shape we wrote is a miss, not a throw',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      _key: '{not json at all',
    });

    expect(await cache.read(_me), isNull);
  });

  test('an empty deck and an empty user are never written', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    await cache.save(userId: _me, restaurants: const []);
    expect(prefs.containsKey(_key), isFalse);

    await cache.save(userId: '', restaurants: [testRestaurant(1)]);
    expect(prefs.containsKey(_key), isFalse);
  });

  test('reading for nobody asks the store nothing', () async {
    await seed(savedAt: DateTime.now());

    expect(await cache.read(''), isNull);
  });

  test('clear drops the deck', () async {
    await seed(savedAt: DateTime.now());

    await cache.clear();

    expect(await cache.read(_me), isNull);
  });
}
