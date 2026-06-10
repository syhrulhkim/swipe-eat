import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDioException(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;

    final message = _extractMessage(response?.data) ??
        switch (error.type) {
          DioExceptionType.connectionTimeout => 'Connection timed out.',
          DioExceptionType.sendTimeout => 'Request timed out.',
          DioExceptionType.receiveTimeout => 'Response timed out.',
          DioExceptionType.badResponse => 'The server returned an error.',
          DioExceptionType.cancel => 'The request was cancelled.',
          DioExceptionType.connectionError => 'No connection could be made.',
          _ => error.message ?? 'Something went wrong.',
        };

    return ApiException(message, statusCode: statusCode);
  }

  static String? _extractMessage(Object? data) {
    if (data is Map) {
      final normalized = data.map(
        (key, value) => MapEntry(key.toString(), value),
      );

      final direct = normalized['message'];
      if (direct is String && direct.trim().isNotEmpty) {
        return direct.trim();
      }

      final error = normalized['error'];
      if (error is String && error.trim().isNotEmpty) {
        return error.trim();
      }

      final errors = normalized['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) {
          return first.first.toString();
        }
        if (first != null) {
          return first.toString();
        }
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    return null;
  }

  @override
  String toString() => message;
}
