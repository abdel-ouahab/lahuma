import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/reciter_photos.dart';

/// Reciter portraits from Quran.com's public audio API. Only a few reciters
/// have one; everyone else gets a monogram.
class ReciterPhotosApi {
  ReciterPhotosApi([ApiClient? client])
      : _dio = (client ?? ApiClient(baseUrl: baseUrl)).dio;

  static const String baseUrl = 'https://api.qurancdn.com/api/qdc/';
  static const String imageHost = 'https://static.qurancdn.com/';

  final Dio _dio;

  Future<ReciterPhotos> fetch() async {
    try {
      final res = await _dio.get<Object?>('audio/reciters', queryParameters: {
        'locale': 'ar',
        'fields': 'profile_picture',
      });
      return parse(res.data);
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Arabic name → absolute image URL, skipping reciters without a photo.
  static ReciterPhotos parse(Object? data) {
    final list = data is Map && data['reciters'] is List
        ? data['reciters'] as List
        : const [];
    final urls = <String, String>{};
    for (final item in list.whereType<Map>()) {
      final picture = item['profile_picture'];
      final translated = item['translated_name'];
      final name = translated is Map ? translated['name'] as String? : null;
      if (picture is! String || picture.isEmpty || name == null) continue;
      urls[name] = picture.startsWith('http')
          ? picture
          : '$imageHost${picture.replaceFirst(RegExp('^/'), '')}';
    }
    return ReciterPhotos(urls);
  }
}
