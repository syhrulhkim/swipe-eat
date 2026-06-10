class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.role,
  });

  final int? id;
  final String name;
  final String email;
  final String? role;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: _asInt(json['id']),
      name: _asString(json['name']) ?? 'User',
      email: _asString(json['email']) ?? '',
      role: _asString(json['role']),
    );
  }

  AppUser copyWith({
    int? id,
    String? name,
    String? email,
    String? role,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static String? _asString(Object? value) {
    if (value == null) {
      return null;
    }
    return value.toString();
  }
}
