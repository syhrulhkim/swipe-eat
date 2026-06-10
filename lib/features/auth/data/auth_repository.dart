import '../../../core/storage/token_storage.dart';
import '../models/app_user.dart';
import '../models/auth_session.dart';
import 'auth_api.dart';

class AuthRepository {
  static const String demoEmail = 'demo@swipeeat.test';
  static const String demoPassword = 'password';
  static const String demoToken = 'demo-token';

  AuthRepository({
    required AuthApi authApi,
    required TokenStorage tokenStorage,
  })  : _authApi = authApi,
        _tokenStorage = tokenStorage;

  final AuthApi _authApi;
  final TokenStorage _tokenStorage;

  Future<AuthSession?> restoreSession() async {
    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    if (token == demoToken) {
      return AuthSession(token: token, user: _demoUser());
    }

    try {
      final user = await _authApi.me(token);
      return AuthSession(token: token, user: user);
    } catch (_) {
      await _tokenStorage.clearToken();
      return null;
    }
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (email.trim().toLowerCase() == demoEmail &&
        password == demoPassword) {
      final session = AuthSession(token: demoToken, user: _demoUser());
      await _tokenStorage.saveToken(session.token);
      return session;
    }

    final payload = await _authApi.login(
      email: email,
      password: password,
    );

    final user = payload.user ?? await _authApi.me(payload.token);
    final session = AuthSession(token: payload.token, user: user);
    await _tokenStorage.saveToken(session.token);
    return session;
  }

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final payload = await _authApi.register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );

    final user = payload.user ?? await _authApi.me(payload.token);
    final session = AuthSession(token: payload.token, user: user);
    await _tokenStorage.saveToken(session.token);
    return session;
  }

  Future<void> logout() async {
    final token = await _tokenStorage.readToken();
    if (token != null && token.isNotEmpty) {
      try {
        await _authApi.logout(token);
      } catch (_) {
        // Local logout should always win.
      }
    }

    await _tokenStorage.clearToken();
  }

  AppUser _demoUser() {
    return const AppUser(
      id: 1,
      name: 'Demo User',
      email: demoEmail,
      role: 'customer',
    );
  }
}
