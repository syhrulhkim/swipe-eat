import 'package:supabase_flutter/supabase_flutter.dart';

/// The signed-in account, assembled from the Supabase auth user plus the
/// `public.profiles` row the `handle_new_user` trigger creates for it.
///
/// [id] is the auth uuid, so it is the same value RLS compares against
/// (`auth.uid()`) and the same value every `profile_id` / `user_id` column
/// stores.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.onboardedAt,
    this.searchRadiusKm,
    this.lastPlaceName,
    this.filterCuisineIds = const [],
    this.filterDietaryTagIds = const [],
    this.filterMinRating,
    this.passportLatitude,
    this.passportLongitude,
    this.passportPlaceName,
  });

  final String id;
  final String name;
  final String email;
  final String? avatarUrl;

  /// Null until the onboarding wizard has been completed once. The router
  /// gate reads this, so it is the single source of truth for "has this
  /// account been set up" — and it lives in the database, which is why a
  /// reinstall does not re-run the wizard.
  final DateTime? onboardedAt;

  /// The Settings hard filter: only restaurants within this many km are
  /// served by the deck and Explore. Null means "no limit".
  final int? searchRadiusKm;

  /// Reverse-geocoded name of the last stored fix ("Peserai, Batu Pahat"),
  /// shown in the deck's header chip. Null until a real fix has been synced.
  final String? lastPlaceName;

  /// Discovery filters — hard limits the deck applies server-side. Empty
  /// lists and a null rating mean "filter off".
  final List<int> filterCuisineIds;
  final List<int> filterDietaryTagIds;
  final double? filterMinRating;

  /// Passport: a manually pinned location that beats the GPS fix while set.
  /// All three null when the passport is off.
  final double? passportLatitude;
  final double? passportLongitude;
  final String? passportPlaceName;

  bool get needsOnboarding => onboardedAt == null;

  bool get hasPassport => passportLatitude != null && passportLongitude != null;

  /// How many discovery constraints are switched on — the filter button's
  /// badge.
  int get activeFilterCount =>
      (filterCuisineIds.isEmpty ? 0 : 1) +
      (filterDietaryTagIds.isEmpty ? 0 : 1) +
      (filterMinRating == null ? 0 : 1);

  /// Builds the user from a `profiles` row, falling back to the auth record
  /// for anything the profile has not been given yet (a fresh OAuth signup
  /// arrives with its name and photo only in `user_metadata`).
  factory AppUser.fromProfile(Map<String, dynamic> row, {User? authUser}) {
    final metadata = authUser?.userMetadata ?? const <String, dynamic>{};

    return AppUser(
      id: _string(row['id']) ?? authUser?.id ?? '',
      name: _firstNonEmpty([
            _string(row['name']),
            _string(metadata['name']),
            _string(metadata['full_name']),
          ]) ??
          'User',
      // `profiles` deliberately has no email column — the address lives in
      // `auth.users`, which only GoTrue may write.
      email: _firstNonEmpty([authUser?.email]) ?? '',
      avatarUrl: _firstNonEmpty([
        _string(row['avatar_url']),
        _string(metadata['avatar_url']),
        _string(metadata['picture']),
      ]),
      onboardedAt: _dateTime(row['onboarded_at']),
      searchRadiusKm: _int(row['search_radius_km']),
      lastPlaceName: _string(row['last_place_name']),
      filterCuisineIds: _intList(row['filter_cuisine_ids']),
      filterDietaryTagIds: _intList(row['filter_dietary_tag_ids']),
      filterMinRating: _double(row['filter_min_rating']),
      passportLatitude: _double(row['passport_latitude']),
      passportLongitude: _double(row['passport_longitude']),
      passportPlaceName: _string(row['passport_place_name']),
    );
  }

  /// Rebuilds a user from [toCache]. Separate from [AppUser.fromProfile]
  /// because the cache stores the assembled user — email included, which the
  /// `profiles` row does not have.
  factory AppUser.fromCache(Map<String, dynamic> json) {
    return AppUser(
      id: _string(json['id']) ?? '',
      name: _string(json['name']) ?? 'User',
      email: _string(json['email']) ?? '',
      avatarUrl: _string(json['avatar_url']),
      onboardedAt: _dateTime(json['onboarded_at']),
      searchRadiusKm: _int(json['search_radius_km']),
      lastPlaceName: _string(json['last_place_name']),
      filterCuisineIds: _intList(json['filter_cuisine_ids']),
      filterDietaryTagIds: _intList(json['filter_dietary_tag_ids']),
      filterMinRating: _double(json['filter_min_rating']),
      passportLatitude: _double(json['passport_latitude']),
      passportLongitude: _double(json['passport_longitude']),
      passportPlaceName: _string(json['passport_place_name']),
    );
  }

  Map<String, dynamic> toCache() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'avatar_url': avatarUrl,
      'onboarded_at': onboardedAt?.toIso8601String(),
      'search_radius_km': searchRadiusKm,
      'last_place_name': lastPlaceName,
      'filter_cuisine_ids': filterCuisineIds,
      'filter_dietary_tag_ids': filterDietaryTagIds,
      'filter_min_rating': filterMinRating,
      'passport_latitude': passportLatitude,
      'passport_longitude': passportLongitude,
      'passport_place_name': passportPlaceName,
    };
  }

  /// Null keeps the current value. Clearing a nullable field (radius back to
  /// "no limit") never goes through here — the RPCs return the whole profile
  /// row, so writers rebuild via [AppUser.fromProfile] instead.
  AppUser copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    DateTime? onboardedAt,
    int? searchRadiusKm,
    String? lastPlaceName,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      onboardedAt: onboardedAt ?? this.onboardedAt,
      searchRadiusKm: searchRadiusKm ?? this.searchRadiusKm,
      lastPlaceName: lastPlaceName ?? this.lastPlaceName,
      // Filters and passport only change through RPCs that return the whole
      // profile row, so copyWith always carries them through unchanged.
      filterCuisineIds: filterCuisineIds,
      filterDietaryTagIds: filterDietaryTagIds,
      filterMinRating: filterMinRating,
      passportLatitude: passportLatitude,
      passportLongitude: passportLongitude,
      passportPlaceName: passportPlaceName,
    );
  }

  static String? _string(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? _firstNonEmpty(List<String?> candidates) {
    for (final candidate in candidates) {
      final text = candidate?.trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  static int? _int(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num && value.isFinite) {
      return value.toInt();
    }
    return null;
  }

  static double? _double(Object? value) {
    if (value is num && value.isFinite) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static List<int> _intList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return [
      for (final item in value)
        if (item is num) item.toInt(),
    ];
  }

  static DateTime? _dateTime(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}
