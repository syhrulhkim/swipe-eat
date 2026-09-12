import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/restaurants/state/likes_controller.dart'
    show LikesAuthEvents;
import 'push_messages.dart';
import 'push_repository.dart';

/// The four things this app asks of a push SDK, and nothing else.
///
/// A seam rather than a direct call because `flutter_test` has no Firebase:
/// the whole of [PushService]'s logic — when a token is saved, when it is
/// saved again, what a tapped notification opens — is testable against a fake
/// that implements this, and only the adapter below is device-only (D60).
abstract class PushMessaging {
  Future<bool> requestPermission();

  /// Null until the OS has a token to give. On iOS that is "until APNs has
  /// registered", which can be after launch — [onTokenRefresh] catches up.
  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  /// The `data` map of a notification the user tapped while the app was
  /// running or backgrounded.
  Stream<Map<String, dynamic>> get onMessageOpened;

  /// The notification that launched the app from cold, or null.
  Future<Map<String, dynamic>?> initialMessage();
}

/// [PushMessaging] over the real thing. Not reachable from a test — every line
/// here is a platform channel (CONVENTIONS §8).
class FirebaseMessagingAdapter implements PushMessaging {
  FirebaseMessagingAdapter([FirebaseMessaging? messaging])
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<Map<String, dynamic>> get onMessageOpened =>
      FirebaseMessaging.onMessageOpenedApp.map((message) => message.data);

  @override
  Future<Map<String, dynamic>?> initialMessage() async =>
      (await _messaging.getInitialMessage())?.data;
}

/// Keeps this device's push token where the server can find it, and turns a
/// tapped notification into a route.
///
/// Owns no UI. The route lands on a [ValueNotifier] the router listens to, so
/// a push that arrives before the session has resolved waits on the splash
/// instead of racing it (D155).
class PushService {
  PushService({
    required PushMessaging messaging,
    required ValueNotifier<String?> route,
    PushRepository? repository,
    LikesAuthEvents authEvents = const LikesAuthEvents(),
    String? platform,
  })  : _messaging = messaging,
        _route = route,
        _repository = repository ?? PushRepository(),
        _authEvents = authEvents,
        _platform = platform ??
            (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');

  final PushMessaging _messaging;
  final ValueNotifier<String?> _route;
  final PushRepository _repository;
  final LikesAuthEvents _authEvents;
  final String _platform;

  StreamSubscription<String>? _refreshSubscription;
  StreamSubscription<Map<String, dynamic>>? _openedSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  /// The token this device last saved, so sign-out knows which row to drop.
  String? _token;

  @visibleForTesting
  String? get deviceToken => _token;

  /// Asks for permission, claims the token, and starts listening.
  ///
  /// A refusal is not a failure: everything below still runs, and a user who
  /// says yes later is picked up by `onTokenRefresh` without another prompt.
  Future<void> start() async {
    try {
      await _messaging.requestPermission();
    } on Object catch (error) {
      debugPrint('Asking for notifications failed: $error');
    }

    _refreshSubscription = _messaging.onTokenRefresh.listen(_save);
    _openedSubscription = _messaging.onMessageOpened.listen(_open);
    // The sign-in that owns this token may not have happened yet — `main`
    // starts this before the session resolves — so the token is claimed again
    // on every sign-in rather than only now.
    _authSubscription = _authEvents.changes?.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        final token = _token;
        if (token != null) {
          unawaited(_save(token));
        }
      }
    });

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _save(token);
      }
    } on Object catch (error) {
      debugPrint('Reading the push token failed: $error');
    }

    try {
      final launched = await _messaging.initialMessage();
      if (launched != null) {
        _open(launched);
      }
    } on Object catch (error) {
      debugPrint('Reading the launch notification failed: $error');
    }
  }

  /// Drops this device's row. Called before sign-out, so the next person to
  /// hold the phone is not buzzed about somebody else's dinner.
  Future<void> forgetDevice() async {
    final token = _token;
    if (token == null) {
      return;
    }
    _token = null;
    try {
      await _repository.deleteToken(token);
    } on Object catch (error) {
      // Never rethrown: a token that could not be deleted must not keep
      // somebody signed in.
      debugPrint('Forgetting the push token failed: $error');
    }
  }

  Future<void> _save(String token) async {
    _token = token;
    try {
      await _repository.saveToken(token, platform: _platform);
    } on Object catch (error) {
      debugPrint('Saving the push token failed: $error');
    }
  }

  /// A tapped notification becomes a route the router picks up on its next
  /// pass. Anything this build cannot read is ignored rather than shown.
  void _open(Map<String, dynamic> data) {
    final route = pushRouteFor(data);
    if (route != null) {
      _route.value = route;
    }
  }

  Future<void> dispose() async {
    await _refreshSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _authSubscription?.cancel();
  }
}
