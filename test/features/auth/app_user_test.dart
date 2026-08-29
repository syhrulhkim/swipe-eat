import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';

void main() {
  group('AppUser.fromProfile', () {
    test('parses the radius and place name off the profile row', () {
      final user = AppUser.fromProfile(const {
        'id': '39c39a30-c8fb-4e08-8e13-c90212f68e59',
        'name': 'Aisyah',
        'search_radius_km': 10,
        'last_place_name': 'Peserai, Batu Pahat',
      });

      expect(user.searchRadiusKm, 10);
      expect(user.lastPlaceName, 'Peserai, Batu Pahat');
    });

    test('a null radius means no limit and an empty place name means none',
        () {
      final user = AppUser.fromProfile(const {
        'id': '39c39a30-c8fb-4e08-8e13-c90212f68e59',
        'search_radius_km': null,
        'last_place_name': '  ',
      });

      expect(user.searchRadiusKm, isNull);
      expect(user.lastPlaceName, isNull);
    });
  });
}
