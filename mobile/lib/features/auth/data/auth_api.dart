import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// Not required for Quran reading. Reserved for the future
/// account-sync flow (Phase 3).
class AuthApi {
  AuthApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await _client.dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'name': name,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
