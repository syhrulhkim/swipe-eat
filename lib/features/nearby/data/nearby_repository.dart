import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/nearby_place.dart';

/// A pair of coordinates the map can centre on.
class NearbyOrigin {
  const NearbyOrigin(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// The two coordinate pairs a profile row can carry: the passport pin the user
/// dropped on purpose, and the fix the app last stored for them.
///
/// Both come back from one read, because the map needs to know about the
/// passport *before* it asks the device where it is — a pin the user set beats
/// a fix they did not (D12).
class NearbyProfileOrigins {
  const NearbyProfileOrigins({this.passport, this.stored});

  static const NearbyProfileOrigins none = NearbyProfileOrigins();

  /// `profiles.passport_latitude/longitude`: "show me this city instead".
  final NearbyOrigin? passport;

  /// `profiles.last_latitude/longitude`: where the app last saw the user.
  final NearbyOrigin? stored;
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

  /// The coordinates the profile carries: the passport pin, and the fix the
  /// app last stored for a user who has never granted location on this device.
  /// `(0, 0)` — the scraper's "no coordinates" — counts as neither.
  ///
  /// Read here rather than off [AppUser] because the profile row carries the
  /// coordinates and the auth model deliberately does not: the passport fields
  /// have no client model at all since D84, and the map is the only screen
  /// that needs any of them.
  Future<NearbyProfileOrigins> profileOrigins() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return NearbyProfileOrigins.none;
    }

    final rows = await _client
        .from('profiles')
        .select(
          'passport_latitude, passport_longitude, '
          'last_latitude, last_longitude',
        )
        .eq('id', userId)
        .limit(1)
        .timeout(_timeout);

    if (rows.isEmpty) {
      return NearbyProfileOrigins.none;
    }

    final row = rows.first;
    return NearbyProfileOrigins(
      passport: _origin(row['passport_latitude'], row['passport_longitude']),
      stored: _origin(row['last_latitude'], row['last_longitude']),
    );
  }

  static NearbyOrigin? _origin(Object? latitude, Object? longitude) {
    final lat = (latitude as num?)?.toDouble();
    final lng = (longitude as num?)?.toDouble();
    if (lat == null || lng == null || (lat == 0 && lng == 0)) {
      return null;
    }
    return NearbyOrigin(lat, lng);
  }
}
