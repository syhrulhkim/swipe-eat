import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// Where a player is between "asked for" and "playing".
enum TikTokPlayerStatus {
  /// The page is on its way; the view shows a spinner.
  loading,

  /// The player document finished loading.
  ready,

  /// The main frame failed. The view offers a retry.
  failed,
}

/// A TikTok player: the WebView driving it, plus how that load is going.
///
/// The controller alone cannot answer "did this work?" — a load that fails
/// after the controller is built (no network, a pulled clip) leaves a black
/// rectangle and no exception. [status] carries that outcome so the view can
/// show something better than silence.
class TikTokPlayerHandle {
  TikTokPlayerHandle({
    required this.controller,
    required this.playerUrl,
  });

  final WebViewController controller;

  /// The document to load, kept so [reload] can retry without recomputing it.
  final Uri playerUrl;

  final ValueNotifier<TikTokPlayerStatus> status =
      ValueNotifier(TikTokPlayerStatus.loading);

  bool _released = false;

  /// True once the player has been evicted from the cache; a released handle
  /// has been navigated away from and must be reloaded before it shows a clip.
  bool get isReleased => _released;

  /// Loads (or reloads) the clip. Also the retry path, so it resets [status]
  /// rather than assuming it is already `loading`.
  Future<void> load() async {
    _released = false;
    status.value = TikTokPlayerStatus.loading;
    await controller.loadRequest(playerUrl);
  }

  /// Stops the player without destroying it.
  ///
  /// `WebViewController` has no dispose in webview_flutter 4.x — the native
  /// view goes when the widget and the controller are both unreferenced. Until
  /// the collector gets there, an evicted player would keep its audio and its
  /// network going, so send it to a blank page first.
  Future<void> release() async {
    _released = true;
    await controller.loadRequest(Uri.parse('about:blank'));
  }
}

/// Builds a WebView already loading TikTok's own player for [videoUrl].
///
/// TikTok clips are licensed through that player, so the app embeds it rather
/// than playing the media itself.
Future<TikTokPlayerHandle> createTikTokPlayer(String videoUrl) async {
  late final PlatformWebViewControllerCreationParams params;
  if (WebViewPlatform.instance is WebKitWebViewPlatform) {
    params = WebKitWebViewControllerCreationParams(
      allowsInlineMediaPlayback: true,
      mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
    );
  } else {
    params = const PlatformWebViewControllerCreationParams();
  }

  final controller = WebViewController.fromPlatformCreationParams(params);
  // Awaited one by one rather than cascaded: each setter returns a future, and
  // a cascade drops them, so a failure would vanish and the load below could
  // race ahead of the settings it depends on.
  await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
  await controller.setBackgroundColor(Colors.black);
  await controller.setUserAgent(
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
    'Mobile/15E148 Safari/604.1',
  );

  final playerUrl = tikTokPlayerUrl(videoUrl);
  final handle = TikTokPlayerHandle(
    controller: controller,
    playerUrl: playerUrl,
  );

  await controller.setNavigationDelegate(
    NavigationDelegate(
      onPageFinished: (_) {
        if (handle.status.value == TikTokPlayerStatus.loading) {
          handle.status.value = TikTokPlayerStatus.ready;
        }
      },
      onWebResourceError: (error) {
        // Subresources fail all the time inside the player — a tracking pixel,
        // an image — and none of that stops the clip. Only the main frame
        // failing means there is nothing to watch.
        if (error.isForMainFrame == false) {
          return;
        }
        handle.status.value = TikTokPlayerStatus.failed;
      },
      onNavigationRequest: (request) {
        // The player carries links out to the app, the creator's profile and
        // ads. Nothing in this app wants those opening inside the card, so the
        // WebView stays on TikTok's own hosts.
        return isTikTokPlayerNavigation(request.url)
            ? NavigationDecision.navigate
            : NavigationDecision.prevent;
      },
    ),
  );

  final platformController = controller.platform;
  if (platformController is AndroidWebViewController) {
    // Android blocks playback started by script or by an autoplay attribute
    // until this is false, so the player would sit on its first frame.
    await platformController.setMediaPlaybackRequiresUserGesture(false);
  }

  // The player is loaded as the top-level document. Wrapping it in local HTML
  // needs a baseUrl, and claiming `https://www.tiktok.com` for a page TikTok
  // did not serve makes the player refuse with its own "Player error" screen.
  await handle.load();

  return handle;
}

/// TikTok's embeddable player for [videoUrl], or the URL itself when no video
/// id can be read out of it.
Uri tikTokPlayerUrl(String videoUrl) {
  final videoId = extractTikTokVideoId(videoUrl);
  if (videoId == null) {
    return Uri.parse(videoUrl);
  }

  return Uri.parse(
    'https://www.tiktok.com/player/v1/$videoId?autoplay=1&controls=1'
    '&volume_control=1&muted=0&music_info=1&description=1&timestamp=1'
    '&rel=0&loop=1',
  );
}

/// Whether the WebView may follow [url].
///
/// TikTok's own hosts only, plus the blank page an evicted player is parked
/// on.
bool isTikTokPlayerNavigation(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }

  if (uri.scheme == 'about') {
    return true;
  }

  if (uri.scheme != 'https' && uri.scheme != 'http') {
    return false;
  }

  final host = uri.host.toLowerCase();
  return host == 'tiktok.com' || host.endsWith('.tiktok.com');
}

/// Pulls the numeric video id out of a TikTok share URL.
String? extractTikTokVideoId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return null;
  }

  for (final segment in uri.pathSegments.reversed) {
    if (RegExp(r'^\d+$').hasMatch(segment)) {
      return segment;
    }
  }

  return null;
}
