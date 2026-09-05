import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/profile/data/profile_repository.dart';

class LocationCall {
  const LocationCall(this.latitude, this.longitude, this.placeName);

  final double latitude;
  final double longitude;
  final String? placeName;
}

/// What one `update_preferences` call carried. Recorded rather than folded
/// into [FakeProfileRepository.user] so a test can assert that a sheet sent
/// *only* the field it edits.
class PreferenceCall {
  const PreferenceCall({
    this.halalOnly,
    this.vegetarian,
    this.spiceLevel,
    this.budgetMin,
    this.budgetMax,
    this.clearBudget = false,
  });

  final bool? halalOnly;
  final bool? vegetarian;
  final int? spiceLevel;
  final int? budgetMin;
  final int? budgetMax;
  final bool clearBudget;
}

/// Plays the `update_preferences` / `update_location` RPCs: applies the write
/// to [user] and returns the whole updated profile, the way the real
/// functions return the `profiles` row.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository(this.user);

  AppUser user;
  bool fail = false;

  final List<int?> radiusCalls = [];
  final List<LocationCall> locationCalls = [];
  final List<PreferenceCall> preferenceCalls = [];

  /// Rebuilds the stored user with a handful of fields replaced.
  ///
  /// One place, so a field added to [AppUser] cannot be silently dropped by
  /// three separate constructor calls that nobody remembered to update.
  AppUser _with({
    int? searchRadiusKm,
    bool setRadius = false,
    String? lastPlaceName,
    List<int>? filterCuisineIds,
    List<int>? filterDietaryTagIds,
    double? filterMinRating,
    bool setMinRating = false,
    bool? halalOnly,
    bool? vegetarian,
    int? spiceLevel,
    int? budgetMin,
    int? budgetMax,
    bool clearBudget = false,
  }) {
    return AppUser(
      id: user.id,
      name: user.name,
      email: user.email,
      avatarUrl: user.avatarUrl,
      onboardedAt: user.onboardedAt,
      searchRadiusKm: setRadius ? searchRadiusKm : user.searchRadiusKm,
      lastPlaceName: lastPlaceName ?? user.lastPlaceName,
      filterCuisineIds: filterCuisineIds ?? user.filterCuisineIds,
      filterDietaryTagIds: filterDietaryTagIds ?? user.filterDietaryTagIds,
      filterMinRating:
          setMinRating ? filterMinRating : user.filterMinRating,
      createdAt: user.createdAt,
      halalOnly: halalOnly ?? user.halalOnly,
      vegetarian: vegetarian ?? user.vegetarian,
      spiceLevel: spiceLevel ?? user.spiceLevel,
      budgetMin: clearBudget ? null : (budgetMin ?? user.budgetMin),
      // The real RPC treats the two ends as a pair: a new floor carries its
      // own ceiling, null included.
      budgetMax: clearBudget
          ? null
          : budgetMin != null
              ? budgetMax
              : (budgetMax ?? user.budgetMax),
    );
  }

  @override
  Future<AppUser> updateSearchRadius(int? radiusKm) async {
    radiusCalls.add(radiusKm);
    if (fail) {
      throw Exception('write refused');
    }
    return user = _with(searchRadiusKm: radiusKm, setRadius: true);
  }

  @override
  Future<AppUser> updatePreferences({
    bool? halalOnly,
    bool? vegetarian,
    int? spiceLevel,
    int? budgetMin,
    int? budgetMax,
    bool clearBudget = false,
  }) async {
    preferenceCalls.add(PreferenceCall(
      halalOnly: halalOnly,
      vegetarian: vegetarian,
      spiceLevel: spiceLevel,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      clearBudget: clearBudget,
    ));
    if (fail) {
      throw Exception('write refused');
    }
    return user = _with(
      halalOnly: halalOnly,
      vegetarian: vegetarian,
      spiceLevel: spiceLevel,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      clearBudget: clearBudget,
    );
  }

  @override
  Future<AppUser> updateLocation({
    required double latitude,
    required double longitude,
    String? placeName,
  }) async {
    locationCalls.add(LocationCall(latitude, longitude, placeName));
    if (fail) {
      throw Exception('write refused');
    }
    return user = user.copyWith(lastPlaceName: placeName);
  }

  final List<({List<int> cuisineIds, List<int> dietaryTagIds, double? minRating})>
      filterCalls = [];

  @override
  Future<AppUser> setDiscoveryFilters({
    required List<int> cuisineIds,
    required List<int> dietaryTagIds,
    double? minRating,
  }) async {
    filterCalls.add((
      cuisineIds: cuisineIds,
      dietaryTagIds: dietaryTagIds,
      minRating: minRating,
    ));
    if (fail) {
      throw Exception('write refused');
    }
    return user = _with(
      filterCuisineIds: cuisineIds,
      filterDietaryTagIds: dietaryTagIds,
      filterMinRating: minRating,
      setMinRating: true,
    );
  }
}
