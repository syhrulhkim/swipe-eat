import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swipe_eat/features/auth/data/auth_repository.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';

/// Stands in for the Supabase-backed repository so controller and router
/// behaviour can be exercised without a network or a `Supabase.initialize`.
///
/// [sessionPresent] and [profile] are set independently on purpose: the gap
/// between "there is a session" and "the profile has loaded" is exactly the
/// window the router has to hold on the splash screen.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.sessionPresent = false,
    this.profile,
    this.supportsGoogleSignIn = false,
    this.supportsAppleSignIn = false,
  });

  bool sessionPresent;
  AppUser? profile;

  @override
  bool supportsGoogleSignIn;

  @override
  bool supportsAppleSignIn;

  /// Held open so a test can delay the profile read and observe the
  /// intermediate state.
  Completer<void>? profileGate;

  AuthFailure? nextFailure;
  SignUpOutcome signUpOutcome = SignUpOutcome.confirmationRequired;

  final List<String> calls = [];
  final _events = StreamController<AuthState>.broadcast();

  void emit(AuthChangeEvent event) {
    _events.add(AuthState(event, null));
  }

  Future<void> dispose() => _events.close();

  @override
  Session? get currentSession => sessionPresent
      ? Session(
          accessToken: 'fake-access-token',
          tokenType: 'bearer',
          user: const User(
            id: '39c39a30-c8fb-4e08-8e13-c90212f68e59',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-08-23T00:00:00Z',
          ),
        )
      : null;

  @override
  Stream<AuthState> get onAuthStateChange => _events.stream;

  @override
  Future<AppUser?> loadCurrentUser() async {
    calls.add('loadCurrentUser');
    final gate = profileGate;
    if (gate != null) {
      await gate.future;
    }
    return sessionPresent ? profile : null;
  }

  @override
  Future<void> login({required String email, required String password}) async {
    calls.add('login:$email');
    _maybeFail();
    sessionPresent = true;
  }

  @override
  Future<SignUpOutcome> register({
    required String name,
    required String email,
    required String password,
  }) async {
    calls.add('register:$email');
    _maybeFail();
    if (signUpOutcome == SignUpOutcome.signedIn) {
      sessionPresent = true;
    }
    return signUpOutcome;
  }

  @override
  Future<void> signInWithGoogle() async {
    calls.add('google');
    _maybeFail();
    sessionPresent = true;
  }

  @override
  Future<void> signInWithApple() async {
    calls.add('apple');
    _maybeFail();
    sessionPresent = true;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    calls.add('reset:$email');
    _maybeFail();
  }

  @override
  Future<void> logout() async {
    calls.add('logout');
    sessionPresent = false;
    profile = null;
  }

  @override
  Future<void> deleteAccount() async {
    calls.add('deleteAccount');
    _maybeFail();
    sessionPresent = false;
    profile = null;
  }

  void _maybeFail() {
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
  }
}
