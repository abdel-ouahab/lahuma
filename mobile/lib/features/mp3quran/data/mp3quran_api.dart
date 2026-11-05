import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/mp3quran_models.dart';

/// The last `/reciters` and `/suwar` answers, kept on the device so the
/// reciters list and downloaded surahs work without a connection.
class Mp3QuranCache {
  Mp3QuranCache({Future<Directory> Function()? dir})
      : _dir = dir ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _dir;

  Future<File> _file(String key) async =>
      File('${(await _dir()).path}/mp3quran_$key.json');

  Future<Object?> read(String key) async {
    try {
      final f = await _file(key);
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString());
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, Object? data) async {
    try {
      final f = await _file(key);
      await f.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // Best effort: the next successful request writes it again.
    }
  }
}

/// Client for the public MP3Quran API (https://mp3quran.net/api/v3/).
/// With a [cache], a failed request answers with the last good one.
class Mp3QuranApi {
  Mp3QuranApi([ApiClient? client, this.cache])
      : _dio = (client ?? ApiClient(baseUrl: baseUrl)).dio;

  static const String baseUrl = 'https://mp3quran.net/api/v3/';

  final Dio _dio;
  final Mp3QuranCache? cache;

  Future<List<Mp3Reciter>> fetchReciters({String language = 'ar'}) async {
    final data = await _get('reciters', language);
    return parseReciters(data);
  }

  Future<List<Mp3Surah>> fetchSuwar({String language = 'ar'}) async {
    final data = await _get('suwar', language);
    return parseSuwar(data);
  }

  Future<Object?> _get(String path, String language) async {
    final key = '${path}_$language';
    try {
      final res = await _dio
          .get<Object?>(path, queryParameters: {'language': language});
      _listUnder(res.data, path); // only cache a usable answer
      await cache?.write(key, res.data);
      return res.data;
    } catch (e) {
      final saved = await cache?.read(key);
      if (saved != null) return saved;
      if (e is ApiException) rethrow;
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
