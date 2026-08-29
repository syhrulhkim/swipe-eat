import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/single_row.dart';
import '../../auth/models/app_user.dart';

/// Profile writes outside the onboarding wizard: the stored location behind
/// the header chip, and the preference fields Settings/Profile edit. Every
/// RPC returns the whole updated `profiles` row, so callers can hand the
/// fresh [AppUser] straight to `AuthController.applyUser` without a re-read.
class ProfileRepository {
  ProfileRepository({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;

  /// Lazy for the same reason as the other repositories: construction must
  /// not assert on an uninitialised `Supabase.instance`.
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  static const _timeout = Duration(seconds: 15);

  /// Persists a real GPS fix (and its reverse-geocoded name), so the deck,
  /// Explore and the header chip all agree on where the user is — including
  /// on their next device.
  Future<AppUser> updateLocation({
    required double latitude,
    required double longitude,
    String? placeName,
  }) {
    return _rpc('update_location', {
      'p_latitude': latitude,
      'p_longitude': longitude,
      if (placeName != null) 'p_place_name': placeName,
      'p_source': 'gps',
    });
  }

  /// The Settings radius. Null means "no limit", which needs the explicit
  /// clear flag — `p_radius_km: null` would read as "keep the current value".
  Future<AppUser> updateSearchRadius(int? radiusKm) {
    return _rpc('update_preferences', {
      if (radiusKm != null) 'p_radius_km': radiusKm,
      'p_clear_radius': radiusKm == null,
    });
  }

  Future<AppUser> _rpc(String function, Map<String, dynamic> params) async {
    final response =
        await _client.rpc<dynamic>(function, params: params).timeout(_timeout);

    return AppUser.fromProfile(
      asSingleRow(response),
      authUser: _client.auth.currentUser,
    );
  }
}
