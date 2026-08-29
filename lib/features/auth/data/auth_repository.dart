import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../models/app_user.dart';
import 'oauth_provider_client.dart';

/// Outcome of a sign-up. Email confirmation is enabled on the project, so a
/// successful `signUp` returns a user but **no session** — the account only
/// becomes usable after the link in the email is opened. Callers must not
/// assume they are signed in afterwards.
enum SignUpOutcome {
  /// Session issued immediately (only happens with confirmation disabled).
  signedIn,

  /// Account created; the confirmation email has been sent.
  confirmationRequired,
}

/// Anything the auth layer can fail with, already turned into a sentence that
/// is safe to show a user. Supabase's raw messages leak internals ("Database
/// error querying schema"), so they are mapped rather than surfaced.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository({
    SupabaseClient? client,
    OAuthProviderClient? oauth,
  })  : _client = client ?? Supabase.instance.client,
        _oauth = oauth ?? const OAuthProviderClient();

  final SupabaseClient _client;
  final OAuthProviderClient _oauth;

  static const String _profileColumns =
      'id, name, avatar_url, onboarded_at, search_radius_km, last_place_name';

  GoTrueClient get _auth => _client.auth;

  Session? get currentSession => _auth.currentSession;

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  /// True when the running build has the client ids Google/Apple sign-in
  /// needs. Those come from out-of-repo console setup, so the buttons stay
  /// hidden until they are supplied rather than failing at tap time.
  bool get supportsGoogleSignIn => AppConfig.hasGoogleSignIn;

  bool get supportsAppleSignIn => _oauth.isAppleAvailable;

  /// Reads the profile row for the signed-in user. Returns null when there is
  /// no session. The row is created by the `handle_new_user` trigger, but a
  /// just-confirmed account can race it, so a missing row is retried once.
  Future<AppUser?> loadCurrentUser() async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      return null;
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      final row = await _client
          .from('profiles')
          .select(_profileColumns)
          .eq('id', authUser.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));

      if (row != null) {
        return AppUser.fromProfile(row, authUser: authUser);
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }

    // The trigger has not landed. Fall back to the auth record so the app is
    // usable; the onboarding write will create the row.
    return AppUser.fromProfile(const {}, authUser: authUser);
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _guard(() => _auth.signInWithPassword(
          email: email.trim(),
          password: password,
        ));
  }

  Future<SignUpOutcome> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _guard(() => _auth.signUp(
          email: email.trim(),
          password: password,
          data: {'name': name.trim()},
        ));

    return response.session == null
        ? SignUpOutcome.confirmationRequired
        : SignUpOutcome.signedIn;
  }

  /// Native Google sign-in: the platform sheet returns id/access tokens which
  /// are exchanged for a Supabase session. This keeps the whole flow in-app
  /// (no browser round trip) and works the same on iOS and Android.
  Future<void> signInWithGoogle() async {
    final tokens = await _guard(_oauth.googleTokens);
    if (tokens == null) {
      throw const AuthFailure('Google sign-in was cancelled.');
    }

    await _guard(() => _auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: tokens.idToken,
          accessToken: tokens.accessToken,
        ));
  }

  Future<void> signInWithApple() async {
    final tokens = await _guard(_oauth.appleTokens);
    if (tokens == null) {
      throw const AuthFailure('Apple sign-in was cancelled.');
    }

    await _guard(() => _auth.signInWithIdToken(
          provider: OAuthProvider.apple,
          idToken: tokens.idToken,
          nonce: tokens.rawNonce,
        ));

    // Apple only sends the name on the very first authorisation, so it has to
    // be captured then or it is lost forever.
    final name = tokens.displayName;
    if (name != null && name.isNotEmpty) {
      await _guard(() => _auth.updateUser(UserAttributes(data: {'name': name})));
      await _client.from('profiles').update({'name': name}).eq(
            'id',
            _auth.currentUser!.id,
          );
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _guard(() => _auth.resetPasswordForEmail(email.trim()));
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } on AuthException {
      // A stale or already-revoked token still has to clear locally.
    }
    await _oauth.signOut();
  }

  /// Runs a Supabase call and rewrites its errors as [AuthFailure].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (error) {
      throw AuthFailure(_messageFor(error));
    } on PostgrestException catch (error) {
      throw AuthFailure(error.message);
    } on AuthFailure {
      rethrow;
    } on TimeoutException {
      throw const AuthFailure('The server took too long to respond.');
    }
  }

  static String _messageFor(AuthException error) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'That email and password do not match an account.';
      case 'email_not_confirmed':
        return 'Confirm your email address first — check your inbox.';
      case 'user_already_exists':
      case 'email_exists':
        return 'An account already uses that email. Sign in instead.';
      case 'weak_password':
        return 'Pick a stronger password (at least 8 characters).';
      case 'email_address_invalid':
        return 'That email address is not accepted. Use a real address.';
      case 'over_email_send_rate_limit':
        return 'Too many attempts. Wait a minute and try again.';
      case 'validation_failed':
        return 'Check the details you entered and try again.';
      default:
        return error.message;
    }
  }
}
