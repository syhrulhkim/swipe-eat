import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swipe_eat/features/restaurants/data/restaurant_repository.dart';
import 'package:swipe_eat/features/restaurants/data/swipe_repository.dart';

void main() {
  group('RestaurantRepository', () {
    test('constructs from an injected client without initialising Supabase',
        () {
      final client = SupabaseClient(
        'https://stub.supabase.co',
        'stub-anon-key',
      );
      addTearDown(client.dispose);

      expect(() => RestaurantRepository(client: client), returnsNormally);
    });

    test('construction is free; only the request needs the singleton', () {
      // The client is resolved lazily, so pages can be built in tests without
      // Supabase.initialize — the uninitialised singleton only surfaces when
      // a request actually goes out, where callers catch and retry.
      final repository = RestaurantRepository();

      expect(repository.fetchDeck(), throwsA(isA<Error>()));
      expect(repository.likedRestaurants(), throwsA(isA<Error>()));
      expect(repository.search(query: 'nasi'), throwsA(isA<Error>()));
    });
  });

  group('SwipeRepository', () {
    test('constructs from an injected client without initialising Supabase',
        () {
      final client = SupabaseClient(
        'https://stub.supabase.co',
        'stub-anon-key',
      );
      addTearDown(client.dispose);

      expect(() => SwipeRepository(client: client), returnsNormally);
    });

    test('construction is free; only the request needs the singleton', () {
      final repository = SwipeRepository();

      expect(
        repository.record(restaurantId: 1, liked: true),
        throwsA(isA<Error>()),
      );
    });
  });
}
