import 'package:dio/dio.dart';

/// Thin wrapper around Dio. Feature-level Api classes (AuthApi, QuranApi)
/// depend on this, never on Dio directly, to keep swapping the HTTP
/// client possible without touching feature code.
class ApiClient {
  ApiClient({String? baseUrl})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ??
                const String.fromEnvironment(
                  'API_BASE_URL',
                  defaultValue: 'http://10.0.2.2:4000/api',
                ),
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        ) {
    dio.interceptors.add(InterceptorsWrapper(onError: (error, handler) {
      // Only a request that carried our token can mean the session is over;
      // a 401 from the login form is just a wrong password.
      final sentToken =
          error.requestOptions.headers.containsKey('Authorization');
      if (error.response?.statusCode == 401 && sentToken) {
        onUnauthorized?.call();
      }
      handler.next(error);
    }));
  }

  final Dio dio;

  /// Called when the server rejects the auth token (expired or revoked).
  void Function()? onUnauthorized;

  void setAuthToken(String? token) {
    if (token == null) {
      dio.options.headers.remove('Authorization');
    } else {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }
}
