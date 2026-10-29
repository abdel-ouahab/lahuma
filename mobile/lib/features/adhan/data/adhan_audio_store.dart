import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/muezzin.dart';
import 'adhan_sound_platform.dart';

/// Thrown when a muezzin's files could not be downloaded.
class AdhanDownloadException implements Exception {
  const AdhanDownloadException(this.cause);
  final Object cause;

  @override
  String toString() => 'AdhanDownloadException($cause)';
}

/// Downloads a muezzin's files and makes them playable as notification
/// sounds; removes the files of muezzins no longer selected.
///
/// Layout: `<app support>/adhan/<muezzinId>/v<version>/<kind>.<ext>`.
/// Android also publishes the full files as `content://` sounds; iOS copies
/// the short (≤ 30 s) files into `Library/Sounds`, the only place a
/// notification can play a downloaded sound from.
class AdhanAudioStore {
  AdhanAudioStore({
    Dio? dio,
    this.platform = const AdhanSoundPlatform(),
    Future<Directory> Function()? supportDir,
    Future<Directory> Function()? libraryDir,
    bool? ios,
  })  : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
            )),
        _supportDir = supportDir ?? getApplicationSupportDirectory,
        _libraryDir = libraryDir ?? getLibraryDirectory,
        ios = ios ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  final Dio _dio;
  final AdhanSoundPlatform platform;
  final Future<Directory> Function() _supportDir;
  final Future<Directory> Function() _libraryDir;
  final bool ios;

  /// Android plays the full adhan as the channel sound; iOS needs the full
  /// files for the in-app player and the short ones for the notification.
  List<AdhanSoundKind> kindsFor(Muezzin m) => [
        AdhanSoundKind.regular,
        AdhanSoundKind.fajr,
        if (ios && m.regularShortUrl.isNotEmpty) AdhanSoundKind.regularShort,
        if (ios && m.fajrShortUrl.isNotEmpty) AdhanSoundKind.fajrShort,
      ];

  /// Name a published sound gets: unique per muezzin, kind and version, so
  /// a new version is a new Android channel and a new iOS file.
  static String soundName(Muezzin m, AdhanSoundKind kind, String ext) =>
      _soundName(m.id, m.version, kind, ext);

  static String _soundName(
      String muezzinId, int version, AdhanSoundKind kind, String ext) {
    final id = muezzinId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final short = id.length > 12 ? id.substring(0, 12) : id;
    return 'adhan_${short}_${kind.name}_v$version$ext';
  }

  /// Downloads every file of [m], reporting 0…1 through [onProgress].
  /// All or nothing: on failure the partial files are removed and an
  /// [AdhanDownloadException] is thrown.
  Future<AdhanDownload> download(
    Muezzin m, {
    void Function(double progress)? onProgress,
  }) async {
    final dir =
        Directory('${(await _supportDir()).path}/adhan/${m.id}/v${m.version}');
    final kinds = kindsFor(m);
    final files = <AdhanSoundKind, String>{};
    try {
      await dir.create(recursive: true);
      for (var i = 0; i < kinds.length; i++) {
        final kind = kinds[i];
        final url = m.url(kind);
        final path = '${dir.path}/${kind.name}${_ext(url, kind)}';
        final part = '$path.part';
        await _dio.download(url, part, onReceiveProgress: (got, total) {
          if (total > 0) onProgress?.call((i + got / total) / kinds.length);
        });
        if (await File(part).length() == 0) {
          throw const FormatException('Empty audio file');
        }
        await File(part).rename(path);
        files[kind] = path;
        onProgress?.call((i + 1) / kinds.length);
      }
    } catch (e) {
      await _deleteDir(dir);
      throw AdhanDownloadException(e);
    }

    final androidUris = <AdhanSoundKind, String>{};
    final iosSounds = <AdhanSoundKind, String>{};
    if (ios) {
      final sounds = Directory('${(await _libraryDir()).path}/Sounds');
      await sounds.create(recursive: true);
      for (final e in files.entries) {
        if (!e.key.isShort) continue;
        final name = soundName(m, e.key, _ext(e.value, e.key));
        await File(e.value).copy('${sounds.path}/$name');
        iosSounds[e.key] = name;
      }
    } else {
      for (final e in files.entries) {
        final uri = await platform.exposeSound(
            e.value, soundName(m, e.key, _ext(e.value, e.key)));
        if (uri != null) androidUris[e.key] = uri;
      }
    }
    return AdhanDownload(
      muezzinId: m.id,
      version: m.version,
      files: files,
      androidUris: androidUris,
      iosSounds: iosSounds,
    );
  }

  /// Android: publishes [d]'s sounds again (a FileProvider grant before
  /// Android 10 does not survive a reboot). Returns the refreshed record.
  Future<AdhanDownload> republish(AdhanDownload d) async {
    if (ios) return d;
    final uris = <AdhanSoundKind, String>{...d.androidUris};
    for (final e in d.files.entries) {
      if (e.key.isShort || !File(e.value).existsSync()) continue;
      final uri = await platform.exposeSound(e.value,
          _soundName(d.muezzinId, d.version, e.key, _ext(e.value, e.key)));
      if (uri != null) uris[e.key] = uri;
    }
    return AdhanDownload(
      muezzinId: d.muezzinId,
      version: d.version,
      files: d.files,
      androidUris: uris,
      iosSounds: d.iosSounds,
    );
  }

  /// Whether every file [d] lists is still on disk.
  bool isComplete(AdhanDownload d) =>
      d.files.isNotEmpty && d.files.values.every((p) => File(p).existsSync());

  /// Deletes every downloaded file and published sound except [keep]'s.
  Future<void> deleteExcept(AdhanDownload? keep) async {
    try {
      final root = Directory('${(await _supportDir()).path}/adhan');
      if (await root.exists()) {
        for (final muezzin in root.listSync().whereType<Directory>()) {
          for (final version in muezzin.listSync().whereType<Directory>()) {
            final kept = keep != null &&
                muezzin.path.endsWith(keep.muezzinId) &&
                version.path.endsWith('v${keep.version}');
            if (!kept) await _deleteDir(version);
          }
          if (muezzin.listSync().isEmpty) await _deleteDir(muezzin);
        }
      }
      if (ios) {
        final sounds = Directory('${(await _libraryDir()).path}/Sounds');
        final names = keep?.iosSounds.values.toSet() ?? const <String>{};
        if (await sounds.exists()) {
          for (final f in sounds.listSync().whereType<File>()) {
            final name = f.uri.pathSegments.last;
            if (name.startsWith('adhan_') && !names.contains(name)) {
              await f.delete();
            }
          }
        }
      } else {
        await platform.removeSoundsExcept({
          if (keep != null)
            for (final e in keep.files.entries)
              if (keep.androidUris.containsKey(e.key))
                _soundName(
                    keep.muezzinId, keep.version, e.key, _ext(e.value, e.key)),
        });
      }
    } catch (e) {
      // Cleanup is best effort; leftovers are removed on the next change.
      debugPrint('Adhan: cleanup failed: $e');
    }
  }

  /// The URL's extension, or the platform default for that kind.
  static String _ext(String url, AdhanSoundKind kind) {
    final path = Uri.tryParse(url)?.path ?? url;
    final dot = path.lastIndexOf('.');
    final ext = dot < 0 ? '' : path.substring(dot).toLowerCase();
    const known = {'.mp3', '.m4a', '.ogg', '.wav', '.caf', '.aiff'};
    if (known.contains(ext)) return ext;
    return kind.isShort ? '.caf' : '.mp3';
  }

  static Future<void> _deleteDir(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
