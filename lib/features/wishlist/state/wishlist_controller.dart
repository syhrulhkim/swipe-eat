import 'package:flutter/foundation.dart';

import '../data/wishlist_repository.dart';
import '../models/wishlist_item.dart';

/// The Wishlist screen's state: the list, whether it is loading, and the
/// optimistic edits in flight.
///
/// Every write here paints first and asks the server second, because the whole
/// screen is a checklist — a tick that waits for a round trip before it
/// appears is a tick that feels broken. A failed write puts the row back the
/// way it was and reports the error; nothing is silently lost.
class WishlistController extends ChangeNotifier {
  WishlistController({WishlistRepository? repository})
      : _repository = repository ?? WishlistRepository();

  /// The one copy the app shares. The detail page and the Wishlist screen used
  /// to each build their own and refetch the whole list per open; one list,
  /// loaded once, is what every other account-scoped controller here does.
  /// Emptied on sign-out by [LikesController.reset], which already watches
  /// auth for the same reason.
  static final WishlistController instance = WishlistController();

  final WishlistRepository _repository;

  List<WishlistItem> _items = const [];
  bool _loaded = false;
  bool _loading = false;
  String? _error;
  Future<void>? _pending;

  /// Bumped by [reset] so an in-flight load cannot publish stale rows over a
  /// list that has since been emptied.
  int _generation = 0;

  List<WishlistItem> get items => List.unmodifiable(_items);
  bool get isLoaded => _loaded;
  bool get loading => _loading;
  String? get error => _error;

  /// Still to go, and already eaten — the two numbers in the header.
  int get toGoCount => _items.where((item) => !item.isEaten).length;
  int get eatenCount => _items.where((item) => item.isEaten).length;

  bool get isEmpty => _loaded && _items.isEmpty;

  /// Loads once; concurrent callers share the request. A failed load clears
  /// its handle so the next call retries rather than caching the failure.
  Future<void> ensureLoaded() {
    if (_loaded) {
      return Future.value();
    }
    final pending = _pending;
    if (pending != null) {
      return pending;
    }
    late final Future<void> load;
    load = refresh().whenComplete(() {
      // Identity check, not a blind null: reset() drops the handle and a newer
      // load may own it by the time this stale future settles.
      if (identical(_pending, load)) {
        _pending = null;
      }
    });
    _pending = load;
    return load;
  }

  Future<void> refresh() async {
    final generation = _generation;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await _repository.list();
      if (generation != _generation) {
        return;
      }
      _items = rows;
      _loaded = true;
    } on Object catch (error) {
      debugPrint('Wishlist load failed: $error');
      if (generation != _generation) {
        return;
      }
      _error = 'Could not load your wishlist.';
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Crosses a row off, or puts it back. The strike-through, the grey photo
  /// and the sink to the bottom all follow from this one field, so they all
  /// happen on the tap.
  Future<void> toggleEaten(int id) async {
    final generation = _generation;
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) {
      return;
    }

    final before = _items[index];
    final eaten = !before.isEaten;
    _replace(
      id,
      eaten
          ? before.copyWith(eatenAt: DateTime.now())
          : before.copyWith(clearEatenAt: true),
    );

    try {
      await _repository.markEaten(id, eaten);
    } on Object catch (error) {
      debugPrint('Wishlist toggle failed: $error');
      if (generation == _generation) {
        _replace(id, before);
        _error = 'Could not update that place.';
        notifyListeners();
      }
    }
  }

