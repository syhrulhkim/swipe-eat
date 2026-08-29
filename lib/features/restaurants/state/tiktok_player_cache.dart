import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../data/tiktok_player_factory.dart';

/// Keeps TikTok players warm for the cards around the one on screen.
///
/// Creating a WebView and loading the player costs about a second, which is
/// the difference between a clip that is already running when the card lands
/// and one that starts with a black rectangle.
///
/// Bounded, because a WebView is expensive to hold: a long session would
/// otherwise end with one live player per card swiped, each still holding its
/// native view. The map is kept in least-recently-warmed order and the oldest
/// entry is released when a new one pushes past [capacity].
class TikTokPlayerCache {
  TikTokPlayerCache({
    Future<TikTokPlayerHandle> Function(String videoUrl)? createPlayer,
    this.capacity = 5,
  })  : _createPlayer = createPlayer ?? createTikTokPlayer,
        assert(capacity > 0, 'A cache that holds nothing warms nothing');

  final Future<TikTokPlayerHandle> Function(String videoUrl) _createPlayer;

  /// How many players stay alive at once.
  ///
  /// The deck warms three cards ahead and mounts at most two, and every build
  /// re-asks for the mounted ones, which moves them back to the front. Five is
  /// comfortably above that, so the player the user is watching is never the
  /// one evicted.
  final int capacity;

  /// Insertion-ordered, and re-inserted on every hit, so the first key is
  /// always the least recently asked for.
  final LinkedHashMap<String, Future<TikTokPlayerHandle>> _players =
      LinkedHashMap<String, Future<TikTokPlayerHandle>>();

  @visibleForTesting
  int get length => _players.length;

  /// Returns the warm player for [videoUrl], starting one if this is the first
  /// ask. Null for a card with no clip, so callers can pass a nullable URL
  /// straight through.
  Future<TikTokPlayerHandle>? warm(String? videoUrl) {
    if (videoUrl == null || videoUrl.isEmpty) {
      return null;
    }

    final existing = _players.remove(videoUrl);
    if (existing != null) {
      // Removed and put back rather than read in place: that is what makes
      // this most-recently-used again.
      _players[videoUrl] = existing;
      return existing;
    }

    final future = _createPlayer(videoUrl);
    // A warmed player nobody has mounted yet has no listener, so a load
    // failure would surface as an unhandled async error. The view that mounts
    // later still sees the error through the handle's status.
    unawaited(future.then((_) {}, onError: (Object error) {
      debugPrint('TikTok player load failed: $error');
    }));

    _players[videoUrl] = future;
    _evictOverflow();
    return future;
  }

  /// Drops every player, stopping each one on the way out.
  void clear() {
    final dropped = _players.values.toList();
    _players.clear();
    for (final player in dropped) {
      _release(player);
    }
  }

  void _evictOverflow() {
    while (_players.length > capacity) {
      final oldest = _players.keys.first;
      _release(_players.remove(oldest)!);
    }
  }

  void _release(Future<TikTokPlayerHandle> player) {
    // A player that never loaded has nothing to stop, and one that refuses to
    // navigate away is already on its way out — neither is worth more than a
    // line in the log.
    unawaited(player.then((handle) => handle.release()).catchError(
          (Object error) => debugPrint('TikTok player release failed: $error'),
        ));
  }
}
