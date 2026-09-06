import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wishlist_item.dart';

/// Reads and writes `wishlist_items` — the store behind the deck's Later
/// gesture and behind the Wishlist screen.
///
/// Own-row RLS does the scoping, so nothing here filters by user: a query that
/// forgot to would return an empty list rather than somebody else's places.
class WishlistRepository {
  WishlistRepository({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;

  /// Resolved per call rather than in the constructor, so a page can be built
  /// in a test without an initialised `Supabase.instance` — the failure
  /// belongs to the request, where it can be caught and retried.
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  /// The row plus everything a wishlist line shows. The join is nullable on
  /// purpose: a manual entry has no restaurant, and the model reads the title
  /// off the row itself.
  static const _columns = 'id, restaurant_id, title, source, from_user_id, '
      'eaten_at, created_at, '
      'restaurants(id, name, tag, neighbourhood, opens_at, closes_at, '
      'closed_dow, restaurant_images(url, position))';

  // A stalled connection would otherwise never resolve; surface it as an error
  // so the UI can offer a retry instead of spinning forever.
  static const _timeout = Duration(seconds: 15);

  /// The whole list, in the order the screen shows it: to go first, then
  /// eaten, newest first inside each half.
  ///
  /// The server orders it and [sortWishlist] orders it again, which is not
  /// redundancy — the second call is the one the optimistic toggles reuse, so
  /// running it here too means the loaded list and the edited list can never
  /// disagree about what "in order" means.
  Future<List<WishlistItem>> list({int limit = 200}) async {
    final rows = await _client
        .from('wishlist_items')
        .select(_columns)
        .order('eaten_at', ascending: true, nullsFirst: true)
        .order('created_at', ascending: false)
        .limit(limit)
        .timeout(_timeout);

    return sortWishlist(rows.map(WishlistItem.fromJson));
  }

  /// A place the user typed rather than swiped. Carries no restaurant, which
  /// is why the table only allows that for `manual`.
  Future<WishlistItem> addManual(String title) async {
    final row = await _client
        .from('wishlist_items')
        .insert({
          'user_id': _userId,
          'title': title.trim(),
          'source': WishlistSource.manual.wire,
        })
        .select(_columns)
        .single()
        .timeout(_timeout);

    return WishlistItem.fromJson(row);
  }

  /// Puts a catalogue restaurant on the list — the Later gesture's write.
  ///
  /// [title] is optional because the caller usually has not got one: the deck
  /// hands this controller an id and nothing else. Left null, the name is read
  /// from the catalogue here, so the stored title is still a real name and the
  /// row still renders when the restaurant later goes away.
  ///
  /// Returns null when the place was already on the list *and still to go*. A
  /// partial unique index cannot be named as an upsert's conflict target over
  /// PostgREST (Postgres wants the index predicate; PostgREST sends none), so
  /// the duplicate is caught rather than pre-empted — and 23505 here means
  /// "already saved", which is success as far as the user's gesture goes.
  ///
  /// One duplicate is not success: a place the user already ticked off. Saying
  /// "Later" to somewhere you ate months ago is a request to go again, so the
  /// existing row is put back on the to-go half rather than left crossed out.
  Future<WishlistItem?> addRestaurant(
    int restaurantId, {
    WishlistSource source = WishlistSource.swiped,
    String? title,
    String? fromUserId,
  }) async {
    final name = title ?? await _restaurantName(restaurantId);

    try {
      final row = await _client
          .from('wishlist_items')
          .insert({
            'user_id': _userId,
            'restaurant_id': restaurantId,
            'title': name,
            'source': source.wire,
            if (fromUserId != null) 'from_user_id': fromUserId,
          })
          .select(_columns)
          .single()
          .timeout(_timeout);

      return WishlistItem.fromJson(row);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        return _revive(restaurantId);
      }
      rethrow;
    }
  }

  /// Puts an already-saved place back on the to-go half. Returns the row when
  /// it had been eaten (so the caller knows the list changed), and null when
  /// it was already waiting — the caller's gesture landed either way.
  Future<WishlistItem?> _revive(int restaurantId) async {
    final rows = await _client
        .from('wishlist_items')
        .update({'eaten_at': null})
        .eq('user_id', _userId)
        .eq('restaurant_id', restaurantId)
        .not('eaten_at', 'is', null)
        .select(_columns)
        .timeout(_timeout);

    if (rows.isEmpty) {
      return null;
    }
    return WishlistItem.fromJson(rows.first);
  }

  /// The catalogue name, or a neutral stand-in when the row is hidden or gone.
  /// Never throws for a missing row: failing a save because the name could not
  /// be read would lose the user's gesture over a label.
  Future<String> _restaurantName(int restaurantId) async {
    final rows = await _client
        .from('restaurants')
        .select('name')
        .eq('id', restaurantId)
        .limit(1)
        .timeout(_timeout);

    if (rows.isEmpty) {
      return 'A place';
    }
    return rows.first['name'] as String? ?? 'A place';
  }

  /// Crosses a row off, or puts it back. The timestamp is the device's — only
  /// an RPC could stamp `now()` server-side, and nothing here reads the value
  /// back for ordering, so the phone's clock is close enough.
  Future<void> markEaten(int id, bool eaten) async {
    await _client
        .from('wishlist_items')
        .update({'eaten_at': eaten ? DateTime.now().toUtc().toIso8601String() : null})
        .eq('id', id)
        .timeout(_timeout);
  }

  Future<void> remove(int id) async {
    await _client.from('wishlist_items').delete().eq('id', id).timeout(_timeout);
  }

  /// Empties the bottom half of the list. Deletes rather than archives: the
  /// wishlist is a checklist, and a checklist you cannot clear is a log.
  Future<void> clearEaten() async {
    await _client
        .from('wishlist_items')
        .delete()
        .not('eaten_at', 'is', null)
        .timeout(_timeout);
  }

  /// Removes whatever row points at this restaurant, if any. The unlike path
  /// uses it: a place you have taken back off your likes is not a place you
  /// are still planning to eat.
  Future<void> removeRestaurant(int restaurantId) async {
    await _client
        .from('wishlist_items')
        .delete()
        .eq('restaurant_id', restaurantId)
        .timeout(_timeout);
  }

  /// Insert needs the id explicitly — RLS checks it, it has no default.
  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Cannot write a wishlist item while signed out.');
    }
    return id;
  }
}
