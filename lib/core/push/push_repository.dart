import 'package:supabase_flutter/supabase_flutter.dart';

/// The device's own row in `push_tokens`.
///
/// One row per token, not per user: a person with a phone and a tablet is two
/// rows, and the edge function sends to every one it finds. The row carries
/// `user_id` because RLS checks it — the policy is own-row, and a body without
/// it would be refused rather than defaulted.
class PushRepository {
  PushRepository({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;

  /// Resolved per call, like the other repositories: nothing here may need an
  /// initialised singleton just to be constructed.
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  static const _timeout = Duration(seconds: 15);

  /// Claims [token] for the signed-in user. Silent when nobody is signed in —
  /// a token with no owner is not a row this table can hold, and the service
  /// saves again on the next sign-in.
  Future<void> saveToken(String token, {required String platform}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    await _client.from('push_tokens').upsert({
      'token': token,
      'user_id': userId,
      'platform': platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).timeout(_timeout);
  }

  /// Drops the row on sign-out, so the next push for that account does not
  /// buzz a phone somebody else is now holding.
  Future<void> deleteToken(String token) async {
    await _client
        .from('push_tokens')
        .delete()
        .eq('token', token)
        .timeout(_timeout);
  }
}
