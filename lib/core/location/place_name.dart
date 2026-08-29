import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'open_directions.dart';
import 'user_location.dart';

/// Turns a fix into a human place name like `Peserai, Batu Pahat`.
///
/// Reverse geocoding goes through the OS service, which is rate limited and
/// offline-fragile, so this never throws: a failure means "no name", and the
/// callers fall back to showing the coordinates' city-less label they already
/// had.
///
/// Returns null for a [fallbackUserPosition], because naming a made-up
/// coordinate would tell the user they are somewhere they are not.
Future<String?> resolvePlaceName(Position position) async {
  if (isFallbackUserPosition(position)) {
    return null;
  }

  return resolvePlaceNameForCoordinates(position.latitude, position.longitude);
}

/// Same lookup for a plain coordinate pair, used for restaurants, which carry
/// no address of their own.
///
/// 0,0 is the "no fix seeded" marker rather than a place, so it returns null
/// instead of naming the Atlantic.
Future<String?> resolvePlaceNameForCoordinates(
  double latitude,
  double longitude,
) async {
  if (!hasMapFix(latitude, longitude)) {
    return null;
  }

  try {
    // geocoding 5.x dropped the top-level functions for an instance API.
    final placemarks = await Geocoding()
        .placemarkFromCoordinates(latitude, longitude)
        .timeout(const Duration(seconds: 8));

    if (placemarks.isEmpty) {
      return null;
    }
    return formatPlaceName(placemarks.first);
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    return null;
  }
}

/// Picks the neighbourhood + city pair out of a placemark.
///
/// Malaysian reverse-geocode results put the neighbourhood ("Peserai") in
/// `subLocality` and the town ("Batu Pahat") in `locality`, but either can be
/// blank, so this walks a preference order and never emits a lone comma or a
/// duplicated part ("Batu Pahat, Batu Pahat").
String? formatPlaceName(Placemark placemark) {
  final local = _firstNonEmpty([
    placemark.subLocality,
    placemark.locality,
    placemark.subAdministrativeArea,
  ]);
  final region = _firstNonEmpty([
    placemark.locality,
    placemark.subAdministrativeArea,
    placemark.administrativeArea,
    placemark.country,
  ]);

  if (local == null) {
    return region;
  }
  if (region == null || region.toLowerCase() == local.toLowerCase()) {
    return local;
  }
  return '$local, $region';
}

String? _firstNonEmpty(List<String?> candidates) {
  for (final candidate in candidates) {
    final text = candidate?.trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
  }
  return null;
}
