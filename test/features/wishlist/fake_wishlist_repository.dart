import 'package:swipe_eat/features/wishlist/data/wishlist_repository.dart';
import 'package:swipe_eat/features/wishlist/models/wishlist_item.dart';

/// A minimal but real [WishlistItem] for list fixtures.
WishlistItem testWishlistItem(
  int id, {
  String? title,
  WishlistSource source = WishlistSource.swiped,
  int? restaurantId,
  DateTime? eatenAt,
  DateTime? createdAt,
  String? tag = 'Nasi lemak',
  String? neighbourhood = 'Kampung Baru',
  String? coverUrl,
  String? fromUserId,
  String? fromUserName,
}) {
  return WishlistItem(
    id: id,
    title: title ?? 'Place $id',
    source: source,
    restaurantId: restaurantId ?? (source == WishlistSource.manual ? null : id),
    fromUserId: fromUserId,
    fromUserName: fromUserName,
    eatenAt: eatenAt,
    // Ids ascend with time by default, so a fixture list is in a predictable
    // order without every case spelling out timestamps.
    createdAt: createdAt ?? DateTime(2026, 8, 1).add(Duration(days: id)),
    coverUrl: coverUrl,
    tag: tag,
    neighbourhood: neighbourhood,
  );
}

/// Stands in for the `wishlist_items` table: it applies the same rules the
/// database would (own rows only is implicit, the unique index rejects a
/// second row for one restaurant) so a controller test exercises the real
/// behaviour rather than a permissive stub.
class FakeWishlistRepository implements WishlistRepository {
  FakeWishlistRepository({List<WishlistItem> rows = const []})
      : _rows = List.of(rows);

  List<WishlistItem> _rows;

  /// Next id handed out by an insert. Above any fixture id so a new row never
  /// collides with one the test placed itself.
  int _nextId = 1000;

  bool failList = false;
  bool failWrite = false;

  /// Every call, in order, so a test can assert what reached the backend.
  final List<String> calls = [];

  List<WishlistItem> get rows => List.unmodifiable(_rows);

  /// Replaces the stored rows, for a test that wants a different starting list
  /// than the one it was constructed with without swapping the instance a
  /// controller is already holding.
  void seed(List<WishlistItem> rows) => _rows = List.of(rows);

  /// The ids still to go and backed by a real restaurant — what
  /// `LikesController.isSavedForLater` answers. Matches
  /// `RestaurantRepository.laterIds`'s query.
  Set<int> pendingRestaurantIds() {
    return {
      for (final row in _rows)
        if (!row.isEaten && row.restaurantId != null) row.restaurantId!,
    };
  }

  @override
  Future<List<WishlistItem>> list({int limit = 200}) async {
    calls.add('list');
    if (failList) {
      throw Exception('wishlist unavailable');
    }
    return sortWishlist(_rows);
  }

  @override
  Future<WishlistItem> addManual(String title) async {
    calls.add('addManual:$title');
    if (failWrite) {
      throw Exception('write refused');
    }
    final item = WishlistItem(
      id: _nextId++,
      title: title.trim(),
      source: WishlistSource.manual,
      createdAt: DateTime.now(),
    );
    _rows = [..._rows, item];
    return item;
  }

  @override
  Future<WishlistItem?> addRestaurant(
    int restaurantId, {
    WishlistSource source = WishlistSource.swiped,
    String? title,
    String? fromUserId,
  }) async {
    calls.add('addRestaurant:$restaurantId');
    if (failWrite) {
      throw Exception('write refused');
    }
    // The unique index: one row per restaurant per user. An existing row that
    // was ticked off comes back to the to-go half, as the real repository's
    // 23505 branch does.
    final existing =
        _rows.where((row) => row.restaurantId == restaurantId).firstOrNull;
    if (existing != null) {
      if (existing.eatenAt == null) {
        return null;
      }
      final revived = existing.copyWith(clearEatenAt: true);
      _rows = [
        for (final row in _rows)
          if (row.id == existing.id) revived else row,
      ];
      return revived;
    }
    final item = WishlistItem(
      id: _nextId++,
      title: title ?? 'Restaurant $restaurantId',
      source: source,
      restaurantId: restaurantId,
      fromUserId: fromUserId,
      createdAt: DateTime.now(),
    );
    _rows = [..._rows, item];
    return item;
  }

  @override
  Future<void> markEaten(int id, bool eaten) async {
    calls.add('markEaten:$id:$eaten');
    if (failWrite) {
      throw Exception('write refused');
    }
    _rows = [
      for (final row in _rows)
        if (row.id == id)
          (eaten
              ? row.copyWith(eatenAt: DateTime.now())
              : row.copyWith(clearEatenAt: true))
        else
          row,
    ];
  }

  @override
  Future<void> remove(int id) async {
    calls.add('remove:$id');
    if (failWrite) {
      throw Exception('write refused');
    }
    _rows = [
      for (final row in _rows)
        if (row.id != id) row,
    ];
  }

  @override
  Future<void> clearEaten() async {
    calls.add('clearEaten');
    if (failWrite) {
      throw Exception('write refused');
    }
    _rows = [
      for (final row in _rows)
        if (!row.isEaten) row,
    ];
  }

  @override
  Future<void> removeRestaurant(int restaurantId) async {
    calls.add('removeRestaurant:$restaurantId');
    if (failWrite) {
      throw Exception('write refused');
    }
    _rows = [
      for (final row in _rows)
        if (row.restaurantId != restaurantId) row,
    ];
  }
}
