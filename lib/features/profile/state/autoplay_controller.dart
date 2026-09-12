import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/autoplay_setting.dart';

/// Whether this device is on Wi-Fi, now and whenever that changes.
///
/// A typedef, not the plugin, for the reason every platform read in this app
/// is one (D60): `flutter test` has no connectivity channel to answer, and a
/// test that wants to prove the Wi-Fi branch needs to be able to say so.
typedef WifiWatcher = Stream<bool> Function();

/// The real one. `connectivity_plus` reports a list, because a device can be
/// on Wi-Fi and Ethernet at once; anything containing Wi-Fi counts.
Stream<bool> watchDeviceWifi() => Connectivity()
    .onConnectivityChanged
    .map((results) => results.contains(ConnectivityResult.wifi));

/// The autoplay setting, and whether it is currently letting clips play.
///
/// Kept apart from `AuthController` on purpose: this is a device preference
/// (see [AutoplaySetting]), so it is neither read from nor written to the
/// profile, and a signed-out browse session still has one.
class AutoplayController extends ChangeNotifier {
  AutoplayController({WifiWatcher? wifi, bool initialWifi = true})
      : _watchWifi = wifi ?? watchDeviceWifi,
        _wifi = initialWifi;

  /// The app's one instance. The deck and the You tab both read it, and
  /// neither owns the other.
  static final AutoplayController instance = AutoplayController();

  static const String _key = 'autoplay_setting';

  final WifiWatcher _watchWifi;
  StreamSubscription<bool>? _wifiSubscription;

  AutoplaySetting _setting = AutoplaySetting.always;
  AutoplaySetting get setting => _setting;

  bool _wifi;

  /// True when a clip is allowed to start on its own right now.
  ///
  /// Optimistic before the first connectivity event: the default setting does
  /// not consult Wi-Fi at all, so the only user this can briefly be wrong for
  /// is one who chose Wi-Fi-only and opened the app on mobile data — and the
  /// first event lands within a frame or two of launch.
  bool get playsNow => _setting.playsOn(wifi: _wifi);

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Reads the stored setting and starts watching the connection. Safe to
  /// call more than once; the second call is free.
  Future<void> ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _setting = AutoplaySetting.fromSlug(prefs.getString(_key));
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      debugPrint('Autoplay setting read failed: $error');
    }

    _wifiSubscription ??= _watchWifi().listen(
      (wifi) {
        if (wifi == _wifi) {
          return;
        }
        _wifi = wifi;
        // Only the Wi-Fi-only setting can change its mind about a connection.
        if (_setting == AutoplaySetting.wifiOnly) {
          notifyListeners();
        }
      },
      onError: (Object error) {
        debugPrint('Connectivity watch failed: $error');
      },
    );

    notifyListeners();
  }

  /// Writes the choice through, optimistically: the deck should stop warming
  /// players the moment the user says so, not a round trip later.
  Future<void> select(AutoplaySetting value) async {
    if (value == _setting) {
      return;
    }
    _setting = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value.slug);
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      debugPrint('Autoplay setting write failed: $error');
    }
  }

  @override
  void dispose() {
    unawaited(_wifiSubscription?.cancel());
    super.dispose();
  }
}
