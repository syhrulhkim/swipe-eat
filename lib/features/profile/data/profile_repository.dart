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
  ///
  /// The name is always sent, null included: it belongs to *this* fix. Keeping
  /// the previous one when reverse geocoding fails would move the coordinates
  /// to a new town and leave the old town's name on the header.
  Future<AppUser> updateLocation({
    required double latitude,
    required double longitude,
    String? placeName,
  }) {
    return _rpc('update_location', {
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_place_name': placeName,
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

  /// The diet & budget answers, edited one row at a time from the You tab and
  /// from Settings. Every argument is optional and null means "leave it as it
  /// is", so a sheet that changes one thing sends one thing.
  ///
  /// The budget is the exception, and it is why [clearBudget] exists: the two
  /// ends move together. Sending [budgetMin] makes the pair authoritative, so
  /// a null [budgetMax] alongside it reads as "RM 10 and up" rather than as
  /// "keep the old ceiling". [clearBudget] is the only way back to "Any".
  Future<AppUser> updatePreferences({
    bool? halalOnly,
    bool? vegetarian,
    int? spiceLevel,
    int? budgetMin,
    int? budgetMax,
    bool clearBudget = false,
  }) {
    return _rpc('update_preferences', {
      if (halalOnly != null) 'p_halal_only': halalOnly,
      if (vegetarian != null) 'p_vegetarian': vegetarian,
      if (spiceLevel != null) 'p_spice_level': spiceLevel,
      if (budgetMin != null) 'p_budget_min': budgetMin,
      if (budgetMin != null) 'p_budget_max': budgetMax,
      if (clearBudget) 'p_clear_budget': true,
    });
  }

  /// The discovery filter sheet. Full overwrite on every call, matching the
  /// RPC's contract — and the RPC has no parameter defaults, so all three
  /// keys must always be sent, nulls included.
  Future<AppUser> setDiscoveryFilters({
    required List<int> cuisineIds,
    required List<int> dietaryTagIds,
    double? minRating,
  }) {
    return _rpc('set_discovery_filters', {
      'p_cuisine_ids': cuisineIds,
      'p_dietary_tag_ids': dietaryTagIds,
      'p_min_rating': minRating,
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
