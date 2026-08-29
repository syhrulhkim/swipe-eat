/// How spicy the deck should lean. Mirrors the `spice_bias` check constraint
/// on `public.profiles` — the strings must stay in sync with the database.
enum SpiceBias {
  low('low', 'Mild'),
  medium('medium', 'Medium'),
  high('high', 'High');

  const SpiceBias(this.value, this.label);

  final String value;
  final String label;

  static SpiceBias fromValue(String? value) {
    return SpiceBias.values.firstWhere(
      (bias) => bias.value == value,
      orElse: () => SpiceBias.high,
    );
  }

  /// Cycled by tapping the tile, so the three states need a ring order.
  SpiceBias get next => SpiceBias.values[(index + 1) % SpiceBias.values.length];
}

/// Where the coordinates on the profile came from. `denied` is a real answer,
/// not a failure: it tells the ranking to score without proximity instead of
/// waiting for a fix that will never arrive.
enum LocationSource {
  gps('gps'),
  denied('denied'),
  unknown('unknown');

  const LocationSource(this.value);

  final String value;
}

/// The wizard's in-memory answers.
///
/// Nothing here is written until the last step, so abandoning halfway leaves
/// the account exactly as it was — `onboarded_at` stays null and the router
/// gate simply re-runs the wizard on the next launch.
class OnboardingDraft {
  OnboardingDraft({String name = ''}) : name = name.trim();

  String name;
  final Set<int> cuisineIds = <int>{};
  final Set<int> dietaryIds = <int>{};

  bool morningMode = true;
  SpiceBias spiceBias = SpiceBias.high;
  bool nearbyFocus = true;

  /// Null means "no limit" — the deck then ranks by distance without ever
  /// filtering a place out for being far. That is the default because only one
  /// seeded restaurant sits within 10 km of the fallback origin; shipping a
  /// radius by default would hand a new user an all-but-empty deck.
  int? radiusKm;

  double? latitude;
  double? longitude;
  String? placeName;
  LocationSource locationSource = LocationSource.unknown;

  /// Step 2 needs at least one cuisine: it is the only cold-start taste signal
  /// the ranking gets, and an empty set would score every restaurant alike.
  bool get hasTaste => cuisineIds.isNotEmpty;

  bool get hasName => name.trim().isNotEmpty;

  void toggleCuisine(int id) => _toggle(cuisineIds, id);

  void toggleDietary(int id) => _toggle(dietaryIds, id);

  static void _toggle(Set<int> set, int id) {
    if (!set.remove(id)) {
      set.add(id);
    }
  }

  /// The `complete_onboarding` argument list.
  ///
  /// `p_radius_km` is always present, including when null: the function
  /// assigns it unconditionally so that "No limit" can clear a previous value,
  /// which means omitting the key would silently clear the radius instead of
  /// leaving it alone.
  Map<String, dynamic> toRpcParams() {
    return <String, dynamic>{
      'p_name': name.trim(),
      'p_cuisine_ids': cuisineIds.toList()..sort(),
      'p_dietary_ids': dietaryIds.toList()..sort(),
      'p_morning_mode': morningMode,
      'p_spice_bias': spiceBias.value,
      'p_nearby_focus': nearbyFocus,
      'p_radius_km': radiusKm,
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_place_name': placeName,
      'p_location_source': locationSource.value,
    };
  }
}
