import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/location/user_location.dart';

void main() {
  group('fallbackUserPosition', () {
    test('sits at Peserai, Batu Pahat', () {
      final position = fallbackUserPosition();

      expect(position.latitude, closeTo(1.85, 1e-6));
      expect(position.longitude, closeTo(102.933333, 1e-6));
    });

    test('is flagged as mocked with zeroed sensor readings', () {
      final position = fallbackUserPosition();

      expect(position.isMocked, isTrue);
      expect(position.accuracy, 0);
      expect(position.altitude, 0);
      expect(position.heading, 0);
      expect(position.speed, 0);
      expect(position.timestamp, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('is usable as a distance origin against a seeded restaurant', () {
      final position = fallbackUserPosition();

      // Sanity check that the fallback is inside the Batu Pahat bounding box
      // the seeded restaurants live in, so distances stay plausible.
      expect(position.latitude, inInclusiveRange(1.7, 2.0));
      expect(position.longitude, inInclusiveRange(102.8, 103.1));
    });
  });
}
