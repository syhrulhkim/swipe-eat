import 'package:supabase_flutter/supabase_flutter.dart';

/// One restaurant reduced to what a signed-out screen can show: a name and a
/// cover. The welcome stack and the sign-up hero need nothing else, and asking
/// for nothing else keeps the query readable by `anon`.
class AuthCover {
  const AuthCover({required this.name, required this.imageUrl});

  final String name;

  /// Null when the row has no cached image yet — the card then falls back to
  /// a plain surface rather than a broken picture.
  final String? imageUrl;

  static AuthCover? fromRow(Map<String, dynamic> row) {
    final name = row['name'];
    if (name is! String || name.isEmpty) {
      return null;
    }

    final images = row['restaurant_images'];
    String? url;
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map && first['url'] is String) {
        url = first['url'] as String;
      }
    }

    return AuthCover(name: name, imageUrl: url);
  }
}

/// Injected into the welcome and sign-up screens so a widget test can hand
/// them covers — or a failure — without a network or an initialised Supabase.
typedef AuthCoverLoader = Future<List<AuthCover>> Function(int limit);

/// The catalogue read the signed-out screens make.
///
/// A plain select rather than one of the deck RPCs: those rank against the
/// caller's own swipes and profile, and there is no caller yet. `restaurants`
/// and `restaurant_images` are readable by `anon` (Backend-Schema §4), so this
/// is the one query the app can make before anybody signs in.
class AuthCoverRepository {
  const AuthCoverRepository({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;

  /// Resolved per call, never in the constructor: a page must be constructible
  /// in a test that never initialised Supabase, so the failure belongs to the
  /// request — where the caller already has to handle one.
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  static const _timeout = Duration(seconds: 10);

  Future<List<AuthCover>> fetchCovers(int limit) async {
    final rows = await _client
        .from('restaurants')
        .select('name, restaurant_images!inner(url, position)')
        // `!inner` above drops rows with no image at all; this keeps the
        // gallery's first picture rather than an arbitrary one.
        .order('position', referencedTable: 'restaurant_images')
        .limit(1, referencedTable: 'restaurant_images')
        .order('rating', ascending: false)
        .limit(limit)
        .timeout(_timeout);

    return [
      for (final row in rows)
        if (AuthCover.fromRow(row) case final cover?) cover,
    ];
  }
}

/// The default loader the two screens use when nothing is injected.
Future<List<AuthCover>> loadAuthCovers(int limit) =>
    const AuthCoverRepository().fetchCovers(limit);
