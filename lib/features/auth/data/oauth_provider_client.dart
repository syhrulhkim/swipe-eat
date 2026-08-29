import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';

/// Tokens handed back by a native provider sheet, ready to be exchanged for a
/// Supabase session via `signInWithIdToken`.
class OAuthTokens {
  const OAuthTokens({
    required this.idToken,
    this.accessToken,
    this.rawNonce,
    this.displayName,
  });

  final String idToken;
  final String? accessToken;

  /// Apple hashes the nonce it signs into the id token; Supabase re-hashes the
  /// raw value to verify it, so the *raw* one is what gets sent.
  final String? rawNonce;

  /// Apple returns the user's name only on the first authorisation ever.
  final String? displayName;
}

/// Wraps the two native sign-in plugins so [AuthRepository] never touches
/// their APIs directly — that keeps the plugin-version churn in one file and
/// lets tests substitute a fake.
///
/// Every method returns null when the user cancels, and throws only on real
/// errors.
class OAuthProviderClient {
  const OAuthProviderClient();

  /// Apple's native sheet exists on Apple platforms only. Elsewhere the button
  /// is hidden rather than falling back to a web flow, which would need extra
  /// service-id configuration.
  bool get isAppleAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<OAuthTokens?> googleTokens() async {
    if (!AppConfig.hasGoogleSignIn) {
      throw StateError(
        'Google sign-in needs GOOGLE_IOS_CLIENT_ID / GOOGLE_WEB_CLIENT_ID.',
      );
    }

    final google = GoogleSignIn.instance;
    await google.initialize(
      clientId: AppConfig.googleIosClientId.isEmpty
          ? null
          : AppConfig.googleIosClientId,
      // The *web* client id is what Supabase validates the id token's
      // audience against, even for a native sign-in.
      serverClientId: AppConfig.googleWebClientId,
    );

    final GoogleSignInAccount account;
    try {
      account = await google.authenticate(scopeHint: const ['email', 'profile']);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google returned no id token.');
    }

    // The access token is a separate, explicitly authorised grant in v7. It is
    // optional for the Supabase exchange, so a refusal here is not fatal.
    const scopes = ['email', 'profile'];
    final authorization =
        await account.authorizationClient.authorizationForScopes(scopes);

    return OAuthTokens(
      idToken: idToken,
      accessToken: authorization?.accessToken,
      displayName: account.displayName,
    );
  }

  Future<OAuthTokens?> appleTokens() async {
    if (!await SignInWithApple.isAvailable()) {
      throw StateError('Sign in with Apple is not available on this device.');
    }

    final rawNonce = Supabase.instance.client.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      rethrow;
    }

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw StateError('Apple returned no identity token.');
    }

    final name = [credential.givenName, credential.familyName]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ')
        .trim();

    return OAuthTokens(
      idToken: idToken,
      rawNonce: rawNonce,
      displayName: name.isEmpty ? null : name,
    );
  }

  /// Clears the cached Google account so the next sign-in shows the picker
  /// instead of silently reusing the last one.
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Never block sign-out on a provider-side failure.
    }
  }
}
