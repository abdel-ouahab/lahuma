import 'package:dio/dio.dart';

/// User-friendly error shown by the UI. Never expose raw exceptions.
///
/// [message] is either a server-provided sentence (already safe to show) or
/// one of the codes [offline] / [generic], which the UI maps to localized text.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;

  /// HTTP status of the failed response; null when no response came back.
  final int? statusCode;

  static const String offline = 'offline';
  static const String generic = 'somethingWentWrong';

  bool get isCode => message == offline || message == generic;

  factory ApiException.fromDioError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      if (data is Map && data['error'] is String) {
        return ApiException(data['error'] as String, statusCode: status);
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return const ApiException(offline);
      }
      if (status != null) return ApiException(generic, statusCode: status);
    }
    return const ApiException(generic);
  }
}
