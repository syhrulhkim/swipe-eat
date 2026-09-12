import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/storage/cached_at.dart';

/// A fixed "now", so the table below is a table and not a race with the clock.
final DateTime now = DateTime.utc(2026, 9, 12, 14, 30);

String ago(Duration elapsed) => describeAge(now.subtract(elapsed), now: now);

void main() {
  group('describeAge', () {
    test('anything under a minute old is just now', () {
      expect(ago(Duration.zero), 'just now');
      expect(ago(const Duration(seconds: 59)), 'just now');
    });

    test('reads minutes for the first hour, and the same shape at one', () {
      // No singular here: the unit is abbreviated, so "1 min ago" is right.
      expect(ago(const Duration(minutes: 1)), '1 min ago');
      expect(ago(const Duration(minutes: 59)), '59 min ago');
    });

    test('the hour boundary flips the unit, and one hour is singular', () {
      expect(ago(const Duration(minutes: 60)), '1 hour ago');
      expect(ago(const Duration(hours: 1, minutes: 59)), '1 hour ago');
      expect(ago(const Duration(hours: 2)), '2 hours ago');
      expect(ago(const Duration(hours: 23, minutes: 59)), '23 hours ago');
    });

    test('a day old is yesterday, and past that it counts days', () {
      expect(ago(const Duration(hours: 24)), 'yesterday');
      expect(ago(const Duration(hours: 47)), 'yesterday');
      expect(ago(const Duration(days: 2)), '2 days ago');
      expect(ago(const Duration(days: 30)), '30 days ago');
    });

    test('without an injected now it measures against the real clock', () {
      expect(describeAge(DateTime.now()), 'just now');
    });
  });
}
