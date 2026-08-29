import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/location/open_directions.dart';

void main() {
  group('directionsUris', () {
    test('asks Apple Maps for driving directions on iOS', () {
      final uris = directionsUris(
        latitude: 1.85,
        longitude: 102.933333,
        label: 'Mak Limah Asam Pedas',
        appleMaps: true,
      );

      expect(uris.first.host, 'maps.apple.com');
      expect(uris.first.queryParameters['daddr'], '1.85,102.933333');
      expect(uris.first.queryParameters['dirflg'], 'd');
      expect(uris.first.queryParameters['q'], 'Mak Limah Asam Pedas');
    });

    test('asks for turn-by-turn navigation elsewhere', () {
      final uris = directionsUris(
        latitude: 1.85,
        longitude: 102.933333,
        label: 'Warung Wak Jaferi',
        appleMaps: false,
      );

      // geo: would only drop a pin, so the button would not do what it says.
      expect(uris.first.scheme, 'google.navigation');
      expect(
        uris.first.toString(),
        'google.navigation:q=1.85,102.933333&mode=d',
      );
    });

    test('falls back to a web map that needs no maps app', () {
      final uris = directionsUris(
        latitude: 1.85,
        longitude: 102.933333,
        appleMaps: true,
      );

      expect(uris.length, 2);
      expect(uris.last.host, 'www.google.com');
      expect(uris.last.queryParameters['destination'], '1.85,102.933333');
    });

    test('omits the pin name when the label is blank', () {
      final uris = directionsUris(
        latitude: 1.85,
        longitude: 102.933333,
        label: '   ',
        appleMaps: true,
      );

      expect(uris.first.queryParameters.containsKey('q'), isFalse);
    });
  });

  group('openDirections', () {
    test('refuses a restaurant with no seeded fix', () async {
      // 0,0 would otherwise route the user into the Atlantic.
      expect(
        await openDirections(latitude: 0, longitude: 0),
        isFalse,
      );
    });
  });
}
