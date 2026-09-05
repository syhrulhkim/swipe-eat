import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/nearby/domain/nearby_format.dart';
import 'package:swipe_eat/features/restaurants/domain/opening_hours.dart';

OpeningHours _hours(String? opens, String? closes, {List<int> closed = const []}) {
  return OpeningHours.fromJson({
    'opens_at': opens,
    'closes_at': closes,
    'closed_dow': closed,
  });
}

void main() {
  group('formatNearbyDistance', () {
    test('reads metres under a kilometre, rounded to the nearest ten', () {
      expect(formatNearbyDistance(0.4503).label, '450 m');
      expect(formatNearbyDistance(0.6).label, '600 m');
      expect(formatNearbyDistance(0.8).label, '800 m');
      // A pin that claimed 447 m would claim an accuracy no phone fix has.
      expect(formatNearbyDistance(0.447).label, '450 m');
    });

    test('reads one decimal of a kilometre above it', () {
      expect(formatNearbyDistance(1.2).label, '1.2 km');
      expect(formatNearbyDistance(3.4).label, '3.4 km');
      expect(formatNearbyDistance(20).label, '20.0 km');
    });

    test('rounds up into kilometres rather than saying "1000 m"', () {
      expect(formatNearbyDistance(0.9996).label, '1.0 km');
    });

    test('splits the number from the unit, for the stepper', () {
      final half = formatNearbyDistance(0.5);
      expect(half.value, '500');
      expect(half.unit, 'm');

      final three = formatNearbyDistance(3);
      expect(three.value, '3.0');
      expect(three.unit, 'km');
    });
  });

  group('nearestNearbyRadiusStep', () {
    test('snaps the profile radius onto a step the stepper can leave', () {
      expect(nearestNearbyRadiusStep(3), 3);
      expect(nearestNearbyRadiusStep(6), 5);
      expect(nearestNearbyRadiusStep(100), 20);
      expect(nearestNearbyRadiusStep(0.1), 0.5);
    });

    test('a tie rounds down, never past what the user asked for', () {
      // 4 is equidistant from 3 and 5; 10 from 8 and 12.
      expect(nearestNearbyRadiusStep(4), 3);
      expect(nearestNearbyRadiusStep(10), 8);
    });
  });

  group('nearbyOpenLine', () {
    final tuesdayEvening = DateTime(2026, 9, 8, 19, 41);

    test('says nothing when the caption never gave the hours', () {
      expect(nearbyOpenLine(OpeningHours.unknown, tuesdayEvening), isNull);
    });

    test('an open place reads fresh', () {
      final line = nearbyOpenLine(
        _hours('10:00:00', '23:00:00'),
        tuesdayEvening,
      )!;
      expect(line.text, 'Open');
      expect(line.tone, NearbyOpenTone.fresh);
    });

    test('a 24-hour place says so, and stays fresh', () {
      final line = nearbyOpenLine(
        _hours('00:00:00', '00:00:00'),
        tuesdayEvening,
      )!;
      expect(line.text, 'Open · 24 h');
      expect(line.tone, NearbyOpenTone.fresh);
    });

    test('closing within the hour trades the accent for the closing time', () {
      final line = nearbyOpenLine(
        _hours('10:00:00', '20:00:00'),
        tuesdayEvening,
      )!;
      expect(line.text, 'Closes 8 pm');
      expect(line.tone, NearbyOpenTone.muted);
    });

    test('an overnight span counts the minutes across midnight', () {
      // 23:40, closing 00:20: twenty minutes left, not 1400.
      final line = nearbyOpenLine(
        _hours('17:30:00', '00:20:00'),
        DateTime(2026, 9, 8, 23, 40),
      )!;
      expect(line.text, 'Closes 12:20 am');
      expect(line.tone, NearbyOpenTone.muted);
    });

    test('a closed place says when it opens', () {
      final line = nearbyOpenLine(
        _hours('17:30:00', '23:00:00'),
        DateTime(2026, 9, 8, 9, 0),
      )!;
      expect(line.text, 'Opens 5:30 pm');
      expect(line.tone, NearbyOpenTone.muted);
    });

    test('a place shut for the day does not promise an opening time', () {
      final line = nearbyOpenLine(
        // Tuesday is ISO weekday 2.
        _hours('17:30:00', '23:00:00', closed: [2]),
        DateTime(2026, 9, 8, 9, 0),
      )!;
      expect(line.text, 'Closed today');
      expect(line.tone, NearbyOpenTone.muted);
    });
  });
}
