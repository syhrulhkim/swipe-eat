import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/onboarding/models/taste_option.dart';

void main() {
  group('TasteOption.fromJson', () {
    test('reads a plain catalog row', () {
      final option = TasteOption.fromJson(const <String, dynamic>{
        'id': 4,
        'slug': 'nasi-lemak',
        'label': 'Nasi lemak',
      });

      expect(option.id, 4);
      expect(option.slug, 'nasi-lemak');
      expect(option.label, 'Nasi lemak');
    });

    test('an id that arrives as a double is still an int', () {
      // PostgREST hands back a JSON number; a `bigint` round-tripped through
      // one can land as a double, and `as int` would throw on it.
      final option = TasteOption.fromJson(const <String, dynamic>{
        'id': 7.0,
        'slug': 'satay',
        'label': 'Satay',
      });

      expect(option.id, 7);
      expect(option.id, isA<int>());
    });

    test('a row with no label is empty, not a crash', () {
      final option = TasteOption.fromJson(const <String, dynamic>{'id': 1});

      expect(option.slug, '');
      expect(option.label, '');
    });
  });

  group('TasteCatalog', () {
    test('the empty catalog has both lists and neither is null', () {
      const catalog = TasteCatalog.empty();

      expect(catalog.cuisines, isEmpty);
      expect(catalog.dietaryTags, isEmpty);
    });
  });
}
