import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../models/app_user.dart';

enum AuthStatus {
  authenticated,
  unauthenticated,
}

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.unauthenticated;
  AppUser? _user;
  bool _isBusy = false;
  String? _errorMessage;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> bootstrap() async {
    _setBusy(true);

    try {
      final session = await _repository.restoreSession();
      if (session == null) {
        _status = AuthStatus.unauthenticated;
        _user = null;
        return;
      }

      _status = AuthStatus.authenticated;
      _user = session.user;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setBusy(true);
    _errorMessage = null;

    try {
      final session = await _repository.login(
        email: email,
        password: password,
      );
      _status = AuthStatus.authenticated;
      _user = session.user;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    _setBusy(true);
    _errorMessage = null;

    try {
      final session = await _repository.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      _status = AuthStatus.authenticated;
      _user = session.user;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> logout() async {
    _setBusy(true);

    try {
      await _repository.logout();
      _status = AuthStatus.unauthenticated;
      _user = null;
      _errorMessage = null;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> refreshUser() async {
    if (!isAuthenticated) {
      return;
    }

    _setBusy(true);

    try {
      final restored = await _repository.restoreSession();
      if (restored == null) {
        _status = AuthStatus.unauthenticated;
        _user = null;
        return;
      }

      _user = restored.user;
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
}
