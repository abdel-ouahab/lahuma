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

  Uri get _base => Uri.parse(_client.dio.options.baseUrl);

  /// The last list fetched, or empty before the first load.
  Future<List<Muezzin>> cached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.adhanMuezzins);
    if (raw == null) return const [];
    try {
      return parse({'muezzins': jsonDecode(raw)}, base: _base);
    } catch (_) {
      return const [];
    }
  }

  /// Fetches the active muezzins (already in `sortOrder`) and caches them.
  Future<List<Muezzin>> refresh() async {
    final List<Muezzin> list;
    try {
      final res = await _client.dio.get<Object?>('/muezzins');
      list = parse(res.data, base: _base);
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

  static const _urlKeys = [
    'regularUrl',
    'fajrUrl',
    'regularShortUrl',
    'fajrShortUrl',
  ];

  /// A relative file URL ("/adhan/…") is resolved against [base], the API's
  /// origin: a backend may return one, and neither Dio nor just_audio can
  /// fetch it as is.
  static List<Muezzin> parse(Object? body, {Uri? base}) {
    final list = body is Map ? body['muezzins'] : null;
    if (list is! List) throw const FormatException('Unexpected muezzins');
    return [
      for (final m in list)
        Muezzin.fromJson({
          ...Map<String, dynamic>.from(m as Map),
          if (base != null)
            for (final k in _urlKeys)
              if (m[k] is String && (m[k] as String).startsWith('/'))
                k: base.resolve(m[k] as String).toString(),
        }),
    ];
  }
}
