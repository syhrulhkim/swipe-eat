import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_eat/features/restaurants/data/likes_migration.dart';

import 'fake_restaurant_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSwipeRepository swipes;

  setUp(() {
    swipes = FakeSwipeRepository();
  });

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  test('replays stored likes oldest first so the tab order survives',
      () async {
    // The old store kept newest first; the Like tab now orders by the
    // swipe's updated_at, so the replay has to reverse.
    SharedPreferences.setMockInitialValues({legacyLikesKey: '[3, 1, 2]'});

    final migrated = await migrateDeviceLikes(swipes: swipes);

    expect(migrated, isTrue);
    expect(swipes.calls.map((c) => c.restaurantId), [2, 1, 3]);
    expect(swipes.calls.every((c) => c.liked), isTrue);
    expect(swipes.calls.every((c) => c.source == 'likes'), isTrue);

    final store = await prefs();
    expect(store.getBool(likesMigratedKey), isTrue);
    expect(store.getString(legacyLikesKey), isNull);
    expect(store.getString(legacySeenKey), isNull);
  });

  test('runs exactly once', () async {
    SharedPreferences.setMockInitialValues({
      legacyLikesKey: '[3]',
      likesMigratedKey: true,
    });

    final migrated = await migrateDeviceLikes(swipes: swipes);

    expect(migrated, isFalse);
    expect(swipes.calls, isEmpty);
  });

  test('a device with no likes just sets the flag', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final migrated = await migrateDeviceLikes(swipes: swipes);

    expect(migrated, isFalse);
    expect(swipes.calls, isEmpty);
    expect((await prefs()).getBool(likesMigratedKey), isTrue);
  });

  test('corrupt legacy data is dropped, not retried forever', () async {
    SharedPreferences.setMockInitialValues({legacyLikesKey: 'not-json'});

    final migrated = await migrateDeviceLikes(swipes: swipes);

    expect(migrated, isFalse);
    expect(swipes.calls, isEmpty);
    expect((await prefs()).getBool(likesMigratedKey), isTrue);
  });

  test('a failed upsert leaves the flag unset so the next launch retries',
      () async {
    SharedPreferences.setMockInitialValues({legacyLikesKey: '[3, 1]'});
    swipes.fail = true;

    final migrated = await migrateDeviceLikes(swipes: swipes);

    expect(migrated, isFalse);
    final store = await prefs();
    expect(store.getBool(likesMigratedKey), isNull);
    expect(store.getString(legacyLikesKey), '[3, 1]',
        reason: 'the source data must survive a failed run');
  });
}
