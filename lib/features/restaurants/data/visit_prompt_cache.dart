import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A place the user asked directions to, still waiting on the question of
/// whether they actually went.
@immutable
class PendingVisit {
  const PendingVisit({
    required this.userId,
    required this.restaurantId,
    required this.name,
    required this.openedAt,
  });

  factory PendingVisit.fromJson(Map<String, dynamic> json) {
    return PendingVisit(
      userId: json['user_id'] as String? ?? '',
      restaurantId: (json['restaurant_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      openedAt:
          DateTime.tryParse(json['opened_at'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String userId;
  final int restaurantId;
  final String name;

  /// When the maps app was opened — the clock the prompt's timing runs on.
  final DateTime openedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'user_id': userId,
        'restaurant_id': restaurantId,
        'name': name,
        'opened_at': openedAt.toIso8601String(),
      };
}

/// The places this device has routed the user to, kept until the app has asked
/// whether they went.
///
/// Device-local on purpose. The durable fact — "I ate here" — goes to the
/// backend through `mark_visited`; what lives here is only the question still
/// outstanding, which is short-lived and worth nothing to another device.
///
/// Every entry carries the account that created it, because preferences are
/// device-global: whoever signs in next must not be asked about a previous
/// user's trip.
///
/// Never throws. A cache that cannot be read or written simply means the app
/// does not ask.
class VisitPromptCache {
  const VisitPromptCache();

  static const String _key = 'visit_prompts_v1';

  /// How long to wait before asking. Returning from the maps app is not
  /// evidence of anything — the user may still be on the sofa deciding — so
  /// the question holds until enough of a meal has plausibly happened.
  static const Duration minAge = Duration(minutes: 45);

  /// Past this the user no longer remembers reliably, so the entry expires
  /// unasked rather than becoming a bad prompt.
  static const Duration maxAge = Duration(days: 7);

  /// Enough for any real run of unanswered trips; the cap only stops a
  /// pathological device from growing the blob without bound.
  static const int maxEntries = 20;

  /// Remembers that the user was sent to [restaurantId]. A second tap on the
  /// same place restamps the first entry rather than queueing a duplicate.
  Future<void> recordDirections({
    required String userId,
    required int restaurantId,
    required String name,
  }) async {
    if (userId.isEmpty || restaurantId == 0) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = _read(prefs)
        ..removeWhere(
          (entry) =>
              entry.userId == userId && entry.restaurantId == restaurantId,
        );

      entries.add(
        PendingVisit(
          userId: userId,
          restaurantId: restaurantId,
          name: name,
          openedAt: DateTime.now(),
        ),
      );

      await _write(prefs, entries);
    } on Object catch (error) {
      debugPrint('Visit prompt write failed: $error');
    }
  }

  /// The entry to ask about now: [userId]'s most recent trip that is older
  /// than [minAge] and younger than [maxAge]. Null when there is nothing ripe.
  ///
  /// Most recent rather than oldest — the freshest trip is the one the user
  /// can still answer for.
  Future<PendingVisit?> nextPrompt(String userId) async {
    if (userId.isEmpty) {
      return null;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final ripe = _read(prefs).where((entry) {
        if (entry.userId != userId) {
          return false;
        }
        final age = now.difference(entry.openedAt);
        return age >= minAge && age <= maxAge;
      }).toList()
        ..sort((a, b) => b.openedAt.compareTo(a.openedAt));

      return ripe.isEmpty ? null : ripe.first;
    } on Object catch (error) {
      debugPrint('Visit prompt read failed: $error');
      return null;
    }
  }

  /// Drops the entry for [restaurantId] — the question has been answered, one
  /// way or the other.
  Future<void> clear({
    required String userId,
    required int restaurantId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = _read(prefs)
        ..removeWhere(
          (entry) =>
              entry.userId == userId && entry.restaurantId == restaurantId,
        );
      await _write(prefs, entries);
    } on Object catch (error) {
      debugPrint('Visit prompt clear failed: $error');
    }
  }

  List<PendingVisit> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return <PendingVisit>[];
    }

    try {
      final payload = jsonDecode(raw);
      if (payload is! List) {
        return <PendingVisit>[];
      }
      return payload
          .whereType<Map<String, dynamic>>()
          .map(PendingVisit.fromJson)
          .where((entry) => entry.restaurantId != 0)
          .toList();
    } on Object catch (error) {
      // Corrupt, or written by an older shape: start over rather than fail.
      debugPrint('Visit prompt decode failed: $error');
      return <PendingVisit>[];
    }
  }

  /// Writes back, dropping anything past [maxAge] on the way through so the
  /// blob prunes itself without a separate sweep.
  Future<void> _write(SharedPreferences prefs, List<PendingVisit> entries) {
    final now = DateTime.now();
    final live = entries
        .where((entry) => now.difference(entry.openedAt) <= maxAge)
        .toList()
      ..sort((a, b) => a.openedAt.compareTo(b.openedAt));

    final kept = live.length <= maxEntries
        ? live
        : live.sublist(live.length - maxEntries);

    if (kept.isEmpty) {
      return prefs.remove(_key);
    }

    return prefs.setString(
      _key,
      jsonEncode(kept.map((entry) => entry.toJson()).toList()),
    );
  }
}
