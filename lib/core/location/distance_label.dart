import 'package:geolocator/geolocator.dart';

/// The one wording for "how far away" across browse surfaces.
///
/// No fix yet, or a restaurant with no coordinates, reads as the city rather
/// than a number that would be a guess. (0,0) is the scraper's "unknown", not
/// a place in the Gulf of Guinea.
String distanceLabelFrom(
  Position? position, {
  required double latitude,
  required double longitude,
}) {
  if (position == null || (latitude == 0 && longitude == 0)) {
    return 'Johor Bahru';
  }

  final meters = Geolocator.distanceBetween(
    position.latitude,
    position.longitude,
    latitude,
    longitude,
  );

  if (meters >= 100000) {
    return '100 km +';
  }

  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  return '${meters.toStringAsFixed(0)} m away';
}
