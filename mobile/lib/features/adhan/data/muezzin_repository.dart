import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/muezzin.dart';

/// The muezzin list from the backend (`GET /muezzins`), cached on the
/// device so the picker works offline after the first load.
class MuezzinRepository {
  MuezzinRepository([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// The last list fetched, or empty before the first load.
  Future<List<Muezzin>> cached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.adhanMuezzins);
    if (raw == null) return const [];
    try {
      return parse({'muezzins': jsonDecode(raw)});
    } catch (_) {
      return const [];
    }
  }

  /// Fetches the active muezzins (already in `sortOrder`) and caches them.
  Future<List<Muezzin>> refresh() async {
    final List<Muezzin> list;
    try {
      final res = await _client.dio.get<Object?>('/muezzins');
      list = parse(res.data);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.adhanMuezzins,
        jsonEncode([for (final m in list) m.toJson()]));
    return list;
  }

  static List<Muezzin> parse(Object? body) {
    final list = body is Map ? body['muezzins'] : null;
    if (list is! List) throw const FormatException('Unexpected muezzins');
    return [
      for (final m in list)
        Muezzin.fromJson(Map<String, dynamic>.from(m as Map)),
    ];
  }
}
