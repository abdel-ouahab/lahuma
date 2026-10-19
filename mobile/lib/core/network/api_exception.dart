import 'package:dio/dio.dart';

/// User-friendly error shown by the UI. Never expose raw exceptions.
///
/// [message] is either a server-provided sentence (already safe to show) or
/// one of the codes [offline] / [generic], which the UI maps to localized text.
class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  static const String offline = 'offline';
  static const String generic = 'somethingWentWrong';

  bool get isCode => message == offline || message == generic;

  factory ApiException.fromDioError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is String) {
        return ApiException(data['error'] as String);
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return const ApiException(offline);
      }
    }
    return const ApiException(generic);
  }
}
