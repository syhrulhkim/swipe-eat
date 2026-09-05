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

/// How hot the user wants it. The stored truth is this 1–4 level (D104);
/// `spice_bias` is derived from it server-side so the deck's existing
/// three-way term keeps scoring without a second migration.
///
/// Four steps, not three, because the fourth ("Bring it") is the one people
/// pick to say something about themselves — collapsing it into "high" on the
/// way in would throw that away before it was ever stored.
enum SpiceLevel {
  mild(1, 'Mild'),
  medium(2, 'Medium'),
  pedas(3, 'Pedas'),
  bringIt(4, 'Bring it');

  const SpiceLevel(this.level, this.label);

  /// The value written to `profiles.spice_level`.
  final int level;
  final String label;

  static SpiceLevel? fromLevel(int? level) {
    if (level == null) {
      return null;
    }
    for (final value in SpiceLevel.values) {
      if (value.level == level) {
        return value;
      }
    }
    return null;
  }
}

/// The budget control's stops: RM 5 to RM 100 in fives.
const int kBudgetFloor = 5;
const int kBudgetCeiling = 100;
const int kBudgetStep = 5;

/// Where the range opens before it is touched, as the prototype shows it:
/// "RM 10–40".
const int kBudgetDefaultMin = 10;
const int kBudgetDefaultMax = 40;

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

  /// "Any rules?" — the diet and budget step. Every one of these is optional,
  /// because the step is skippable, so the defaults have to be answers nobody
  /// would mind having given: nothing hidden, no spice claimed, and the range
  /// the prototype opens on.
  bool halalOnly = false;
  bool vegetarian = false;
  SpiceLevel? spiceLevel;
  int? budgetMin = kBudgetDefaultMin;
  int? budgetMax = kBudgetDefaultMax;

  /// Skip is an answer too, and it is not the same answer as the defaults
  /// sitting on screen. Clearing the budget is the whole difference —
  /// otherwise skipping would quietly cap a stranger's deck at RM 40.
  void clearRules() {
    halalOnly = false;
    vegetarian = false;
    spiceLevel = null;
    budgetMin = null;
    budgetMax = null;
  }

  /// The read-out over the range control.
  String get budgetLabel => budgetRangeLabel(budgetMin, budgetMax);

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
      'p_halal_only': halalOnly,
      'p_vegetarian': vegetarian,
      'p_spice_level': spiceLevel?.level,
      'p_budget_min': budgetMin,
      'p_budget_max': budgetMax,
      // Mirrors `p_clear_radius`. The function cannot tell "no answer" from
      // "leave it alone" by looking at a null, so the wizard says which it
      // means rather than letting the default decide.
      'p_clear_budget': budgetMin == null && budgetMax == null,
    };
  }
}

/// "RM 10–40", "RM 10+" or "Any" — one spelling of a budget across the wizard,
/// the You tab and Settings, so the three never disagree about what is stored.
///
/// An upper end at [kBudgetCeiling] is "and up", not a RM 100 cap: hiding the
/// handful of places that cost more from someone who just said money is not
/// the issue would be the opposite of what they answered.
String budgetRangeLabel(int? min, int? max) {
  if (min == null) {
    return 'Any';
  }
  if (max == null || max >= kBudgetCeiling) {
    return 'RM $min+';
  }
  return 'RM $min–$max';
}
