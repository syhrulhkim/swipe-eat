import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/rating_label.dart';

void main() {
  group('ratingLabel', () {
    test('formats a real rating to one decimal', () {
      expect(ratingLabel(4.5), '4.5');
      expect(ratingLabel(4), '4.0');
      expect(ratingLabel(5), '5.0');
    });

    test('rounds to one decimal', () {
      expect(ratingLabel(4.46), '4.5');
      expect(ratingLabel(4.44), '4.4');
    });

    test('renders a dash for an absent rating', () {
      expect(ratingLabel(0), '–');
    });

    test('renders a dash for a negative rating', () {
      expect(ratingLabel(-1), '–');
      expect(ratingLabel(-0.1), '–');
    });

    test('renders a dash for NaN', () {
      // NaN > 0 is false, so corrupt data degrades to "no rating".
      expect(ratingLabel(double.nan), '–');
    });

    test('uses an en dash, not a hyphen', () {
      expect(ratingLabel(0), '–');
      expect(ratingLabel(0), isNot('-'));
    });

    test('a tiny positive rating still formats numerically', () {
      // Current behaviour: only <= 0 is treated as "no rating", so 0.01
      // renders as "0.0". Pinned deliberately; ratings that small do not
      // occur in practice.
      expect(ratingLabel(0.01), '0.0');
    });

    test('clamping is not the label layer concern', () {
      // ratingLabel does not clamp; out-of-band values pass through.
      expect(ratingLabel(9.99), '10.0');
    });
  });
}
