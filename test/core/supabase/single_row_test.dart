import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/supabase/single_row.dart';

void main() {
  group('asSingleRow', () {
    // Every profile write — finishing onboarding, the Settings radius, the
    // location sync behind the header chip — parses its RPC response through
    // here, so a shape this misreads is a write that "failed" after it
    // actually landed.

    test('passes a single object row through', () {
      expect(asSingleRow({'id': 'abc', 'search_radius_km': 10}),
          {'id': 'abc', 'search_radius_km': 10});
    });

    test('unwraps the array PostgREST sometimes wraps the row in', () {
      expect(
        asSingleRow([
          {'id': 'abc'},
        ]),
        {'id': 'abc'},
      );
    });

    test('anything that is not a row throws instead of degrading', () {
      // Degrading to an empty row would build a blank AppUser — null
      // onboarded_at included — and applyUser would kick a fully onboarded
      // user back into the wizard with no error anywhere. A throw lands in
      // every caller's existing error path (snackbar / debugPrint), and the
      // writes behind these RPCs are all safe to retry.
      expect(() => asSingleRow(null), throwsFormatException);
      expect(() => asSingleRow(const []), throwsFormatException);
      expect(() => asSingleRow('ok'), throwsFormatException);
      expect(() => asSingleRow(const ['not-a-row']), throwsFormatException);
    });
  });
}
