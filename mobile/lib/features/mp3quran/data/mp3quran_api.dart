import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/mp3quran_models.dart';

/// Client for the public MP3Quran API (https://mp3quran.net/api/v3/).
class Mp3QuranApi {
  Mp3QuranApi([ApiClient? client])
      : _dio = (client ?? ApiClient(baseUrl: baseUrl)).dio;

  static const String baseUrl = 'https://mp3quran.net/api/v3/';

  final Dio _dio;

  Future<List<Mp3Reciter>> fetchReciters({String language = 'ar'}) async {
    final data = await _get('reciters', language);
    return parseReciters(data);
  }

  Future<List<Mp3Surah>> fetchSuwar({String language = 'ar'}) async {
    final data = await _get('suwar', language);
    return parseSuwar(data);
  }

  Future<Object?> _get(String path, String language) async {
    try {
      final res = await _dio
          .get<Object?>(path, queryParameters: {'language': language});
      return res.data;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Parses the `/reciters` payload. Reciters with no playable Moshaf are
  /// dropped; entries that fail to parse are skipped rather than failing the
  /// whole list.
  static List<Mp3Reciter> parseReciters(Object? data) {
    final list = _listUnder(data, 'reciters');
    final out = <Mp3Reciter>[];
    for (final item in list) {
      try {
        final r = Mp3Reciter.fromJson(item);
        final playable = r.moshaf
            .where((m) => m.server.isNotEmpty && m.surahNumbers.isNotEmpty);
        if (r.name.isNotEmpty && playable.isNotEmpty) {
          out.add(
              Mp3Reciter(id: r.id, name: r.name, moshaf: playable.toList()));
        }
      } catch (_) {}
    }
    return out;
  }

  static List<Mp3Surah> parseSuwar(Object? data) {
    final out = <Mp3Surah>[];
    for (final item in _listUnder(data, 'suwar')) {
      try {
        out.add(Mp3Surah.fromJson(item));
      } catch (_) {}
    }
    return out;
  }

  static List<Map<String, dynamic>> _listUnder(Object? data, String key) {
    if (data is Map && data[key] is List) {
      return (data[key] as List).whereType<Map<String, dynamic>>().toList();
    }
    throw const ApiException(ApiException.generic);
  }
}
