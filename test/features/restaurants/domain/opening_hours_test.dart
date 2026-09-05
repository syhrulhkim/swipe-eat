import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/restaurants/domain/opening_hours.dart';

void main() {
  // 2026-09-07 is a Monday.
  DateTime monday(int hour, [int minute = 0]) =>
      DateTime(2026, 9, 7, hour, minute);
  DateTime tuesday(int hour, [int minute = 0]) =>
      DateTime(2026, 9, 8, hour, minute);

  group('OpeningHours.fromJson', () {
    test('reads the row columns', () {
      final hours = OpeningHours.fromJson({
        'opens_at': '17:30:00',
        'closes_at': '02:00:00',
        'closed_dow': [1],
        'hours_text': '5:30PM - 2AM (Closed on Monday)',
      });
      expect(hours.opensAtMinutes, 17 * 60 + 30);
      expect(hours.closesAtMinutes, 2 * 60);
      expect(hours.closedWeekdays, {1});
      expect(hours.text, '5:30PM - 2AM (Closed on Monday)');
      expect(hours.isKnown, isTrue);
      expect(hours.isOvernight, isTrue);
    });

    test('is unknown when either time is missing', () {
      expect(OpeningHours.fromJson({'opens_at': '09:00:00'}).isKnown, isFalse);
      expect(OpeningHours.fromJson({}).isKnown, isFalse);
      expect(OpeningHours.fromJson({}).isOpenAt(monday(12)), isNull);
      expect(OpeningHours.fromJson({}).statusLabel(monday(12)), isNull);
    });

    test('round-trips through toJson', () {
      final hours = OpeningHours.fromJson({
        'opens_at': '09:30:00',
        'closes_at': '20:00:00',
        'closed_dow': [7, 1],
        'hours_text': '9.30am - 8pm',
      });
      final again = OpeningHours.fromJson(hours.toJson());
      expect(again.opensAtMinutes, hours.opensAtMinutes);
      expect(again.closesAtMinutes, hours.closesAtMinutes);
      expect(again.closedWeekdays, hours.closedWeekdays);
      expect(again.text, hours.text);
      expect(hours.toJson()['closed_dow'], [1, 7]);
    });

    test('rejects malformed clocks', () {
      expect(OpeningHours.parseClockMinutes('25:00'), isNull);
      expect(OpeningHours.parseClockMinutes('9'), isNull);
      expect(OpeningHours.parseClockMinutes('ab:cd'), isNull);
      expect(OpeningHours.parseClockMinutes('24:00:00'), 0);
    });
  });

  group('isOpenAt', () {
    const daytime = OpeningHours(
      opensAtMinutes: 9 * 60 + 30,
      closesAtMinutes: 20 * 60,
    );

    test('a daytime span is open between its times and closed outside', () {
      expect(daytime.isOpenAt(monday(9, 29)), isFalse);
      expect(daytime.isOpenAt(monday(9, 30)), isTrue);
      expect(daytime.isOpenAt(monday(19, 59)), isTrue);
      expect(daytime.isOpenAt(monday(20)), isFalse);
    });

    test('a closed weekday closes the whole day', () {
      const hours = OpeningHours(
        opensAtMinutes: 9 * 60,
        closesAtMinutes: 20 * 60,
        closedWeekdays: {DateTime.monday},
      );
      expect(hours.isOpenAt(monday(12)), isFalse);
      expect(hours.isOpenAt(tuesday(12)), isTrue);
    });

    test('an overnight span wraps past midnight, matching the database', () {
      // Ikan Bakar Medan: 5:30 pm – 2 am, closed Monday.
      const hours = OpeningHours(
        opensAtMinutes: 17 * 60 + 30,
        closesAtMinutes: 2 * 60,
        closedWeekdays: {DateTime.monday},
      );
      // 1 am Monday belongs to Sunday's opening: open.
      expect(hours.isOpenAt(monday(1)), isTrue);
      // 8 pm Monday: the closed day.
      expect(hours.isOpenAt(monday(20)), isFalse);
      // 1 am Tuesday belongs to Monday's opening: closed.
      expect(hours.isOpenAt(tuesday(1)), isFalse);
      // 8 pm Tuesday: open.
      expect(hours.isOpenAt(tuesday(20)), isTrue);
      // 3 am Tuesday: after closing.
      expect(hours.isOpenAt(tuesday(3)), isFalse);
    });

    test('equal times mean all day', () {
      const hours = OpeningHours(opensAtMinutes: 0, closesAtMinutes: 0);
      expect(hours.isAllDay, isTrue);
      expect(hours.isOpenAt(monday(3)), isTrue);
      expect(hours.isOpenAt(monday(23, 59)), isTrue);
    });
  });

  group('statusLabel', () {
    test('says when it closes while open', () {
      const hours = OpeningHours(
        opensAtMinutes: 17 * 60 + 30,
        closesAtMinutes: 2 * 60,
      );
      expect(hours.statusLabel(monday(20)), 'Open till 2 am');
    });

    test('says when it opens before opening', () {
      const hours = OpeningHours(
        opensAtMinutes: 17 * 60 + 30,
        closesAtMinutes: 23 * 60,
      );
      expect(hours.statusLabel(monday(12)), 'Opens 5:30 pm');
    });

    test('says closed today after closing or on a closed day', () {
      const hours = OpeningHours(
        opensAtMinutes: 9 * 60,
        closesAtMinutes: 17 * 60,
        closedWeekdays: {DateTime.tuesday},
      );
      expect(hours.statusLabel(monday(18)), 'Closed today');
      expect(hours.statusLabel(tuesday(12)), 'Closed today');
    });

    test('says 24 h for an all-day place', () {
      const hours = OpeningHours(opensAtMinutes: 0, closesAtMinutes: 0);
      expect(hours.statusLabel(monday(12)), 'Open 24 h');
    });
  });

  group('formatClock', () {
    test('writes the short 12-hour form the design uses', () {
      expect(OpeningHours.formatClock(0), '12 am');
      expect(OpeningHours.formatClock(2 * 60), '2 am');
      expect(OpeningHours.formatClock(12 * 60), '12 pm');
      expect(OpeningHours.formatClock(17 * 60 + 30), '5:30 pm');
      expect(OpeningHours.formatClock(22 * 60 + 5), '10:05 pm');
    });
  });
}
