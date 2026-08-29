import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/tiktok_player_factory.dart';

/// Keeps TikTok players warm for the cards around the one on screen.
///
/// Creating a WebView and loading the player costs about a second, which is
/// the difference between a clip that is already running when the card lands
/// and one that starts with a black rectangle.
class TikTokPlayerCache {
  TikTokPlayerCache({
    Future<WebViewController> Function(String videoUrl)? createController,
  }) : _createController = createController ?? createTikTokPlayerController;

  final Future<WebViewController> Function(String videoUrl) _createController;
  final Map<String, Future<WebViewController>> _controllers = {};

  /// Returns the warm player for [videoUrl], starting one if this is the first
  /// ask. Null for a card with no clip, so callers can pass a nullable URL
  /// straight through.
  Future<WebViewController>? warm(String? videoUrl) {
    if (videoUrl == null || videoUrl.isEmpty) {
      return null;
    }

    return _controllers.putIfAbsent(videoUrl, () {
      final future = _createController(videoUrl);
      // A warmed player nobody has mounted yet has no listener, so a load
      // failure would surface as an unhandled async error. The view that
      // mounts later still sees the error through its own listener.
      unawaited(future.then((_) {}, onError: (Object error) {
        debugPrint('TikTok player load failed: $error');
      }));
      return future;
    });
  }

  void clear() {
    _controllers.clear();
  }
}
