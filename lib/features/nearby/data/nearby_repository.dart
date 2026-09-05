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

  /// The coordinates the profile last stored, for a user who has never granted
  /// location on this device. Null when the account has no fix yet, or when it
  /// stored the scraper's (0,0) sentinel.
  ///
  /// Read here rather than off [AppUser] because the profile row carries the
  /// coordinates and the auth model deliberately does not — the map is the
  /// only screen that needs them on the client.
  Future<NearbyOrigin?> storedOrigin() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }

    final rows = await _client
        .from('profiles')
        .select('last_latitude, last_longitude')
        .eq('id', userId)
        .limit(1)
        .timeout(_timeout);

    if (rows.isEmpty) {
      return null;
    }

    final latitude = (rows.first['last_latitude'] as num?)?.toDouble();
    final longitude = (rows.first['last_longitude'] as num?)?.toDouble();
    if (latitude == null ||
        longitude == null ||
        (latitude == 0 && longitude == 0)) {
      return null;
    }

    return NearbyOrigin(latitude, longitude);
  }
}
