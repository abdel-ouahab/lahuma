import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../data/auth_api.dart';

class AuthUser {
  const AuthUser({required this.id, required this.email, required this.name});

  final String id;
  final String email;
  final String name;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'name': name};
}

final apiClientProvider = Provider((ref) => ApiClient());

final authApiProvider =
    Provider((ref) => AuthApi(ref.watch(apiClientProvider)));

/// The signed-in account, or null for guests. Signing in is optional: the
/// whole app works without it.
///
/// A saved session is shown straight away (the app works offline), then
/// checked with the server: a token it rejects signs out quietly, and so does
/// any later request that comes back 401 (see [ApiClient.onUnauthorized]).
class AuthNotifier extends StateNotifier<AuthUser?> {
  AuthNotifier(this._api, this._client) : super(null) {
    _client.onUnauthorized = logout;
    restored = _restore();
  }

  final AuthApi _api;
  final ApiClient _client;
  String? _token;

  /// Completes once the saved session is loaded and checked with the server.
  @visibleForTesting
  late final Future<void> restored;

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(StorageKeys.authToken);
    final raw = prefs.getString(StorageKeys.authUser);
    if (token == null || raw == null) return;
    _token = token;
    _client.setAuthToken(token);
    state = AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    await _verify(token);
  }

  /// Confirms [token] with the server and refreshes the saved user. A 401 is
  /// handled by the client's interceptor; a 404 means the account is gone.
  /// Offline or server errors keep the saved session.
  Future<void> _verify(String token) async {
    try {
      final result = await _api.me();
      if (!mounted || _token != token) return;
      final user = AuthUser.fromJson(result['user'] as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.authUser, jsonEncode(user.toJson()));
      state = user;
    } on ApiException catch (e) {
      if (e.statusCode == 404 && mounted && _token == token) await logout();
    } catch (_) {
      // Unexpected payload: keep the saved session.
    }
  }

  Future<void> login({required String email, required String password}) async {
    final result = await _api.login(email: email, password: password);
    await _store(result);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final result =
        await _api.register(email: email, password: password, name: name);
    await _store(result);
  }

  Future<void> logout() async {
    _token = null;
    _client.setAuthToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.authToken);
    await prefs.remove(StorageKeys.authUser);
    if (mounted) state = null;
  }

  Future<void> _store(Map<String, dynamic> result) async {
    final user = AuthUser.fromJson(result['user'] as Map<String, dynamic>);
    final token = result['token'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.authToken, token);
    await prefs.setString(StorageKeys.authUser, jsonEncode(user.toJson()));
    _token = token;
    _client.setAuthToken(token);
    state = user;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthUser?>((ref) {
  return AuthNotifier(
    ref.watch(authApiProvider),
    ref.watch(apiClientProvider),
  );
});
