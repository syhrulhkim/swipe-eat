import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/wishlist/models/wishlist_item.dart';
import 'package:swipe_eat/features/wishlist/state/wishlist_controller.dart';

import 'fake_wishlist_repository.dart';

/// A list fetch that parks until the test releases it, so a [reset] can land
/// while the request is still in flight.
class _GatedListRepository extends FakeWishlistRepository {
  _GatedListRepository({super.rows});

  final Completer<void> gate = Completer<void>();

  @override
  Future<List<WishlistItem>> list({int limit = 200}) async {
    await gate.future;
    return super.list(limit: limit);
  }
}

/// A write that parks the same way, so a reset can land between the
/// optimistic edit and the write settling.
class _GatedWriteRepository extends FakeWishlistRepository {
  _GatedWriteRepository({super.rows});

  final Completer<void> gate = Completer<void>();

  @override
  Future<void> markEaten(int id, bool eaten) async {
    await gate.future;
    return super.markEaten(id, eaten);
  }

  @override
  Future<WishlistItem> addManual(String title) async {
    await gate.future;
    return super.addManual(title);
  }
}

void main() {
  late FakeWishlistRepository repository;
  late WishlistController controller;

  setUp(() {
    repository = FakeWishlistRepository();
    controller = WishlistController(repository: repository);
  });

  tearDown(() => controller.dispose());

  group('WishlistItem ordering', () {
    test('puts the to-go half first, newest first inside each', () {
      final ordered = sortWishlist([
        testWishlistItem(1, title: 'Old to go'),
        testWishlistItem(4, title: 'Old eaten', eatenAt: DateTime(2026, 8, 20)),
        testWishlistItem(3, title: 'New to go'),
        testWishlistItem(6, title: 'New eaten', eatenAt: DateTime(2026, 8, 21)),
      ]);

      expect(
        ordered.map((item) => item.title),
        ['New to go', 'Old to go', 'New eaten', 'Old eaten'],
      );
    });
  });

  group('WishlistItem subtitle', () {
    test('joins cuisine, neighbourhood and the 24 h note', () {
      final item = WishlistItem.fromJson({
        'id': 1,
        'title': 'Roti Canai Corner',
        'source': 'friend',
        'created_at': '2026-08-01T00:00:00Z',
        'restaurants': {
          'id': 9,
          'name': 'Roti Canai Corner',
          'tag': 'Mamak',
          'neighbourhood': 'TTDI',
          'opens_at': '00:00:00',
          'closes_at': '00:00:00',
          'closed_dow': <int>[],
          'restaurant_images': [
            {'url': 'https://example.com/2.jpg', 'position': 1},
            {'url': 'https://example.com/1.jpg', 'position': 0},
          ],
        },
      });

      expect(item.subtitle, 'Mamak · TTDI · open 24 h');
      // The cover is the lowest-positioned image, not the first in the array.
      expect(item.coverUrl, 'https://example.com/1.jpg');
      expect(item.source, WishlistSource.friend);
    });

    test('a manual row with no restaurant has an empty subtitle', () {
      final item = WishlistItem.fromJson({
        'id': 2,
        'title': 'That place Ali mentioned',
        'source': 'manual',
        'created_at': '2026-08-01T00:00:00Z',
      });

      expect(item.subtitle, isEmpty);
      expect(item.coverUrl, isNull);
      expect(item.restaurantId, isNull);
    });

    test('survives a null restaurants join on a restaurant row', () {
      // The catalog policy can hide the joined row; the wishlist line still
      // has to render, off its own stored title.
      final item = WishlistItem.fromJson({
        'id': 3,
        'restaurant_id': 42,
        'title': 'Hidden Stall',
        'source': 'swiped',
        'created_at': '2026-08-01T00:00:00Z',
        'restaurants': null,
      });

      expect(item.title, 'Hidden Stall');
      expect(item.restaurantId, 42);
      expect(item.subtitle, isEmpty);
    });

    test('an unknown source parses as manual rather than throwing', () {
      expect(WishlistSource.fromWire('something_new'), WishlistSource.manual);
      expect(WishlistSource.fromWire(null), WishlistSource.manual);
    });
  });

  group('WishlistController load', () {
    test('publishes the rows in list order and counts both halves', () async {
      repository = FakeWishlistRepository(rows: [
        testWishlistItem(1, title: 'To Go One'),
        testWishlistItem(2, title: 'To Go Two'),
        testWishlistItem(3, title: 'Eaten', eatenAt: DateTime(2026, 8, 24)),
      ]);
      controller = WishlistController(repository: repository);

      await controller.ensureLoaded();

      expect(controller.isLoaded, isTrue);
      expect(controller.toGoCount, 2);
      expect(controller.eatenCount, 1);
      expect(controller.items.last.title, 'Eaten');
    });

    test('ensureLoaded fetches once for concurrent callers', () async {
      await Future.wait([
        controller.ensureLoaded(),
        controller.ensureLoaded(),
        controller.ensureLoaded(),
      ]);

      expect(repository.calls.where((call) => call == 'list').length, 1);
    });

    test('a failed load reports itself and retries on the next call', () async {
      repository.failList = true;
      await controller.ensureLoaded();

      expect(controller.isLoaded, isFalse);
      expect(controller.error, 'Could not load your wishlist.');

      repository.failList = false;
      await controller.ensureLoaded();

      expect(controller.isLoaded, isTrue);
      expect(controller.error, isNull);
    });
  });

  group('WishlistController toggleEaten', () {
    test('crosses a row off and sinks it to the bottom', () async {
      repository = FakeWishlistRepository(rows: [
        testWishlistItem(1, title: 'First'),
        testWishlistItem(2, title: 'Second'),
      ]);
      controller = WishlistController(repository: repository);
      await controller.ensureLoaded();
      expect(controller.items.first.title, 'Second');

      await controller.toggleEaten(2);

      expect(controller.items.map((item) => item.title), ['First', 'Second']);
      expect(controller.items.last.isEaten, isTrue);
      expect(controller.toGoCount, 1);
      expect(controller.eatenCount, 1);
    });

    test('toggles back and the row rises again', () async {
      repository = FakeWishlistRepository(rows: [
        testWishlistItem(1, title: 'First'),
        testWishlistItem(2, title: 'Second', eatenAt: DateTime(2026, 8, 24)),
      ]);
      controller = WishlistController(repository: repository);
      await controller.ensureLoaded();
      expect(controller.items.last.title, 'Second');

      await controller.toggleEaten(2);

      expect(controller.items.first.title, 'Second');
      expect(controller.eatenCount, 0);
    });

    test('paints before the write lands', () async {
      repository = FakeWishlistRepository(rows: [testWishlistItem(1)]);
      controller = WishlistController(repository: repository);
      await controller.ensureLoaded();

      // Not awaited: the point is that the row is already crossed off before
      // the repository has answered.
      final pending = controller.toggleEaten(1);
      expect(controller.items.single.isEaten, isTrue);

      await pending;
      expect(repository.calls, contains('markEaten:1:true'));
    });

    test('a refused write puts the row back and says so', () async {
      repository = FakeWishlistRepository(rows: [testWishlistItem(1)]);
      controller = WishlistController(repository: repository);
      await controller.ensureLoaded();
      repository.failWrite = true;

      await controller.toggleEaten(1);

      expect(controller.items.single.isEaten, isFalse);
      expect(controller.error, 'Could not update that place.');
    });
  });

  group('WishlistController addManual', () {
    test('adds the typed place at the top of the to-go half', () async {
      repository = FakeWishlistRepository(rows: [testWishlistItem(1)]);
      controller = WishlistController(repository: repository);
      await controller.ensureLoaded();

      await controller.addManual('  Nasi Kandar Line Clear  ');

      expect(controller.items.first.title, 'Nasi Kandar Line Clear');
      expect(controller.items.first.source, WishlistSource.manual);
      expect(controller.toGoCount, 2);
    });

    test('blank input writes nothing', () async {
      await controller.ensureLoaded();

      await controller.addManual('   ');

      expect(repository.calls.any((call) => call.startsWith('addManual')),
          isFalse);
      expect(controller.items, isEmpty);
    });

    test('typing a place after a failed load does not stand in for the list',
        () async {
      // The add bar is live in the error state, so this is reachable: the
      // fetch failed, the user typed somewhere anyway. Publishing that one row
      // as "the list" would hide every place already on the server behind it,
      // and mark the controller loaded so nothing ever goes back for them.
      repository = FakeWishlistRepository(rows: [
        testWishlistItem(1, title: 'Already Saved'),
      ])
        ..failList = true;
      controller = WishlistController(repository: repository);
      await controller.ensureLoaded();
      expect(controller.isLoaded, isFalse);

      repository.failList = false;
      await controller.addManual('Line Clear');

      expect(
        controller.items.map((item) => item.title),
        containsAll(<String>['Line Clear', 'Already Saved']),
      );
      expect(controller.toGoCount, 2);
    });

    test('a refused add says so and leaves the list alone', () async {
      await controller.ensureLoaded();
      repository.failWrite = true;

      await controller.addManual('Somewhere');

      expect(controller.items, isEmpty);
      expect(controller.error, 'Could not add that place.');
    });
  });

  group('WishlistController clearEaten', () {
    test('empties the eaten half and keeps the rest', () async {
      repository = FakeWishlistRepository(rows: [
        testWishlistItem(1, title: 'Still To Go'),
        testWishlistItem(2, title: 'Eaten One', eatenAt: DateTime(2026, 8, 1)),
        testWishlistItem(3, title: 'Eaten Two', eatenAt: DateTime(2026, 8, 2)),
      ]);
      controller = WishlistController(repository: repository);
      await controller.ensureLoaded();

      await controller.clearEaten();

      expect(controller.items.map((item) => item.title), ['Still To Go']);
      expect(controller.eatenCount, 0);
      expect(repository.rows.length, 1);
    });

    test('with nothing eaten it does not call the backend', () async {
      repository = FakeWishlistRepository(rows: [testWishlistItem(1)]);
      controller = WishlistController(repository: repository);
      await controller.ensureLoaded();

      await controller.clearEaten();

      expect(repository.calls, isNot(contains('clearEaten')));
    });

    test('a refused clear brings the rows back', () async {
      repository = FakeWishlistRepository(rows: [
        testWishlistItem(1, title: 'Still To Go'),
        testWishlistItem(2, title: 'Eaten One', eatenAt: DateTime(2026, 8, 1)),
      ]);
      controller = WishlistController(repository: repository);
      await controller.ensureLoaded();
      repository.failWrite = true;

      await controller.clearEaten();

      expect(controller.eatenCount, 1);
      expect(controller.error, 'Could not clear those.');
    });
  });

  group('WishlistController remove', () {
    test('drops the row, and restores it when the write is refused', () async {
      repository = FakeWishlistRepository(rows: [
        testWishlistItem(1, title: 'One'),
        testWishlistItem(2, title: 'Two'),
      ]);
      controller = WishlistController(repository: repository);
      await controller.ensureLoaded();

      await controller.remove(1);
      expect(controller.items.map((item) => item.title), ['Two']);

      repository.failWrite = true;
      await controller.remove(2);
      expect(controller.items.map((item) => item.title), ['Two']);
      expect(controller.error, 'Could not remove that place.');
    });
  });

  group('WishlistController stale responses', () {
    test('a load in flight cannot publish into the next account', () async {
      // The leak this guards: user A signs out mid-load, user B signs in, and
      // A's places land on B's list.
      final backing = _GatedListRepository(rows: [testWishlistItem(1)]);
      final scoped = WishlistController(repository: backing);
      addTearDown(scoped.dispose);

      final inFlight = scoped.refresh();
      scoped.reset(); // the account changed underneath the request
      backing.gate.complete();
      await inFlight;

      expect(scoped.items, isEmpty);
      expect(scoped.isLoaded, isFalse,
          reason: 'the next ensureLoaded must refetch for whoever is signed '
              'in now, not settle for the previous account');
      expect(scoped.loading, isFalse,
          reason: 'a discarded load must not leave the screen spinning');
    });

    test('a load that fails after a reset reports nothing', () async {
      final backing = _GatedListRepository()..failList = true;
      final scoped = WishlistController(repository: backing);
      addTearDown(scoped.dispose);

      final inFlight = scoped.refresh();
      scoped.reset();
      backing.gate.complete();
      await inFlight;

      expect(scoped.error, isNull,
          reason:
              'the failure belongs to a list nobody is looking at any more');
    });

    test('an add in flight cannot publish into the next account', () async {
      final backing = _GatedWriteRepository();
      final scoped = WishlistController(repository: backing);
      addTearDown(scoped.dispose);

      final pending = scoped.addManual('Line Clear');
      scoped.reset();
      backing.gate.complete();
      await pending;

      expect(scoped.items, isEmpty);
      expect(scoped.isLoaded, isFalse);
    });

    test('a write that fails after a reset does not resurrect the row',
        () async {
      final backing = _GatedWriteRepository(rows: [testWishlistItem(1)])
        ..failWrite = true;
      final scoped = WishlistController(repository: backing);
      addTearDown(scoped.dispose);
      await scoped.ensureLoaded();

      final pending = scoped.toggleEaten(1);
      scoped.reset();
      backing.gate.complete();
      await pending;

      expect(scoped.items, isEmpty);
      expect(scoped.error, isNull);
    });

    test('a stale load settling cannot clear a newer load\'s handle', () async {
      // reset() nulls the shared handle; when the discarded load finally
      // settles it must recognise the handle now belongs to a newer request,
      // or "fetches once" silently breaks after every account change.
      final backing = _GatedListRepository(rows: [testWishlistItem(1)]);
      final scoped = WishlistController(repository: backing);
      addTearDown(scoped.dispose);

      final stale = scoped.ensureLoaded();
      scoped.reset();
      final fresh = scoped.ensureLoaded(); // new handle before stale settles
      backing.gate.complete();
      await stale;
      await fresh;

      expect(scoped.isLoaded, isTrue);
      expect(scoped.items.length, 1);
      final fetches = backing.calls.where((call) => call == 'list').length;
      expect(fetches, 2);

      await scoped.ensureLoaded();
      expect(backing.calls.where((call) => call == 'list').length, fetches,
          reason: 'a loaded controller must not fetch again');
    });
  });

  group('WishlistController reset', () {
    test('forgets everything and refetches next time', () async {
      repository = FakeWishlistRepository(rows: [testWishlistItem(1)]);
      controller = WishlistController(repository: repository);
      await controller.ensureLoaded();

      controller.reset();
      expect(controller.isLoaded, isFalse);
      expect(controller.items, isEmpty);

      await controller.ensureLoaded();
      expect(controller.items.length, 1);
    });
  });

  group('WishlistController.addRestaurant', () {
    test('adds a catalogue place and finds it again by restaurant id',
        () async {
      await controller.ensureLoaded();
      await controller.addRestaurant(7, title: 'Warung Kak Ros');

      expect(repository.calls, contains('addRestaurant:7'));
      final item = controller.itemForRestaurant(7);
      expect(item, isNotNull);
      expect(item!.title, 'Warung Kak Ros');
      expect(controller.toGoCount, 1);
    });

    test('a place already on the list is a no-op, not a second row', () async {
      repository = FakeWishlistRepository(rows: [
        testWishlistItem(1, restaurantId: 7),
      ]);
      controller = WishlistController(repository: repository);
      await controller.ensureLoaded();

      await controller.addRestaurant(7);

      expect(repository.calls.contains('addRestaurant:7'), isFalse);
      expect(controller.items.length, 1);
    });

    test('itemForRestaurant answers null for a place nobody saved', () async {
      await controller.ensureLoaded();

      expect(controller.itemForRestaurant(99), isNull);
    });

    test('a refused write reports itself and adds nothing', () async {
      repository.failWrite = true;
      await controller.ensureLoaded();

      await controller.addRestaurant(7);

      expect(controller.error, 'Could not add that place.');
      expect(controller.items, isEmpty);
    });
  });
}
