import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swipe_eat/features/quiz/data/quiz_repository.dart';

void main() {
  group('QuizRepository', () {
    test('constructs from an injected client without initialising Supabase',
        () {
      // Supabase.instance.client throws when the global singleton has not been
      // initialised, so reaching this without an exception proves the injected
      // client is used instead of the singleton.
      final client = SupabaseClient(
        'https://stub.supabase.co',
        'stub-anon-key',
      );
      addTearDown(client.dispose);

      expect(() => QuizRepository(client: client), returnsNormally);
    });

    test('falls back to the uninitialised singleton when no client is given',
        () {
      expect(QuizRepository.new, throwsA(isA<Error>()));
    });

    group('fetchActiveQuestion', () {
      test('returns null when no rows come back', () async {
        final rest = await _StubRest.serving(<Map<String, dynamic>>[]);
        addTearDown(rest.close);

        expect(await rest.repository.fetchActiveQuestion(), isNull);
      });

      test('maps the first row, sorting its options by position', () async {
        final rest = await _StubRest.serving(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 3,
            'prompt': 'What are you craving?',
            'quiz_options': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 20,
                'label': 'Something spicy',
                'position': 2,
                'result_title': 'Go bold',
                'result_body': 'Chilli pan mee.',
                'result_accent': '#F6D365',
                'recommended': <String, dynamic>{'name': 'Warung Ayu'},
              },
              <String, dynamic>{
                'id': 10,
                'label': 'Something light',
                'position': 1,
                'result_title': null,
                'result_body': null,
                'result_accent': null,
                'recommended': null,
              },
            ],
          },
          <String, dynamic>{'id': 4, 'prompt': 'ignored second row'},
        ]);
        addTearDown(rest.close);

        final question = await rest.repository.fetchActiveQuestion();

        expect(question, isNotNull);
        expect(question!.id, 3);
        expect(question.prompt, 'What are you craving?');
        expect(
          question.options.map((option) => option.label),
          ['Something light', 'Something spicy'],
        );
        expect(question.options.first.resultTitle, '');
        expect(question.options.first.resultAccent, const Color(0xFFB7E4C7));
        expect(question.options.first.recommendedRestaurantName, isNull);
        expect(question.options.last.resultAccent, const Color(0xFFF6D365));
        expect(question.options.last.recommendedRestaurantName, 'Warung Ayu');
      });

      test('queries active questions ordered by position, limit 1', () async {
        final rest = await _StubRest.serving(<Map<String, dynamic>>[]);
        addTearDown(rest.close);

        await rest.repository.fetchActiveQuestion();

        expect(rest.requestedPaths, hasLength(1));
        final uri = Uri.parse(rest.requestedPaths.single);
        expect(uri.path, '/rest/v1/quiz_questions');
        expect(uri.queryParameters['is_active'], 'eq.true');
        expect(uri.queryParameters['order'], startsWith('position.asc'));
        expect(uri.queryParameters['limit'], '1');
        expect(uri.queryParameters['select'], contains('quiz_options'));
        expect(
          uri.queryParameters['select'],
          contains('recommended:restaurants(name)'),
        );
      });

      test('yields an empty option list when the join is missing', () async {
        final rest = await _StubRest.serving(<Map<String, dynamic>>[
          <String, dynamic>{'id': 3, 'prompt': 'No options yet'},
        ]);
        addTearDown(rest.close);

        final question = await rest.repository.fetchActiveQuestion();

        expect(question!.options, isEmpty);
      });
    });
  });
}

/// A loopback stand-in for Supabase's REST endpoint: the repository talks to a
/// real [SupabaseClient] whose base URL points here, so the postgrest query
/// building and row decoding are exercised without touching the live project.
class _StubRest {
  _StubRest._(this._server, this.repository);

  static Future<_StubRest> serving(List<Map<String, dynamic>> rows) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = SupabaseClient(
      'http://${server.address.address}:${server.port}',
      'stub-anon-key',
    );
    final rest = _StubRest._(server, QuizRepository(client: client));

    server.listen((request) async {
      rest.requestedPaths.add(request.requestedUri.toString());
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(rows));
      await request.response.close();
    });

    addTearDown(client.dispose);
    return rest;
  }

  final HttpServer _server;
  final QuizRepository repository;
  final List<String> requestedPaths = <String>[];

  Future<void> close() => _server.close(force: true);
}
