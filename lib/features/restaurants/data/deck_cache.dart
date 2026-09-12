import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/restaurant.dart';

/// A deck that was dealt earlier, kept so a launch with no connection has
/// something to show.
class CachedDeck {
  const CachedDeck({required this.restaurants, required this.savedAt});

  final List<Restaurant> restaurants;
  final DateTime savedAt;
}

/// The last deck the server dealt, on the device.
///
/// Account-scoped: the deck is ranked from one user's taste and already
/// excludes what that user swiped, so serving it to whoever signs in next
/// would be both wrong and a small privacy leak. The stored user id is checked
/// on every read.
///
/// Never throws. A cache that cannot be read or written is a cache miss, and a
/// miss only costs the offline fallback.
class DeckCache {
  const DeckCache();

  static const String _key = 'deck_cache_v1';

  /// Old enough that the ranking behind it is meaningless — a deck from last
  /// month knows nothing about where the user is now.
  static const Duration maxAge = Duration(days: 7);

  Future<void> save({
    required String userId,
    required List<Restaurant> restaurants,
  }) async {
    if (userId.isEmpty || restaurants.isEmpty) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(<String, dynamic>{
          'user_id': userId,
          'saved_at': DateTime.now().toIso8601String(),
          'restaurants': restaurants.map((row) => row.toJson()).toList(),
        }),
      );
    } on Object catch (error) {
      debugPrint('Deck cache write failed: $error');
    }
  }

  /// The cached deck for [userId], or null when there is none, it belongs to
  /// another account, or it is past [maxAge].
  Future<CachedDeck?> read(String userId) async {
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
      if (payload is! Map<String, dynamic> || payload['user_id'] != userId) {
        return null;
      }

      final savedAt = DateTime.tryParse(payload['saved_at'] as String? ?? '');
      if (savedAt == null || DateTime.now().difference(savedAt) > maxAge) {
        return null;
      }

      final restaurants = (payload['restaurants'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(Restaurant.fromJson)
          .toList();
      if (restaurants.isEmpty) {
        return null;
      }

      return CachedDeck(restaurants: restaurants, savedAt: savedAt);
    } on Object catch (error) {
      // Corrupt or written by an older shape: treat as a miss.
      debugPrint('Deck cache read failed: $error');
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } on Object catch (error) {
      debugPrint('Deck cache clear failed: $error');
    }
  }
}
