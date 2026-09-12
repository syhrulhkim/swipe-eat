import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Fallback when GPS is unavailable: Peserai, Batu Pahat, near the seeded
/// restaurants, so distances stay plausible in the simulator and when the
/// user denies location access.
Position fallbackUserPosition() {
  return Position(
    longitude: 102.933333,
    latitude: 1.850000,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    accuracy: 0,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
    isMocked: true,
  );
}

Future<Position>? _cachedPosition;

/// Resolves the device position, requesting permission if needed.
/// Never throws — falls back to [fallbackUserPosition] on denial,
/// disabled services, timeout, or any platform error.
///
/// The result is cached for the app session so the tabs that all init at
/// startup share one permission dialog and one GPS fix instead of racing
/// (concurrent requestPermission calls throw on Android).
///
/// A fallback result is NOT kept for the whole session: if the user grants
/// location in Settings after an initial denial, the next caller retries GPS
/// instead of being stuck with the fallback until an app restart.
Future<Position> resolveUserPosition() {
  return _cachedPosition ??= _resolveUserPosition().then((position) {
    if (_isFallback(position)) {
      _cachedPosition = null;
    }
    return position;
  });
}

/// Drops the session cache so the next [resolveUserPosition] call starts a
/// fresh lookup.
///
/// Only needed by tests: each `testWidgets` body runs in its own fake-async
/// zone, and a future cached during an earlier test schedules its callbacks in
/// that (now dead) zone, so a later test would wait on it forever.
@visibleForTesting
void resetUserPositionCache() {
  _cachedPosition = null;
}

/// True when [position] is the [fallbackUserPosition] rather than a real fix.
/// Callers ranking or measuring by distance should treat a fallback as
/// "location unknown" instead of an actual origin.
bool isFallbackUserPosition(Position position) => _isFallback(position);

bool _isFallback(Position position) {
  return position.isMocked &&
      position.timestamp == DateTime.fromMillisecondsSinceEpoch(0);
}

Future<Position> _resolveUserPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return fallbackUserPosition();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return fallbackUserPosition();
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 10),
      ),
    );
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    final lastKnown = await _safeLastKnownPosition();
    return lastKnown ?? fallbackUserPosition();
  }
}

Future<Position?> _safeLastKnownPosition() async {
  try {
    return await Geolocator.getLastKnownPosition();
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    return null;
  }
}
