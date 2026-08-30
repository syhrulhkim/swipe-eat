import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/profile/data/profile_repository.dart';

class LocationCall {
  const LocationCall(this.latitude, this.longitude, this.placeName);

  final double latitude;
  final double longitude;
  final String? placeName;
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

  @override
  Future<AppUser> updateSearchRadius(int? radiusKm) async {
    radiusCalls.add(radiusKm);
    if (fail) {
      throw Exception('write refused');
    }
    return user = AppUser(
      id: user.id,
      name: user.name,
      email: user.email,
      avatarUrl: user.avatarUrl,
      onboardedAt: user.onboardedAt,
      searchRadiusKm: radiusKm,
      lastPlaceName: user.lastPlaceName,
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
  final List<({double? latitude, double? longitude, String? placeName})>
      passportCalls = [];

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
    return user = AppUser(
      id: user.id,
      name: user.name,
      email: user.email,
      avatarUrl: user.avatarUrl,
      onboardedAt: user.onboardedAt,
      searchRadiusKm: user.searchRadiusKm,
      lastPlaceName: user.lastPlaceName,
      filterCuisineIds: cuisineIds,
      filterDietaryTagIds: dietaryTagIds,
      filterMinRating: minRating,
      passportLatitude: user.passportLatitude,
      passportLongitude: user.passportLongitude,
      passportPlaceName: user.passportPlaceName,
    );
  }

  @override
  Future<AppUser> setPassport({
    double? latitude,
    double? longitude,
    String? placeName,
  }) async {
    passportCalls.add((
      latitude: latitude,
      longitude: longitude,
      placeName: placeName,
    ));
    if (fail) {
      throw Exception('write refused');
    }
    return user = AppUser(
      id: user.id,
      name: user.name,
      email: user.email,
      avatarUrl: user.avatarUrl,
      onboardedAt: user.onboardedAt,
      searchRadiusKm: user.searchRadiusKm,
      lastPlaceName: user.lastPlaceName,
      filterCuisineIds: user.filterCuisineIds,
      filterDietaryTagIds: user.filterDietaryTagIds,
      filterMinRating: user.filterMinRating,
      passportLatitude: latitude,
      passportLongitude: longitude,
      passportPlaceName: latitude == null ? null : placeName,
    );
  }
}
