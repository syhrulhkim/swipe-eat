import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swipe_eat/features/restaurants/models/restaurant.dart';
import 'package:swipe_eat/features/restaurants/state/likes_controller.dart';

import 'fake_restaurant_repositories.dart';

/// Drives the controller's auth subscription without a Supabase singleton.
class _FakeAuthEvents extends LikesAuthEvents {
  _FakeAuthEvents({this.userId});

  String? userId;
  // Lives for the length of one test and dies with it; closing it in a
  // teardown would add ceremony without changing what the test proves.
  // ignore: close_sinks
  final StreamController<AuthState> events = StreamController.broadcast();

  @override
  Stream<AuthState>? get changes => events.stream;

  @override
  String? get currentUserId => userId;
}

AuthState _signedIn(String userId) {
  final user = User(
    id: userId,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-08-24T00:00:00Z',
  );
  return AuthState(
    AuthChangeEvent.signedIn,
    Session(accessToken: 'token', tokenType: 'bearer', user: user),
  );
}

/// A liked-rows fetch that parks until the test releases it, so an account
/// change can land while the request is still in flight.
class _GatedRestaurantRepository extends FakeRestaurantRepository {
  final Completer<void> gate = Completer<void>();

  @override
  Future<List<Restaurant>> likedRestaurants({int limit = 200}) async {
    await gate.future;
    return super.likedRestaurants(limit: limit);
  }
}

