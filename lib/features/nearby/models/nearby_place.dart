import '../../restaurants/models/restaurant.dart';

/// One row of `get_nearby`: a restaurant plus the two things only the server
/// can answer — how far it is from the origin the query used, and whether it
/// is open at the server's idea of now.
///
/// The distance is not recomputed on the client: the map, the results bar and
/// the badge all quote the number the ordering was done with, so a pin can
/// never say "1.2 km" while sitting behind one that says "1.4 km".
class NearbyPlace {
  const NearbyPlace({
    required this.restaurant,
    required this.distanceKm,
    this.openNow,
    this.swiped = false,
  });

  factory NearbyPlace.fromJson(Map<String, dynamic> json) {
    return NearbyPlace(
      restaurant: Restaurant.fromJson(json),
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      openNow: json['open_now'] as bool?,
      // Defensive: an older `get_nearby` has no such column, and a map that
      // re-deals a swiped place is a smaller wrong than a map that hands the
      // deck nothing at all.
      swiped: json['swiped'] == true,
    );
  }

  final Restaurant restaurant;
  final double distanceKm;

  /// Null when the caption never said when the place opens.
  final bool? openNow;

  /// True when the caller has already swiped this restaurant — liked, passed
  /// or saved for later. The pin is drawn either way; "Swipe all" skips it, so
  /// the deck is never handed cards it has already shown (D117).
  final bool swiped;

  int get id => restaurant.id;

  /// The pin's cover photo, or null when the row has no image yet — roughly
  /// half the catalogue, so the placeholder is the common case.
  String? get coverUrl =>
      restaurant.imageUrls.isEmpty ? null : restaurant.imageUrls.first;
}
