import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// Builds a WebView already loading TikTok's own player for [videoUrl].
///
/// TikTok clips are licensed through that player, so the app embeds it rather
/// than playing the media itself.
Future<WebViewController> createTikTokPlayerController(String videoUrl) async {
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
  await controller.setNavigationDelegate(NavigationDelegate());

  final platformController = controller.platform;
  if (platformController is AndroidWebViewController) {
    // Android blocks playback started by script or by an autoplay attribute
    // until this is false, so the player would sit on its first frame.
    await platformController.setMediaPlaybackRequiresUserGesture(false);
  }

  final videoId = extractTikTokVideoId(videoUrl);
  final playerUrl = videoId == null
      ? videoUrl
      : 'https://www.tiktok.com/player/v1/$videoId?autoplay=1&controls=1&volume_control=1&muted=0&music_info=1&description=1&timestamp=1&rel=0&loop=1';

  // The player is loaded as the top-level document. Wrapping it in local HTML
  // needs a baseUrl, and claiming `https://www.tiktok.com` for a page TikTok
  // did not serve makes the player refuse with its own "Player error" screen.
  await controller.loadRequest(Uri.parse(playerUrl));

  return controller;
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
