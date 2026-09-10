import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/nearby/data/nearby_repository.dart';
import 'package:swipe_eat/features/nearby/models/nearby_place.dart';
import 'package:swipe_eat/features/restaurants/domain/opening_hours.dart';
import 'package:swipe_eat/features/restaurants/models/restaurant.dart';

/// One recorded `get_nearby` call, so a test can assert the radius the
/// stepper actually queried with rather than only the number on screen.
class NearbyQuery {
  const NearbyQuery(this.latitude, this.longitude, this.radiusKm, this.limit);

  final double latitude;
  final double longitude;
  final double radiusKm;
  final int limit;
}

/// Stands in for the Supabase-backed repository. `implements` rather than
/// extends, so an interface change breaks the fake instead of silently
/// diverging from it (D69).
class FakeNearbyRepository implements NearbyRepository {
  FakeNearbyRepository();

  /// Returned for every radius unless [rowsByRadius] names that radius.
  List<NearbyPlace> rows = const [];

  /// Per-radius answers, for a test that widens the circle and expects more.
  Map<double, List<NearbyPlace>> rowsByRadius = const {};

  bool fail = false;

  /// Gates [fetchNearby] so a test can hold a load open — dispose the
  /// controller mid-flight, then let the answer arrive.
  Completer<void>? gate;

  final List<NearbyQuery> queries = [];

  @override
  Future<List<NearbyPlace>> fetchNearby({
    required double latitude,
    required double longitude,
    required double radiusKm,
    int limit = 60,
  }) async {
    queries.add(NearbyQuery(latitude, longitude, radiusKm, limit));
    final gate = this.gate;
    if (gate != null) {
      await gate.future;
    }
    if (fail) {
      throw Exception('nearby unavailable');
    }
    return rowsByRadius[radiusKm] ?? rows;
  }
}

/// A real device fix, for the "we know where you are" path.
Position testPosition({double latitude = 1.4655, double longitude = 103.7578}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.utc(2026, 9, 5, 11, 41),
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

/// A [NearbyPlace] with just enough on it to paint a pin.
NearbyPlace testPlace(
  int id, {
  String? name,
  String tag = 'Kaya toast',
  required double distanceKm,
  bool? openNow,
  bool swiped = false,
  int? priceFrom,
  OpeningHours hours = OpeningHours.unknown,
  List<String> imageUrls = const [],
  double latitude = 1.4655,
  double longitude = 103.7578,
}) {
  return NearbyPlace(
    distanceKm: distanceKm,
    openNow: openNow,
    swiped: swiped,
    restaurant: Restaurant(
      id: id,
      name: name ?? 'Place $id',
      tag: tag,
      details: '',
      brandColor: kBrandColorFallback,
      rating: 0,
      latitude: latitude,
      longitude: longitude,
      imageUrls: imageUrls,
      reviews: const [],
      hours: hours,
      priceFrom: priceFrom,
    ),
  );
}
