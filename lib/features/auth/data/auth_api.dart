import '../../../core/network/api_client.dart';
import '../models/app_user.dart';

class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<AuthPayload> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      '/login',
      data: <String, dynamic>{
        'email': email,
        'password': password,
      },
    );

    return AuthPayload.fromJson(_asMap(response.data));
  }

  Future<AuthPayload> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _client.post(
      '/register',
      data: <String, dynamic>{
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );

    return AuthPayload.fromJson(_asMap(response.data));
  }

  Future<AppUser> me(String token) async {
    final response = await _client.get(
      '/user',
      token: token,
    );

    return AppUser.fromJson(_extractUserMap(_asMap(response.data)));
  }

  Future<void> logout(String token) async {
    await _client.post(
      '/logout',
      token: token,
    );
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }

    throw const FormatException('Unexpected API response format.');
  }

  Map<String, dynamic> _extractUserMap(Map<String, dynamic> json) {
    final user = json['user'];
    if (user is Map) {
      return user.map((key, value) => MapEntry(key.toString(), value));
    }

    final data = json['data'];
    if (data is Map) {
      final nestedUser = data['user'];
      if (nestedUser is Map) {
        return nestedUser.map((key, value) => MapEntry(key.toString(), value));
      }
      return data.map((key, value) => MapEntry(key.toString(), value));
    }

    return json;
  }
}

class AuthPayload {
  const AuthPayload({
    required this.token,
    this.user,
  });

  final String token;
  final AppUser? user;

  factory AuthPayload.fromJson(Map<String, dynamic> json) {
    final token = _extractToken(json);
    if (token == null || token.isEmpty) {
      throw const FormatException('Auth response did not include a token.');
    }

    final userMap = _extractUserMap(json);
    return AuthPayload(
      token: token,
      user: userMap == null ? null : AppUser.fromJson(userMap),
    );
  }

  static String? _extractToken(Map<String, dynamic> json) {
    final candidates = <Object?>[
      json['token'],
      json['access_token'],
      json['accessToken'],
    ];

    final data = json['data'];
    if (data is Map) {
      candidates.addAll(<Object?>[
        data['token'],
        data['access_token'],
        data['accessToken'],
      ]);
    }

    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }

    return null;
  }

  static Map<String, dynamic>? _extractUserMap(Map<String, dynamic> json) {
    final user = json['user'];
    if (user is Map) {
      return user.map((key, value) => MapEntry(key.toString(), value));
    }

    final data = json['data'];
    if (data is Map) {
      final nestedUser = data['user'];
      if (nestedUser is Map) {
        return nestedUser.map((key, value) => MapEntry(key.toString(), value));
      }

      final maybeUser = data.map((key, value) => MapEntry(key.toString(), value));
      if (maybeUser.containsKey('email') || maybeUser.containsKey('name')) {
        return maybeUser;
      }
    }

    return null;
  }
}