  /// A place the user typed. It lands at the top of the to-go half, because
  /// [sortWishlist] orders by creation and this is the newest thing on the
  /// list.
  ///
  /// Blank input is not an error, it is a no-op — the plus button being live
  /// with an empty field is a design choice, not a promise to store nothing.
  /// Returns whether the row landed, so the caller can decide what to do with
  /// the text the user typed: keeping it on a failure is the difference
  /// between a retry and retyping.
  Future<bool> addManual(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final generation = _generation;

    try {
      final item = await _repository.addManual(trimmed);
      if (generation != _generation) {
        // The account changed under the write. The row is on the server for
        // whoever wrote it, so the text is not worth keeping here.
        return true;
      }
      if (!_loaded) {
        // The add bar is live in the error state, so a place can be typed
        // before the list has ever arrived. One row is not the list: publishing
        // it as one would hide everything already on the server behind it, and
        // mark the controller loaded so nothing went back for the rest. Fetch
        // instead — the row is written, and the fetch returns it with the
        // others.
        await refresh();
        return _error == null;
      }
      _items = sortWishlist([item, ..._items]);
      _error = null;
      notifyListeners();
      return true;
    } on Object catch (error) {
      debugPrint('Wishlist add failed: $error');
      if (generation == _generation) {
        _error = 'Could not add that place.';
        notifyListeners();
      }
      return false;
    }
  }

  /// The restaurant's row, if it has one. The detail screen's bookmark reads
  /// its filled state from this rather than from [LikesController], because
  /// the wishlist is the thing it toggles and a second source could disagree.
  WishlistItem? itemForRestaurant(int restaurantId) {
    for (final item in _items) {
      if (item.restaurantId == restaurantId) {
        return item;
      }
    }
    return null;
  }

  /// Puts a catalogue restaurant on the list — the detail screen's bookmark.
  ///
  /// Unlike [addManual] this cannot paint first: the row's id comes from the
  /// insert, and the bookmark has to be able to un-add what it just added. A
  /// restaurant already on the list is a no-op, not an error, which is what
  /// the repository's duplicate-null means.
  Future<void> addRestaurant(int restaurantId, {String? title}) async {
    final generation = _generation;
    if (itemForRestaurant(restaurantId) != null) {
      return;
    }

    try {
      final item = await _repository.addRestaurant(
        restaurantId,
        title: title,
      );
      if (generation != _generation || item == null) {
        return;
      }
      _items = sortWishlist([item, ..._items]);
      _loaded = true;
      _error = null;
      notifyListeners();
    } on Object catch (error) {
      debugPrint('Wishlist add failed: $error');
      if (generation == _generation) {
        _error = 'Could not add that place.';
        notifyListeners();
      }
    }
  }

  Future<void> remove(int id) async {
    final generation = _generation;
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) {
      return;
    }
    final removed = _items[index];
    _items = [
      for (final item in _items)
        if (item.id != id) item,
    ];
    notifyListeners();

    try {
      await _repository.remove(id);
    } on Object catch (error) {
      debugPrint('Wishlist remove failed: $error');
      if (generation == _generation) {
        _items = sortWishlist([..._items, removed]);
        _error = 'Could not remove that place.';
        notifyListeners();
      }
    }
  }

  /// Empties the eaten half. Optimistic like the rest: the rows go, and come
  /// back together if the delete did not land.
  Future<void> clearEaten() async {
    final generation = _generation;
    final cleared = [
      for (final item in _items)
        if (item.isEaten) item,
    ];
    if (cleared.isEmpty) {
      return;
    }
    _items = [
      for (final item in _items)
        if (!item.isEaten) item,
    ];
    notifyListeners();

    try {
      await _repository.clearEaten();
    } on Object catch (error) {
      debugPrint('Wishlist clear failed: $error');
      if (generation == _generation) {
        _items = sortWishlist([..._items, ...cleared]);
        _error = 'Could not clear those.';
        notifyListeners();
      }
    }
  }

  /// Forgets everything; the next [ensureLoaded] refetches. Called when the
  /// account changes, for the same reason [LikesController] does it.
  void reset() {
    _generation++;
    _items = const [];
    _loaded = false;
    _loading = false;
    _error = null;
    _pending = null;
    notifyListeners();
  }

  void _replace(int id, WishlistItem item) {
    _items = sortWishlist([
      for (final existing in _items)
        if (existing.id == id) item else existing,
    ]);
    notifyListeners();
  }
}
