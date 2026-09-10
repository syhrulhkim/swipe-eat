import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/nearby_place.dart';

/// A pair of coordinates the map can centre on.
class NearbyOrigin {
  const NearbyOrigin(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// Everything the Nearby map asks the server for.
class NearbyRepository {
  NearbyRepository({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;

  /// Resolved per call rather than in the constructor, so the tab can be built
  /// in a test without an initialised `Supabase.instance`.
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  static const _timeout = Duration(seconds: 15);

  /// The pins: active, geocoded restaurants inside [radiusKm], closest first,
  /// each carrying its distance and its open-now answer.
  ///
  /// The RPC returns images, dishes and reviews as jsonb in the shape
  /// `Restaurant.fromJson` reads, so there is no `.select()` here and no
  /// second round trip — see `docs/Features/Nearby-Map.md`.
  Future<List<NearbyPlace>> fetchNearby({
    required double latitude,
    required double longitude,
    required double radiusKm,
    int limit = 60,
  }) async {
    final rows = await _client.rpc<dynamic>('get_nearby', params: {
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_radius_km': radiusKm,
      'p_limit': limit,
    }).timeout(_timeout) as List<dynamic>;

    return rows
        .map((row) => NearbyPlace.fromJson(row as Map<String, dynamic>))
        .toList();
  }

}
