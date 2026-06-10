import 'package:dio/dio.dart';

import 'api_exception.dart';

class ApiClient {
  ApiClient({required String baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
            headers: const <String, dynamic>{
              'Accept': 'application/json',
            },
          ),
        );

  final Dio _dio;

  Dio get dio => _dio;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? token,
  }) {
    return _request(
      () => _dio.get(
        path,
        queryParameters: queryParameters,
        options: _options(token),
      ),
    );
  }

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    String? token,
  }) {
    return _request(
      () => _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _options(token),
      ),
    );
  }

  Future<Response<dynamic>> delete(
    String path, {
    Object? data,
    String? token,
  }) {
    return _request(
      () => _dio.delete(
        path,
        data: data,
        options: _options(token),
      ),
    );
  }

  Options _options(String? token) {
    final headers = <String, dynamic>{
      'Accept': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return Options(headers: headers);
  }

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }
}
