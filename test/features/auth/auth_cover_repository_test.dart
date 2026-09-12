import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swipe_eat/features/auth/data/auth_cover_repository.dart';

import '../../support/fake_supabase_http.dart';

void main() {
  group('AuthCoverRepository', () {
    test('constructs from an injected client without initialising Supabase',
        () {
      final client = SupabaseClient(
        'https://stub.supabase.co',
        'stub-anon-key',
      );
      addTearDown(client.dispose);

      expect(() => AuthCoverRepository(client: client), returnsNormally);
    });

    test('construction is free; only the request needs the singleton', () {
      expect(
        const AuthCoverRepository().fetchCovers(6),
        throwsA(isA<Error>()),
      );
    });
  });

  group('AuthCoverRepository over the wire', () {
    late FakeSupabaseHttp fake;
    late SupabaseClient client;
    late AuthCoverRepository repository;

    setUp(() {
      fake = FakeSupabaseHttp();
      client = fakeSupabaseClient(fake);
      addTearDown(client.dispose);
      repository = AuthCoverRepository(client: client);
    });

    Map<String, dynamic> row(String name, {String? imageUrl}) {
      return {
        'name': name,
        'restaurant_images': [
          if (imageUrl != null) {'url': imageUrl, 'position': 0},
        ],
      };
    }

    test('asks for the top-rated rows and one picture each', () async {
      fake.on('GET', '/rest/v1/restaurants', [
        row('Village Park', imageUrl: 'https://img.test/1.jpg'),
      ]);

      final covers = await repository.fetchCovers(6);

      final call = fake.single;
      expect(call.method, 'GET');
      expect(call.path, '/rest/v1/restaurants');
      expect(call.query['select'], 'name,restaurant_images!inner(url,position)');
      // `!inner` plus the referenced-table order/limit is the whole point: the
      // gallery's *first* picture, not an arbitrary one.
      expect(call.query['restaurant_images.order'], 'position.asc.nullslast');
      expect(call.query['restaurant_images.limit'], '1');
      expect(call.query['order'], 'rating.desc.nullslast');
      expect(call.query['limit'], '6');

      expect(covers.single.name, 'Village Park');
      expect(covers.single.imageUrl, 'https://img.test/1.jpg');
    });

    test('a row with no usable name is dropped, not drawn blank', () async {
      fake.on('GET', '/rest/v1/restaurants', [
        row(''),
        row('Nasi Lemak Antarabangsa'),
      ]);

      final covers = await repository.fetchCovers(6);

      // The one that survived has no picture either — that is a plain surface,
      // not a broken image.
      expect(covers.map((cover) => cover.name), ['Nasi Lemak Antarabangsa']);
      expect(covers.single.imageUrl, isNull);
    });

    test('a server failure reaches the screen rather than an empty stack',
        () async {
      fake.onError(
        'GET',
        '/rest/v1/restaurants',
        status: 500,
        code: 'XX000',
        message: 'internal error',
      );

      await expectLater(
        repository.fetchCovers(6),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
