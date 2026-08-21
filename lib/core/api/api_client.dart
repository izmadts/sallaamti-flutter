import 'dart:io';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_store.dart';
import 'api_exception.dart';

// Thin Dio wrapper: every request automatically carries the stored bearer
// token (if any) and Accept: application/json, and every failure is
// normalized into an ApiException before it reaches a repository or
// screen — nothing above this layer should ever touch a raw DioException.
class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await SecureStore.readToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // Backend's SetApiLocale middleware reads this to pick which
        // language __('db.*') error/status messages come back in — without
        // it every API message is English regardless of the app's own
        // language switch.
        final locale = await SecureStore.readLocale();
        if (locale != null) {
          options.headers['X-Locale'] = locale;
        }
        handler.next(options);
      },
    ));
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _request(() => _dio.get(path, queryParameters: query));

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data}) =>
      _request(() => _dio.post(path, data: data));

  // Laravel reads booleans from multipart bodies via $request->boolean(),
  // which only recognizes string forms ('1'/'true'/'on'/'yes') — a Dart
  // `bool` serialized as FormData would arrive as the literal text "true",
  // which boolean() also accepts, but converting explicitly here avoids
  // relying on that overlap for values like `0`/`false`.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, dynamic> fields = const {},
    Map<String, File> files = const {},
  }) async {
    final map = <String, dynamic>{};
    fields.forEach((key, value) {
      if (value == null) return;
      if (value is bool) {
        map[key] = value ? '1' : '0';
      } else if (value is List) {
        for (final item in value) {
          map.putIfAbsent('$key[]', () => <String>[]);
          (map['$key[]'] as List).add(item.toString());
        }
      } else {
        map[key] = value.toString();
      }
    });

    for (final entry in files.entries) {
      map[entry.key] = await MultipartFile.fromFile(entry.value.path, filename: entry.value.path.split(Platform.pathSeparator).last);
    }

    return _request(() => _dio.post(path, data: FormData.fromMap(map)));
  }

  Future<Map<String, dynamic>> _request(Future<Response> Function() call) async {
    try {
      final response = await call();
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ApiException.network();
      }
      throw ApiException.fromResponseData(e.response?.data, e.response?.statusCode);
    }
  }
}