/// A swipe write that parks until the test releases it, so a reset can land
/// between the optimistic edit and the write's failure.
class _GatedSwipeRepository extends FakeSwipeRepository {
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> record({
    required int restaurantId,
    required bool liked,
    String source = 'deck',
    double? latitude,
    double? longitude,
  }) async {
    await gate.future;
    return super.record(
      restaurantId: restaurantId,
      liked: liked,
      source: source,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

void main() {
  late FakeRestaurantRepository restaurants;
  late FakeSwipeRepository swipes;
  late LikesController controller;

  setUp(() {
    restaurants = FakeRestaurantRepository();
    swipes = FakeSwipeRepository();
    wireFakeBackend(restaurants, swipes);
    controller = LikesController(
      restaurants: restaurants,
      swipes: swipes,
      followAuthChanges: false,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  group('LikesController load', () {
    test('refresh publishes the backend rows newest first', () async {
      restaurants.likedRows = [testRestaurant(5), testRestaurant(2)];

      await controller.refresh();

      expect(controller.isLoaded, isTrue);
      expect(controller.liked.map((r) => r.id), [5, 2]);
      expect(controller.isLiked(5), isTrue);
      expect(controller.isLiked(9), isFalse);
    });

    test('ensureLoaded only fetches once for concurrent callers', () async {
      await Future.wait([
        controller.ensureLoaded(),
        controller.ensureLoaded(),
      ]);
      await controller.ensureLoaded();

      expect(restaurants.likedFetches, 1);
    });

    test('a failed load does not cache the error', () async {
      restaurants.failLiked = true;
      await expectLater(controller.ensureLoaded(), throwsException);
      expect(controller.isLoaded, isFalse);

      restaurants.failLiked = false;
      await controller.ensureLoaded();
      expect(controller.isLoaded, isTrue);
    });
  });

  group('LikesController like', () {
    test('records the swipe and syncs the list from the backend', () async {
      await controller.refresh();

      await controller.like(7, source: 'deck', latitude: 1.9, longitude: 103.1);

      expect(controller.isLiked(7), isTrue);
      expect(controller.liked.map((r) => r.id), [7]);
      expect(swipes.calls.single.restaurantId, 7);
      expect(swipes.calls.single.liked, isTrue);
      expect(swipes.calls.single.source, 'deck');
      expect(swipes.calls.single.latitude, 1.9);
      expect(swipes.calls.single.longitude, 103.1);
    });

    test('rolls the optimistic id back when the write fails', () async {
      await controller.refresh();
      swipes.fail = true;
      var notified = 0;
      controller.addListener(() => notified++);

      await expectLater(controller.like(7), throwsException);

      expect(controller.isLiked(7), isFalse);
      expect(notified, 2, reason: 'once optimistic, once for the rollback');
    });

    test('a deck like is attributed to the deck by default', () async {
      // The deck calls like() without naming a source; if the default drifts,
      // every swipe from the deck is mis-attributed and nothing else breaks
      // loudly enough to notice.
      await controller.refresh();

      await controller.like(7);

      expect(swipes.calls.single.source, 'deck');
    });

    test('keeps the optimistic id when only the follow-up refresh fails',
        () async {
      await controller.refresh();
      restaurants.failLiked = true;

      // Must not throw: the write itself landed, and that is what the id
      // set reflects. Only the row list is stale until the next refresh.
      await controller.like(7);

      expect(controller.isLiked(7), isTrue);
    });
  });

  group('LikesController unlike', () {
    test('removes the row optimistically and records the swipe', () async {
      restaurants.likedRows = [testRestaurant(7), testRestaurant(3)];
      await controller.refresh();

      await controller.unlike(7);

      expect(controller.isLiked(7), isFalse);
      expect(controller.liked.map((r) => r.id), [3]);
      expect(swipes.calls.single.liked, isFalse);
      expect(swipes.calls.single.source, 'likes');
    });

    test('restores the row in place when the write fails', () async {
      restaurants.likedRows = [
        testRestaurant(9),
        testRestaurant(7),
        testRestaurant(3),
      ];
      await controller.refresh();
      swipes.fail = true;

      await expectLater(controller.unlike(7), throwsException);

      expect(controller.isLiked(7), isTrue);
      expect(controller.liked.map((r) => r.id), [9, 7, 3],
          reason: 'the rollback must not shuffle the list order');
    });

    test('does nothing for a restaurant that is not liked', () async {
      await controller.refresh();

      await controller.unlike(42);

      expect(swipes.calls, isEmpty);
    });
  });

  group('LikesController reset', () {
    test('drops everything so the next account starts clean', () async {
      restaurants.likedRows = [testRestaurant(7)];
      await controller.refresh();
      expect(controller.isLoaded, isTrue);

      controller.reset();

      expect(controller.isLoaded, isFalse);
      expect(controller.liked, isEmpty);
      expect(controller.isLiked(7), isFalse);
    });

    test('a refresh already in flight cannot publish into the next account',
        () async {
      // The leak this guards: user A signs out mid-refresh, user B signs in,
      // and A's rows land in B's session as B's hearts.
      final backend = _GatedRestaurantRepository()
        ..likedRows = [testRestaurant(7)];
      final scoped = LikesController(
        restaurants: backend,
        swipes: swipes,
        followAuthChanges: false,
      );
      addTearDown(scoped.dispose);

      final inFlight = scoped.refresh();
      scoped.reset(); // the account changed underneath the request
      backend.gate.complete();
      await inFlight;

      expect(scoped.liked, isEmpty);
      expect(scoped.isLiked(7), isFalse);
      expect(scoped.isLoaded, isFalse,
          reason: 'the next ensureLoaded must refetch for whoever is signed '
              'in now, not settle for the previous account');
    });

    test('a write that fails after a reset does not resurrect the row',
        () async {
      // Same leak from the other side: the rollback of an optimistic unlike
      // must not put user A's restaurant back once the session has moved on.
      final backend = _GatedSwipeRepository()..fail = true;
      restaurants.likedRows = [testRestaurant(7)];
      final scoped = LikesController(
        restaurants: restaurants,
        swipes: backend,
        followAuthChanges: false,
      );
      addTearDown(scoped.dispose);
      await scoped.refresh();

      final pending = scoped.unlike(7);
      final settled = expectLater(pending, throwsException);
      scoped.reset();
      backend.gate.complete();
      await settled;

      expect(scoped.isLiked(7), isFalse);
      expect(scoped.liked, isEmpty);
    });
  });

  group('LikesController auth following', () {
    test('the replayed signedIn for the current account keeps the load alive',
        () async {
      // Supabase's auth stream replays its latest event to every new
      // listener, on a microtask. On a fresh-login launch that replayed
      // signedIn lands while the very first load is in flight; treating it
      // as an account change would discard the rows and leave the Like tab
      // on a spinner with no error and no retry.
      final backend = _GatedRestaurantRepository()
        ..likedRows = [testRestaurant(7)];
      final auth = _FakeAuthEvents(userId: 'user-a');
      final scoped = LikesController(restaurants: backend, swipes: swipes,
          authEvents: auth);
      addTearDown(() {
        scoped.dispose();
        auth.events.close();
      });

      final load = scoped.ensureLoaded();
      auth.events.add(_signedIn('user-a'));
      await Future<void>.delayed(Duration.zero); // let the replay land
      backend.gate.complete();
      await load;

      expect(scoped.isLoaded, isTrue);
      expect(scoped.liked.map((r) => r.id), [7]);
    });

    test('an actual account change dumps the cache', () async {
      final auth = _FakeAuthEvents(userId: 'user-a');
      restaurants.likedRows = [testRestaurant(7)];
      final scoped = LikesController(restaurants: restaurants, swipes: swipes,
          authEvents: auth);
      addTearDown(() {
        scoped.dispose();
        auth.events.close();
      });
      await scoped.ensureLoaded();
      expect(scoped.isLiked(7), isTrue);

      auth.events.add(_signedIn('user-b'));
      await Future<void>.delayed(Duration.zero);

      expect(scoped.isLoaded, isFalse);
      expect(scoped.liked, isEmpty);
      expect(scoped.isLiked(7), isFalse,
          reason: "user A's hearts must not survive into user B's session");
    });

    test('signing out clears the cache', () async {
      final auth = _FakeAuthEvents(userId: 'user-a');
      restaurants.likedRows = [testRestaurant(7)];
      final scoped = LikesController(restaurants: restaurants, swipes: swipes,
          authEvents: auth);
      addTearDown(() {
        scoped.dispose();
        auth.events.close();
      });
      await scoped.ensureLoaded();

      auth.events.add(const AuthState(AuthChangeEvent.signedOut, null));
      await Future<void>.delayed(Duration.zero);

      expect(scoped.isLoaded, isFalse);
      expect(scoped.liked, isEmpty);
    });

    test('a stale load settling cannot clear a newer load\'s handle',
        () async {
      // reset() nulls the shared _loading handle; when the discarded load
      // finally settles it must recognise the handle now belongs to a newer
      // request, or "only fetches once" silently breaks after every account
      // change.
      final backend = _GatedRestaurantRepository()
        ..likedRows = [testRestaurant(7)];
      final scoped = LikesController(
        restaurants: backend,
        swipes: swipes,
        followAuthChanges: false,
      );
      addTearDown(scoped.dispose);

      final stale = scoped.ensureLoaded();
      scoped.reset();
      final fresh = scoped.ensureLoaded(); // new handle before stale settles
      backend.gate.complete();
      await stale;
      await fresh;

      expect(scoped.isLoaded, isTrue);
      // Both loads went through the same gated backend: the stale one was
      // discarded by the generation bump, the fresh one published.
      expect(backend.likedFetches, 2);

      await scoped.ensureLoaded();
      expect(backend.likedFetches, 2,
          reason: 'a loaded controller must not fetch again');
    });
  });
}
