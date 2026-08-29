import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/quiz/models/quiz_question.dart';

void main() {
  group('QuizQuestion.fromJson', () {
    test('maps a full Supabase row', () {
      final question = QuizQuestion.fromJson(_fullRow());

      expect(question.id, 3);
      expect(question.prompt, 'What are you craving?');
      expect(question.options, hasLength(3));
      expect(
        question.options.map((option) => option.label),
        ['Something light', 'Something spicy', 'Something sweet'],
      );
    });

    test('coerces a numeric id to int', () {
      final row = _fullRow()..['id'] = 3.0;

      expect(QuizQuestion.fromJson(row).id, 3);
    });

    test('defaults a null prompt to empty', () {
      final row = _fullRow()..['prompt'] = null;

      expect(QuizQuestion.fromJson(row).prompt, '');
    });

    test('defaults an absent prompt to empty', () {
      final row = _fullRow()..remove('prompt');

      expect(QuizQuestion.fromJson(row).prompt, '');
    });

    group('quiz_options', () {
      test('sorts by position regardless of input order', () {
        final question = QuizQuestion.fromJson(
          _rowWithOptions(<Map<String, dynamic>>[
            _option(id: 3, label: 'third', position: 3),
            _option(id: 1, label: 'first', position: 1),
            _option(id: 2, label: 'second', position: 2),
          ]),
        );

        expect(
          question.options.map((option) => option.label),
          ['first', 'second', 'third'],
        );
      });

      test('treats a missing position as 0', () {
        final question = QuizQuestion.fromJson(
          _rowWithOptions(<Map<String, dynamic>>[
            <String, dynamic>{'id': 1, 'label': 'positioned', 'position': 2},
            <String, dynamic>{'id': 2, 'label': 'unpositioned'},
          ]),
        );

        expect(
          question.options.map((option) => option.label),
          ['unpositioned', 'positioned'],
        );
      });

      test('yields an empty list for an empty array', () {
        expect(QuizQuestion.fromJson(_rowWithOptions([])).options, isEmpty);
      });

      test('yields an empty list when the key is absent', () {
        final row = _fullRow()..remove('quiz_options');

        expect(QuizQuestion.fromJson(row).options, isEmpty);
      });

      test('yields an empty list when the value is null', () {
        expect(QuizQuestion.fromJson(_rowWithOptions(null)).options, isEmpty);
      });

      test('does not reorder the caller\'s payload in place', () {
        final row = _fullRow();
        final payload = row['quiz_options'] as List<dynamic>;

        QuizQuestion.fromJson(row);

        expect(
          payload.map((option) => (option as Map)['position']),
          [3, 1, 2],
        );
      });

      // Regression: the sort must run on the copy made by .toList(), not on a
      // fixed-length or const payload, which would throw
      // UnsupportedError on sort.
      test('sorts a const [] payload without throwing', () {
        expect(
          () => QuizQuestion.fromJson(<String, dynamic>{
            'id': 1,
            'prompt': 'p',
            'quiz_options': const <Map<String, dynamic>>[],
          }),
          returnsNormally,
        );
      });

      test('sorts a const list of options without throwing', () {
        final question = QuizQuestion.fromJson(<String, dynamic>{
          'id': 1,
          'prompt': 'p',
          'quiz_options': const <Map<String, dynamic>>[
            <String, dynamic>{'id': 2, 'label': 'second', 'position': 2},
            <String, dynamic>{'id': 1, 'label': 'first', 'position': 1},
          ],
        });

        expect(
          question.options.map((option) => option.label),
          ['first', 'second'],
        );
      });

      test('sorts an unmodifiable list of options without throwing', () {
        final question = QuizQuestion.fromJson(<String, dynamic>{
          'id': 1,
          'prompt': 'p',
          'quiz_options': List<Map<String, dynamic>>.unmodifiable(
            <Map<String, dynamic>>[
              _option(id: 2, label: 'second', position: 2),
              _option(id: 1, label: 'first', position: 1),
            ],
          ),
        });

        expect(
          question.options.map((option) => option.label),
          ['first', 'second'],
        );
      });

      test('sorts a fixed-length list of options without throwing', () {
        final question = QuizQuestion.fromJson(<String, dynamic>{
          'id': 1,
          'prompt': 'p',
          'quiz_options': List<Map<String, dynamic>>.filled(
            2,
            _option(id: 1, label: 'first', position: 1),
            growable: false,
          ),
        });

        expect(question.options, hasLength(2));
      });
    });
  });

  group('QuizOption.fromJson', () {
    test('maps a full option row', () {
      final option = QuizOption.fromJson(<String, dynamic>{
        'id': 9,
        'label': 'Something spicy',
        'position': 2,
        'result_title': 'Go bold',
        'result_body': 'Chilli pan mee is calling.',
        'result_accent': '#F6D365',
        'recommended': <String, dynamic>{'name': 'Kopitiam Peserai'},
      });

      expect(option.id, 9);
      expect(option.label, 'Something spicy');
      expect(option.position, 2);
      expect(option.resultTitle, 'Go bold');
      expect(option.resultBody, 'Chilli pan mee is calling.');
      expect(option.resultAccent, const Color(0xFFF6D365));
      expect(option.recommendedRestaurantName, 'Kopitiam Peserai');
    });

    test('coerces numeric id and position to int', () {
      final option = QuizOption.fromJson(<String, dynamic>{
        'id': 9.0,
        'position': 2.7,
      });

      expect(option.id, 9);
      expect(option.position, 2);
    });

    test('falls back to defaults when every nullable column is null', () {
      final option = QuizOption.fromJson(<String, dynamic>{
        'id': 1,
        'label': null,
        'position': null,
        'result_title': null,
        'result_body': null,
        'result_accent': null,
        'recommended': null,
      });

      expect(option.label, '');
      expect(option.position, 0);
      expect(option.resultTitle, '');
      expect(option.resultBody, '');
      expect(option.resultAccent, _fallbackAccent);
      expect(option.recommendedRestaurantName, isNull);
    });

    test('falls back to defaults on an id-only row', () {
      final option = QuizOption.fromJson(<String, dynamic>{'id': 1});

      expect(option.id, 1);
      expect(option.label, '');
      expect(option.position, 0);
      expect(option.resultTitle, '');
      expect(option.resultBody, '');
      expect(option.resultAccent, _fallbackAccent);
      expect(option.recommendedRestaurantName, isNull);
    });

    group('result_accent', () {
      test('parses a hex string without the leading hash', () {
        expect(
          QuizOption.fromJson(_optionWithAccent('F6D365')).resultAccent,
          const Color(0xFFF6D365),
        );
      });

      test('forces full opacity on a transparent-looking hex', () {
        expect(
          QuizOption.fromJson(_optionWithAccent('#00F6D365')).resultAccent,
          const Color(0xFFF6D365),
        );
      });

      test('falls back to the quiz mint when the hex is invalid', () {
        expect(
          QuizOption.fromJson(_optionWithAccent('mint')).resultAccent,
          _fallbackAccent,
        );
      });
    });

    group('recommended', () {
      test('is null when the nested join is absent', () {
        final option = QuizOption.fromJson(<String, dynamic>{
          'id': 1,
          'label': 'Something light',
        });

        expect(option.recommendedRestaurantName, isNull);
      });

      test('is null when the nested join has no name', () {
        final option = QuizOption.fromJson(<String, dynamic>{
          'id': 1,
          'recommended': <String, dynamic>{'id': 4},
        });

        expect(option.recommendedRestaurantName, isNull);
      });

      test('is null when the nested name is null', () {
        final option = QuizOption.fromJson(<String, dynamic>{
          'id': 1,
          'recommended': <String, dynamic>{'name': null},
        });

        expect(option.recommendedRestaurantName, isNull);
      });

      test('reads the name out of the nested join', () {
        final option = QuizOption.fromJson(<String, dynamic>{
          'id': 1,
          'recommended': <String, dynamic>{'id': 4, 'name': 'Warung Ayu'},
        });

        expect(option.recommendedRestaurantName, 'Warung Ayu');
      });
    });
  });
}

const _fallbackAccent = Color(0xFFB7E4C7);

Map<String, dynamic> _option({
  required int id,
  required String label,
  required int position,
}) {
  return <String, dynamic>{
    'id': id,
    'label': label,
    'position': position,
    'result_title': '$label title',
    'result_body': '$label body',
    'result_accent': '#B7E4C7',
    'recommended': <String, dynamic>{'name': '$label restaurant'},
  };
}

Map<String, dynamic> _optionWithAccent(Object? accent) {
  return <String, dynamic>{'id': 1, 'result_accent': accent};
}

Map<String, dynamic> _rowWithOptions(Object? options) {
  return _fullRow()..['quiz_options'] = options;
}

Map<String, dynamic> _fullRow() {
  return <String, dynamic>{
    'id': 3,
    'prompt': 'What are you craving?',
    'quiz_options': <Map<String, dynamic>>[
      _option(id: 30, label: 'Something sweet', position: 3),
      _option(id: 10, label: 'Something light', position: 1),
      _option(id: 20, label: 'Something spicy', position: 2),
    ],
  };
}
