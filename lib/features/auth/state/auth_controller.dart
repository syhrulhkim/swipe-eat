import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../models/app_user.dart';

enum AuthStatus {
  /// Nothing decided yet — the persisted session is still being restored, or
  /// the profile behind a fresh session has not loaded. The router must hold
  /// on a splash screen while this is the state, otherwise every cold start
  /// flashes the login (or the onboarding) page before settling.
  unknown,
  authenticated,
  unauthenticated,
}

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;
  StreamSubscription<AuthState>? _subscription;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  bool _isBusy = false;
  String? _errorMessage;

  /// Set after a sign-up that needs the emailed confirmation link. The login
  /// page shows it, because the account exists but cannot sign in yet.
  String? _notice;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  String? get notice => _notice;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// The router's gate: false means "do not redirect yet".
  bool get isResolved => _status != AuthStatus.unknown;

  /// Null `onboarded_at` on the profile means the wizard is still owed. Only
  /// meaningful once [isResolved] and [isAuthenticated].
  bool get needsOnboarding => _user?.needsOnboarding ?? false;

  bool get supportsGoogleSignIn => _repository.supportsGoogleSignIn;
  bool get supportsAppleSignIn => _repository.supportsAppleSignIn;

  /// Restores any persisted session and starts listening for auth changes.
  /// Subscribing before the first resolve means a token refresh or a sign-out
  /// triggered on another device propagates here without polling.
  Future<void> bootstrap() async {
    _subscription ??= _repository.onAuthStateChange.listen(_handleAuthState);
    await _resolve();
  }

  Future<bool> login({
    required String email,
    required String password,
  }) {
    return _run(() => _repository.login(email: email, password: password));
  }

  /// Returns true when the account was created. Email confirmation is on, so
  /// success usually means "check your inbox", not "signed in" — [notice]
  /// carries that message and the caller must not navigate to the dashboard.
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final ok = await _run(() async {
      final outcome = await _repository.register(
        name: name,
        email: email,
        password: password,
      );
      if (outcome == SignUpOutcome.confirmationRequired) {
        _notice = 'Account created. Open the confirmation link we emailed to '
            '${email.trim()}, then sign in.';
      }
    });
    return ok;
  }

  Future<bool> signInWithGoogle() => _run(_repository.signInWithGoogle);

  Future<bool> signInWithApple() => _run(_repository.signInWithApple);

  Future<bool> sendPasswordReset(String email) {
    return _run(() async {
      await _repository.sendPasswordReset(email);
      _notice = 'Password reset link sent to ${email.trim()}.';
    });
  }

  Future<void> logout() async {
    _setBusy(true);
    try {
      await _repository.logout();
      _status = AuthStatus.unauthenticated;
      _user = null;
      _errorMessage = null;
      _notice = null;
    } finally {
      _setBusy(false);
    }
  }

  /// Re-reads the profile row — call after onboarding or a preference write so
  /// `needsOnboarding` and the displayed name reflect the database.
  Future<void> refreshUser() async {
    if (!isAuthenticated) {
      return;
    }
    _user = await _repository.loadCurrentUser();
    notifyListeners();
  }

  /// Replaces the cached profile with one the caller already has.
  ///
  /// `complete_onboarding` and `update_preferences` both return the whole
  /// `profiles` row, so the writer can hand it straight back instead of making
  /// the controller re-read what it just wrote.
  void applyUser(AppUser user) {
    _user = user;
    if (_status != AuthStatus.authenticated) {
      _status = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  /// Lets a completed onboarding update the gate without a round trip.
  void markOnboarded(DateTime onboardedAt) {
    final current = _user;
    if (current == null) {
      return;
    }
    _user = current.copyWith(onboardedAt: onboardedAt);
    notifyListeners();
  }

  void clearNotice() {
    if (_notice == null) {
      return;
    }
    _notice = null;
    notifyListeners();
  }

  void _handleAuthState(AuthState state) {
    switch (state.event) {
      case AuthChangeEvent.signedOut:
        _status = AuthStatus.unauthenticated;
        _user = null;
        notifyListeners();
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.userUpdated:
        unawaited(_resolve());
      default:
        // tokenRefreshed / passwordRecovery / mfaChallengeVerified change no
        // state the router cares about.
        break;
    }
  }

  /// Single place that moves the controller out of [AuthStatus.unknown]: the
  /// status only becomes `authenticated` once the profile is in hand, so the
  /// router never sees a session without a resolved `needsOnboarding`.
  Future<void> _resolve() async {
    if (_repository.currentSession == null) {
      _status = AuthStatus.unauthenticated;
      _user = null;
      notifyListeners();
      return;
    }

    try {
      _user = await _repository.loadCurrentUser();
      _status = _user == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
    } on Object catch (error) {
      // Deliberately everything: the profile read can fail as a Postgrest
      // error, a socket error or a timeout, and a session that cannot load its
      // profile (offline, RLS change) still counts as signed in — the profile
      // retries on the next refresh.
      _errorMessage = error.toString();
      _status = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    _setBusy(true);
    _errorMessage = null;
    _notice = null;

    try {
      await action();
      return true;
    } on AuthFailure catch (error) {
      _errorMessage = error.message;
      return false;
    } on Object catch (error) {
      // Anything the repository did not translate into an [AuthFailure] still
      // has to reach the form; a swallowed error would leave the button spinning
      // with no explanation.
      _errorMessage = error.toString();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    if (_isBusy == value) {
      return;
    }
    _isBusy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
