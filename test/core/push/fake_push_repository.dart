import 'dart:async';

import 'package:swipe_eat/core/push/push_repository.dart';
import 'package:swipe_eat/core/push/push_service.dart';

/// `implements`, never `extends` (D69): if the repository grows an argument,
/// this stops compiling instead of quietly dropping it.
class FakePushRepository implements PushRepository {
  /// Every token saved, with the platform it was saved as.
  final List<(String, String)> saved = [];

  final List<String> deleted = [];

  /// Thrown by the next [saveToken]. The service swallows it — a phone that
  /// could not register must still open — so a test needs a way to cause one.
  Object? failSaveWith;

  Object? failDeleteWith;

  @override
  Future<void> saveToken(String token, {required String platform}) async {
    final failure = failSaveWith;
    if (failure != null) {
      failSaveWith = null;
      throw failure;
    }
    saved.add((token, platform));
  }

  @override
  Future<void> deleteToken(String token) async {
    final failure = failDeleteWith;
    if (failure != null) {
      failDeleteWith = null;
      throw failure;
    }
    deleted.add(token);
  }
}

/// Stands in for Firebase Messaging. Nothing in `flutter_test` can reach the
/// real one (D60), so the seam is where the service's whole behaviour is
/// driven from: a token that arrives late, a token that changes, a
/// notification tapped now and one that launched the app.
class FakePushMessaging implements PushMessaging {
  FakePushMessaging({
    this.token,
    this.granted = true,
    this.launchMessage,
  });

  String? token;
  bool granted;
  Map<String, dynamic>? launchMessage;

  final List<String> calls = [];

  final StreamController<String> refreshes = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> openings =
      StreamController.broadcast();

  Future<void> dispose() async {
    await refreshes.close();
    await openings.close();
  }

  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    return granted;
  }

  @override
  Future<String?> getToken() async {
    calls.add('getToken');
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => refreshes.stream;

  @override
  Stream<Map<String, dynamic>> get onMessageOpened => openings.stream;

  @override
  Future<Map<String, dynamic>?> initialMessage() async {
    calls.add('initialMessage');
    return launchMessage;
  }
}
