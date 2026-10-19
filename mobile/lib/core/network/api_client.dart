import 'package:dio/dio.dart';

/// Thin wrapper around Dio. Feature-level Api classes (AuthApi, QuranApi)
/// depend on this, never on Dio directly, to keep swapping the HTTP
/// client possible without touching feature code.
class ApiClient {
  ApiClient({String? baseUrl})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.0.2.2:4000/api',
            ),
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

  final Dio dio;

  void setAuthToken(String? token) {
    if (token == null) {
      dio.options.headers.remove('Authorization');
    } else {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }
}
