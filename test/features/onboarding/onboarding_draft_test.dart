import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/onboarding/models/onboarding_draft.dart';

void main() {
  group('OnboardingDraft', () {
    test('defaults match the profile defaults in the database', () {
      final draft = OnboardingDraft();

      expect(draft.morningMode, isTrue);
      expect(draft.spiceBias, SpiceBias.high);
      expect(draft.nearbyFocus, isTrue);
      expect(draft.radiusKm, isNull, reason: 'no limit by default');
      expect(draft.locationSource, LocationSource.unknown);
    });

    test('gates step one on a name and step two on a cuisine', () {
      final draft = OnboardingDraft();
      expect(draft.hasName, isFalse);
      expect(draft.hasTaste, isFalse);

      draft
        ..name = '  Aisyah  '
        ..toggleCuisine(3);

      expect(draft.hasName, isTrue);
      expect(draft.hasTaste, isTrue);
    });

    test('toggling a cuisine twice removes it', () {
      final draft = OnboardingDraft()
        ..toggleCuisine(3)
        ..toggleCuisine(3);

      expect(draft.cuisineIds, isEmpty);
    });

    test('always sends p_radius_km, including when it is null', () {
      final params = OnboardingDraft(name: 'A').toRpcParams();

      // complete_onboarding assigns search_radius_km unconditionally so that
      // "No limit" can clear a stored value. Omitting the key would therefore
      // clear the radius by accident rather than leave it alone.
      expect(params.containsKey('p_radius_km'), isTrue);
      expect(params['p_radius_km'], isNull);
    });

    test('serialises the answers the RPC expects', () {
      final draft = OnboardingDraft(name: '  Aisyah ')
        ..toggleCuisine(5)
        ..toggleCuisine(2)
        ..toggleDietary(1)
        ..morningMode = false
        ..spiceBias = SpiceBias.low
        ..nearbyFocus = false
        ..radiusKm = 10
        ..latitude = 1.85
        ..longitude = 102.93
        ..placeName = 'Peserai, Batu Pahat'
        ..locationSource = LocationSource.gps;

      expect(draft.toRpcParams(), {
        'p_name': 'Aisyah',
        'p_cuisine_ids': [2, 5],
        'p_dietary_ids': [1],
        'p_morning_mode': false,
        'p_spice_bias': 'low',
        'p_nearby_focus': false,
        'p_radius_km': 10,
        'p_latitude': 1.85,
        'p_longitude': 102.93,
        'p_place_name': 'Peserai, Batu Pahat',
        'p_location_source': 'gps',
      });
    });

    test('spice bias cycles through every value and wraps', () {
      expect(SpiceBias.low.next, SpiceBias.medium);
      expect(SpiceBias.medium.next, SpiceBias.high);
      expect(SpiceBias.high.next, SpiceBias.low);
    });

    test('an unknown spice_bias from the database falls back to high', () {
      expect(SpiceBias.fromValue('scorching'), SpiceBias.high);
      expect(SpiceBias.fromValue(null), SpiceBias.high);
      expect(SpiceBias.fromValue('medium'), SpiceBias.medium);
    });
  });
}
