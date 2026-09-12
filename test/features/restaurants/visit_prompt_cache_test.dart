import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_eat/features/restaurants/data/visit_prompt_cache.dart';

const String _key = 'visit_prompts_v1';
const String _me = '39c39a30-c8fb-4e08-8e13-c90212f68e59';
const String _someoneElse = '8c0f6f2e-1c53-4b2d-9c1e-6f8a2b7d4e11';

/// One stored entry, dated [ago] before now.
///
/// [VisitPromptCache.recordDirections] stamps `DateTime.now()`, and the timing
/// rules read that stamp, so back-dating has to happen in the blob.
Map<String, dynamic> entry(
  int restaurantId, {
  required Duration ago,
  String userId = _me,
  String? name,
}) {
  return <String, dynamic>{
    'user_id': userId,
    'restaurant_id': restaurantId,
    'name': name ?? 'Restaurant $restaurantId',
    'opened_at': DateTime.now().subtract(ago).toIso8601String(),
  };
}

void seed(List<Map<String, dynamic>> entries) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    _key: jsonEncode(entries),
  });
}

/// The entries as they now sit in the store.
Future<List<dynamic>> stored() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_key);
  return raw == null ? const [] : jsonDecode(raw) as List<dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cache = VisitPromptCache();

  test('a trip from twenty minutes ago is not asked about yet', () async {
    // Coming back from the maps app proves nothing: the user may still be
    // deciding on the sofa.
    seed([entry(7, ago: const Duration(minutes: 20))]);

    expect(await cache.nextPrompt(_me), isNull);
  });

  test('a trip from two hours ago is the one to ask about', () async {
    seed([entry(7, ago: const Duration(hours: 2), name: 'Warung Kak Ros')]);

    final prompt = await cache.nextPrompt(_me);

    expect(prompt, isNotNull);
    expect(prompt!.restaurantId, 7);
    expect(prompt.name, 'Warung Kak Ros');
    expect(prompt.planId, isNull);
  });

  test('a trip older than a week expires unasked', () async {
    seed([entry(7, ago: const Duration(days: 7, hours: 1))]);

    expect(await cache.nextPrompt(_me), isNull);
  });

  test('the freshest ripe trip wins, not the oldest', () async {
    // The most recent meal is the one the user can still answer for.
    seed([
      entry(1, ago: const Duration(days: 3)),
      entry(2, ago: const Duration(hours: 2)),
      entry(3, ago: const Duration(days: 1)),
    ]);

    expect((await cache.nextPrompt(_me))!.restaurantId, 2);
  });

  test('another account is never asked about this one\'s trip', () async {
    seed([entry(7, ago: const Duration(hours: 2), userId: _someoneElse)]);

    expect(await cache.nextPrompt(_me), isNull);
    expect(await cache.nextPrompt(''), isNull);
  });

  test('a second tap on the same place restamps rather than queueing',
      () async {
    seed([entry(7, ago: const Duration(hours: 2))]);

    await cache.recordDirections(userId: _me, restaurantId: 7, name: 'Ros');

    expect((await stored()).length, 1);
    // Restamped, so the clock starts again and the question holds.
    expect(await cache.nextPrompt(_me), isNull);
  });

  test('answering drops the entry', () async {
    seed([
      entry(7, ago: const Duration(hours: 2)),
      entry(8, ago: const Duration(hours: 3)),
    ]);

    await cache.clear(userId: _me, restaurantId: 7);

    expect((await cache.nextPrompt(_me))!.restaurantId, 8);
    expect((await stored()).length, 1);
  });

  test('nothing is recorded without an account or a restaurant', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    await cache.recordDirections(userId: '', restaurantId: 7, name: 'Ros');
    await cache.recordDirections(userId: _me, restaurantId: 0, name: 'Ros');

    expect(prefs.containsKey(_key), isFalse);
  });

  test('the twenty-first trip pushes the oldest one out', () async {
    // All inside the week, so the cap is what drops one and not the sweep.
    seed([
      for (var i = 0; i < 20; i++)
        entry(100 + i, ago: Duration(hours: 2, minutes: 20 - i)),
    ]);

    await cache.recordDirections(userId: _me, restaurantId: 999, name: 'New');

    final ids = (await stored())
        .cast<Map<String, dynamic>>()
        .map((row) => row['restaurant_id'])
        .toList();
    expect(ids.length, 20);
    expect(ids, isNot(contains(100)));
    expect(ids, contains(999));
  });

  test('a corrupt blob starts over instead of failing', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      _key: 'not json at all',
    });

    expect(await cache.nextPrompt(_me), isNull);

    await cache.recordDirections(userId: _me, restaurantId: 7, name: 'Ros');

    expect((await stored()).length, 1);
  });

  group('PendingVisit', () {
    test('round-trips through json, plan and all', () {
      final visit = PendingVisit(
        userId: _me,
        restaurantId: 7,
        name: 'Warung Kak Ros',
        openedAt: DateTime.utc(2026, 9, 12, 12),
        planId: 42,
      );

      final copy = PendingVisit.fromJson(visit.toJson());

      expect(copy.userId, _me);
      expect(copy.restaurantId, 7);
      expect(copy.name, 'Warung Kak Ros');
      expect(copy.openedAt, visit.openedAt);
      expect(copy.planId, 42);
    });

    test('a walk-in carries no plan key at all', () {
      final json = PendingVisit(
        userId: _me,
        restaurantId: 7,
        name: 'Ros',
        openedAt: DateTime.utc(2026, 9, 12, 12),
      ).toJson();

      expect(json.containsKey('plan_id'), isFalse);
    });

    test('a row with nothing readable in it is epoch-dated, not a throw', () {
      final visit = PendingVisit.fromJson(const <String, dynamic>{});

      expect(visit.userId, '');
      expect(visit.restaurantId, 0);
      expect(visit.openedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });
  });
}
