import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'swipe_repository.dart';

/// Prefs key of the deleted device-local `LikesStore` (newest-first JSON list
/// of ids). Both stores kept ids stable for exactly this migration.
const String legacyLikesKey = 'liked_restaurant_ids_v1';

/// Prefs key of the deleted `SeenRestaurantsStore`. Its data is not migrated
/// — "seen recently" expired after 3 days anyway — just deleted.
const String legacySeenKey = 'seen_restaurant_ids_v1';

/// Set once the move has happened, so it never runs twice.
const String likesMigratedKey = 'likes_migrated_v1';

/// One-time move of likes recorded before the auth swap into the swipes
/// table. Returns true when anything was migrated. Never throws: the
/// dashboard fires this and forgets it, and a failed run simply retries on
/// the next launch because the flag is only set after every upsert lands.
///
/// Deliberately device-scoped: the legacy likes predate accounts entirely,
/// so they belong to whichever account first reaches the dashboard on this
/// device — almost certainly the device's owner. Scoping the flag per user
/// would instead copy the same likes into every account that signs in here,
/// which is strictly worse.
Future<bool> migrateDeviceLikes({SwipeRepository? swipes}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(likesMigratedKey) ?? false) {
      return false;
    }

    final ids = _parseIds(prefs.getString(legacyLikesKey));
    if (ids.isNotEmpty) {
      final repository = swipes ?? SwipeRepository();
      // Oldest first: the Like tab orders by the swipe's updated_at, so
      // writing in reverse keeps the old list's newest-first order intact.
      for (final id in ids.reversed) {
        await repository.record(restaurantId: id, liked: true, source: 'likes');
      }
    }

    await prefs.setBool(likesMigratedKey, true);
    await prefs.remove(legacyLikesKey);
    await prefs.remove(legacySeenKey);
    return ids.isNotEmpty;
  } on Object catch (error, stackTrace) {
    // Best-effort by design: the flag stays unset, so whatever failed — the
    // preferences read, a swipe write — is retried on the next launch.
    debugPrint('Likes migration failed (will retry): $error\n$stackTrace');
    return false;
  }
}

List<int> _parseIds(String? raw) {
  if (raw == null || raw.isEmpty) {
    return const [];
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }
    return [
      for (final value in decoded)
        if (value is num && value.isFinite) value.toInt(),
    ];
  } on FormatException {
    // Corrupt data from an older/foreign writer: nothing worth carrying over.
    return const [];
  }
}
