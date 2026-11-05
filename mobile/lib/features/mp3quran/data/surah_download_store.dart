import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/mp3quran_models.dart';

/// Surahs saved on the device so they play without a connection.
///
/// Layout: `<app support>/recitations/<edition>/<NNN>.mp3`, where `<edition>`
/// is the Moshaf's server URL made into a folder name: the server is what
/// the audio really is (Moshaf ids are only unique per API response).
class SurahDownloadStore {
  SurahDownloadStore({
    Dio? dio,
    Future<Directory> Function()? supportDir,
  })  : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
            )),
        _supportDir = supportDir ?? getApplicationSupportDirectory;

  final Dio _dio;
  final Future<Directory> Function() _supportDir;
  Directory? _root;

  /// The folder name for [moshaf]'s files.
  static String editionKey(Mp3Moshaf moshaf) {
    final uri = Uri.tryParse(moshaf.server);
    final raw = uri == null ? moshaf.server : '${uri.host}${uri.path}';
    return raw
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static String _fileName(int surah) =>
      '${surah.toString().padLeft(3, '0')}.mp3';

  Future<Directory> root() async =>
      _root ??= Directory('${(await _supportDir()).path}/recitations');

  /// The saved file for [surah], or null.
  Future<String?> fileFor(Mp3Moshaf moshaf, int surah) async {
    final f = File(
        '${(await root()).path}/${editionKey(moshaf)}/${_fileName(surah)}');
    return await f.exists() ? f.path : null;
  }

  /// Every saved surah, by [editionKey].
  Future<Map<String, Set<int>>> scan() async {
    final r = await root();
    final out = <String, Set<int>>{};
    if (!await r.exists()) return out;
    for (final dir in r.listSync().whereType<Directory>()) {
      final surahs = <int>{
        for (final f in dir.listSync().whereType<File>())
          if (RegExp(r'^\d{3}\.mp3$').hasMatch(f.uri.pathSegments.last))
            int.parse(f.uri.pathSegments.last.substring(0, 3)),
      };
      // A directory's uri ends with "/", so its name is the segment before.
      final name = dir.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      if (surahs.isNotEmpty) out[name] = surahs;
    }
    return out;
  }

  /// Downloads [surah] of [moshaf], reporting 0…1 through [onProgress]. A
  /// failed or cancelled download leaves nothing behind.
  Future<String> download(
    Mp3Moshaf moshaf,
    int surah, {
    void Function(double progress)? onProgress,
    CancelToken? cancel,
  }) async {
    final url = moshaf.audioUrlFor(surah);
    if (url == null) throw StateError('No surah $surah in this recitation');
    final dir = Directory('${(await root()).path}/${editionKey(moshaf)}');
    await dir.create(recursive: true);
    final path = '${dir.path}/${_fileName(surah)}';
    final part = '$path.part';
    try {
      await _dio.download(url, part, cancelToken: cancel,
          onReceiveProgress: (got, total) {
        if (total > 0) onProgress?.call(got / total);
      });
      if (!await _looksLikeMp3(File(part))) {
        throw const FormatException('Not an audio file');
      }
      await File(part).rename(path);
      return path;
    } catch (_) {
      try {
        await File(part).delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> delete(Mp3Moshaf moshaf, int surah) async {
    final f = File('${(await root()).path}/${editionKey(moshaf)}/'
        '${_fileName(surah)}');
    if (await f.exists()) await f.delete();
  }

  Future<void> deleteAll(Mp3Moshaf moshaf) async {
    final dir = Directory('${(await root()).path}/${editionKey(moshaf)}');
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Bytes used by [moshaf]'s saved surahs.
  Future<int> sizeOf(Mp3Moshaf moshaf) async {
    final dir = Directory('${(await root()).path}/${editionKey(moshaf)}');
    if (!await dir.exists()) return 0;
    var total = 0;
    for (final f in dir.listSync().whereType<File>()) {
      if (f.path.endsWith('.mp3')) total += f.lengthSync();
    }
    return total;
  }

  /// An ID3 tag or an MPEG frame sync: a server error page is not saved.
  static Future<bool> _looksLikeMp3(File file) async {
    final raf = await file.open();
    try {
      final b = await raf.read(3);
      if (b.length < 3) return false;
      if (String.fromCharCodes(b) == 'ID3') return true;
      return b[0] == 0xFF && b[1] & 0xE0 == 0xE0;
    } finally {
      await raf.close();
    }
  }
}
