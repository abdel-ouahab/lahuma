import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/network/api_client.dart';
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
class AuthNotifier extends StateNotifier<AuthUser?> {
  AuthNotifier(this._api, this._client) : super(null) {
    _restore();
  }

  final AuthApi _api;
  final ApiClient _client;

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(StorageKeys.authToken);
    final raw = prefs.getString(StorageKeys.authUser);
    if (token == null || raw == null) return;
    _client.setAuthToken(token);
    state = AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.authToken);
    await prefs.remove(StorageKeys.authUser);
    _client.setAuthToken(null);
    state = null;
  }

  Future<void> _store(Map<String, dynamic> result) async {
    final user = AuthUser.fromJson(result['user'] as Map<String, dynamic>);
    final token = result['token'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.authToken, token);
    await prefs.setString(StorageKeys.authUser, jsonEncode(user.toJson()));
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
