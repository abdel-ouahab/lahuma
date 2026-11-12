import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/network/api_exception.dart';

/// Talks directly to the external Quran API (api.alquran.cloud).
/// Kept out of the repository so it can later be swapped for the
/// backend proxy or a bundled offline dataset.
///
/// Every successful response is cached in a Hive box, so anything the user
/// has opened once can be read again without a connection.
class QuranRemoteDataSource {
  QuranRemoteDataSource({Dio? dio, Box<String>? cache})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.alquran.cloud/v1',
              // A weak connection gives up in seconds and falls back to
              // the cached copy instead of leaving the reader spinning.
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            )),
        _cache = cache;

  final Dio _dio;
  final Box<String>? _cache;

  Box<String>? get _box {
    if (_cache != null) return _cache;
    return Hive.isBoxOpen(StorageKeys.quranCacheBox)
        ? Hive.box<String>(StorageKeys.quranCacheBox)
        : null;
  }

  /// GET [path] and return its `data` field; fall back to the cached copy
  /// when the network is unavailable.
  Future<dynamic> _getData(String path) async {
    try {
      final response = await _dio.get(path);
      final data = response.data['data'];
      await _box?.put(path, jsonEncode(data));
      return data;
    } catch (e) {
      final cached = _box?.get(path);
      if (cached != null) return jsonDecode(cached);
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchSurahList() async {
    final data = await _getData('/surah') as List;
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchSurah(int number) async {
    return await _getData('/surah/$number/quran-uthmani')
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchEdition(int number, String edition) async {
    return await _getData('/surah/$number/$edition') as Map<String, dynamic>;
  }
}
