import 'dart:async';

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
    required this.videoUrl,
    required bool muted,
  })  : muted = ValueNotifier(muted),
        playerUrl = tikTokPlayerUrl(videoUrl);

  final WebViewController controller;

  /// The clip this player was built for.
  final String videoUrl;

  /// The document to load, kept so [load] can retry without recomputing it.
  Uri playerUrl;

  /// Whether the clip is playing silent. Starts true (D89); the card's "Tap
  /// for sound" hint flips it and follows it.
  final ValueNotifier<bool> muted;

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

  /// Turns the sound on or off through TikTok's own embed-player API (D122).
  ///
  /// The URL's `muted` parameter cannot do this. Their docs define `muted=1`
  /// as "set the default volume to 0 **and prevent the user from changing
  /// the volume**" and `muted=0` as merely enabling the volume control — so
  /// reloading with `muted=0` produced a clip that was still silent, which is
  /// exactly what "Tap for sound" was doing before. Verified against the live
  /// player: under `muted=1` an `unMute` message is refused outright.
  ///
  /// D4 still holds. This is the documented `x-tiktok-player` message their
  /// player listens for, not a reach into their DOM — and driving a clip that
  /// is already on screen is what it is for. It costs no reload, so the clip
  /// no longer restarts from the top when the sound comes on.
  Future<void> setMuted(bool value) async {
    if (muted.value == value) {
      return;
    }

    muted.value = value;
    await _postMuteState();
  }

  /// Tells the loaded page what [muted] currently says.
  ///
  /// Also the re-apply after every page load: `loadRequest` returns when the
  /// navigation *starts*, so the handle — and the pill reading it — go live
  /// while the document is still coming. A tap that lands in that window would
  /// otherwise be swallowed by the page that arrives afterwards.
  Future<void> _postMuteState() async {
    final type = muted.value ? 'mute' : 'unMute';
    try {
      await controller.runJavaScript(
        "window.postMessage({'x-tiktok-player':true,type:'$type'},'*')",
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      // The page can be gone, blank or mid-navigation. Losing the sound is not
      // worth an error on a card the user is only looking at.
    }
  }

  /// Stops the player without destroying it.
  ///
  /// `WebViewController` has no dispose in webview_flutter 4.x — the native
  /// view goes when the widget and the controller are both unreferenced. Until
  /// the collector gets there, an evicted player would keep its audio and its
  /// network going, so send it to a blank page first.
  Future<void> release() async {
    _released = true;
    // Back to silent: a released handle can be warmed again later, and D89
    // says a clip starts muted however it got here. onPageFinished re-applies
    // that to whatever page comes next.
    muted.value = true;
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

  final handle = TikTokPlayerHandle(
    controller: controller,
    videoUrl: videoUrl,
    muted: true,
  );

  await controller.setNavigationDelegate(
    NavigationDelegate(
      onPageFinished: (_) {
        if (handle.status.value == TikTokPlayerStatus.loading) {
          handle.status.value = TikTokPlayerStatus.ready;
        }
        // The player is loaded with the volume control unlocked, so on a
        // WebView with the autoplay gesture requirement switched off it could
        // come up with sound. D89 says a clip starts silent, and this is where
        // that is enforced — and where a tap that beat the page gets applied.
        unawaited(handle._postMuteState());
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

  // Always `muted=0`, which does not mean "start with sound". In TikTok's
  // player it means "leave the volume control usable"; `muted=1` pins the
  // volume at 0 and refuses every unmute for the life of the page, which is
  // what made "Tap for sound" a no-op. A clip still *starts* silent (D89) —
  // browsers mute an autoplay that had no gesture, and onPageFinished re-posts
  // `mute` for the WebViews where that requirement is switched off.
  return Uri.parse(
    'https://www.tiktok.com/player/v1/$videoId?autoplay=1&controls=1'
    '&volume_control=1&muted=0'
    '&music_info=1&description=1&timestamp=1&rel=0&loop=1',
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
