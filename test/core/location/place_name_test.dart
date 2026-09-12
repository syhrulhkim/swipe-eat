import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:swipe_eat/core/location/open_directions.dart';
import 'package:swipe_eat/core/location/place_name.dart';

void main() {
  group('formatPlaceName', () {
    test('pairs the neighbourhood with the town', () {
      expect(
        formatPlaceName(
          const Placemark(subLocality: 'Peserai', locality: 'Batu Pahat'),
        ),
        'Peserai, Batu Pahat',
      );
    });

    test('never says the same town twice, whatever its casing', () {
      expect(
        formatPlaceName(
          const Placemark(subLocality: 'BATU PAHAT', locality: 'Batu Pahat'),
        ),
        'BATU PAHAT',
      );
    });

    test('a blank subLocality is no neighbourhood at all', () {
      // Blank rather than absent: the OS returns whitespace often enough that
      // a null check alone would emit ", Batu Pahat". The town then answers
      // for both halves, so it is said once — the state is never reached.
      expect(
        formatPlaceName(
          const Placemark(
            subLocality: '   ',
            locality: 'Batu Pahat',
            administrativeArea: 'Johor',
          ),
        ),
        'Batu Pahat',
      );
    });

    test('the state names the place only when the town has no name', () {
      expect(
        formatPlaceName(
          const Placemark(
            subLocality: 'Peserai',
            administrativeArea: 'Johor',
          ),
        ),
        'Peserai, Johor',
      );
    });

    test('with no local part it falls back to the widest name it has', () {
      expect(
        formatPlaceName(const Placemark(country: 'Malaysia')),
        'Malaysia',
      );
    });

    test('a placemark with nothing in it names nowhere', () {
      expect(formatPlaceName(const Placemark()), isNull);
    });
  });

  group('hasMapFix', () {
    test('0,0 is the unseeded marker, not the Atlantic', () {
      expect(hasMapFix(0, 0), isFalse);
    });

    test('a real coordinate is a fix, and so is one axis of it', () {
      expect(hasMapFix(1.85, 102.93), isTrue);
      expect(hasMapFix(0, 102.93), isTrue);
      expect(hasMapFix(1.85, 0), isTrue);
    });
  });
}
