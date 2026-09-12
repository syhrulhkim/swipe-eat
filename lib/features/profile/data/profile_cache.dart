import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/models/app_user.dart';

/// The signed-in user's profile, on the device.
///
/// A session outlives any single network call: a cold start with no connection
/// restores the session fine and then fails to read `profiles`, which used to
/// leave the app signed in with no name, no radius and no place chip. The
/// cached row fills that gap until the real read succeeds.
///
/// Account-scoped and never throws, for the same reasons as the deck cache.
class ProfileCache {
  const ProfileCache();

  static const String _key = 'profile_cache_v1';

  Future<void> save(AppUser user) async {
    if (user.id.isEmpty) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(user.toCache()));
    } on Object catch (error) {
      debugPrint('Profile cache write failed: $error');
    }
  }

  /// The cached profile for [userId], or null when there is none or it belongs
  /// to another account.
  ///
  /// Deliberately not aged out: a profile does not go stale the way a ranked
  /// deck does, and the alternative to an old name is no name at all.
  Future<AppUser?> read(String userId) async {
    if (userId.isEmpty) {
      return null;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) {
        return null;
      }

      final payload = jsonDecode(raw);
      if (payload is! Map<String, dynamic>) {
        return null;
      }

      final user = AppUser.fromCache(payload);
      return user.id == userId ? user : null;
    } on Object catch (error) {
      debugPrint('Profile cache read failed: $error');
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } on Object catch (error) {
      debugPrint('Profile cache clear failed: $error');
    }
  }
}
