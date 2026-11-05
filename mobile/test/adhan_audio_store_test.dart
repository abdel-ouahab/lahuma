import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/adhan/data/adhan_audio_store.dart';
import 'package:lahuma/features/adhan/domain/muezzin.dart';

/// Serves [files] by URL path; anything else is a 404.
class FakeServer implements HttpClientAdapter {
  FakeServer(this.files);
  final Map<String, List<int>> files;
  final requested = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    requested.add(path);
    final body = files[path];
    if (body == null) {
      return ResponseBody.fromString('<html>Not found</html>', 404,
          headers: {
            Headers.contentTypeHeader: ['text/html'],
          });
    }
    return ResponseBody.fromBytes(body, 200, headers: {
      Headers.contentLengthHeader: ['${body.length}'],
    });
  }

  @override
  void close({bool force = false}) {}
}

final mp3 = [...'ID3'.codeUnits, 4, 0, 0, 0, 0, 0, 0, ...List.filled(500, 1)];
final caf = [...'caff'.codeUnits, 0, 1, 0, 0, ...List.filled(300, 2)];

Muezzin algeria({int version = 2}) => Muezzin(
      id: '00000000-0000-4000-8000-000000000003',
      nameAr: 'أذان الجزائر',
      nameFr: "Adhan d'Algérie",
      country: 'DZ',
      regularUrl: 'http://10.0.2.2:4000/adhan/algeria/v$version/regular.mp3',
      fajrUrl: 'http://10.0.2.2:4000/adhan/algeria/v$version/fajr.mp3',
      regularShortUrl:
          'http://10.0.2.2:4000/adhan/algeria/v$version/regular_short.caf',
      fajrShortUrl:
          'http://10.0.2.2:4000/adhan/algeria/v$version/fajr_short.caf',
      version: version,
    );

Map<String, List<int>> filesOf(int version) => {
      '/adhan/algeria/v$version/regular.mp3': mp3,
      '/adhan/algeria/v$version/fajr.mp3': mp3,
      '/adhan/algeria/v$version/regular_short.caf': caf,
      '/adhan/algeria/v$version/fajr_short.caf': caf,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Directory support;
  late Directory library;

  setUp(() {
    root = Directory.systemTemp.createTempSync('adhan_store_');
    support = Directory('${root.path}/support')..createSync();
    library = Directory('${root.path}/library')..createSync();
  });
  tearDown(() => root.deleteSync(recursive: true));

  AdhanAudioStore store(FakeServer server, {required bool ios}) =>
      AdhanAudioStore(
        dio: Dio()..httpClientAdapter = server,
        supportDir: () async => support,
        libraryDir: () async => library,
        ios: ios,
      );

  test('Android downloads the two full files into adhan/<id>/v<version>',
      () async {
    final server = FakeServer(filesOf(2));
    final progress = <double>[];
    final d = await store(server, ios: false)
        .download(algeria(), onProgress: progress.add);

    expect(server.requested, [
      '/adhan/algeria/v2/regular.mp3',
      '/adhan/algeria/v2/fajr.mp3',
    ]);
    final dir = '${support.path}/adhan/${algeria().id}/v2';
    expect(d.files, {
      AdhanSoundKind.regular: '$dir/regular.mp3',
      AdhanSoundKind.fajr: '$dir/fajr.mp3',
    });
    expect(File('$dir/fajr.mp3').readAsBytesSync(), mp3);
    expect(progress.last, 1);
  });

  test('iOS also downloads the clips and copies them into Library/Sounds',
      () async {
    final d =
        await store(FakeServer(filesOf(2)), ios: true).download(algeria());

    expect(d.files.keys, containsAll(AdhanSoundKind.values));
    expect(d.iosSounds.keys,
        {AdhanSoundKind.regularShort, AdhanSoundKind.fajrShort});
    for (final name in d.iosSounds.values) {
      expect(name, endsWith('_v2.caf'));
      expect(File('${library.path}/Sounds/$name').existsSync(), isTrue);
    }
  });

  test('a 404 fails the whole download and leaves nothing behind', () async {
    final files = filesOf(2)..remove('/adhan/algeria/v2/fajr.mp3');
    await expectLater(store(FakeServer(files), ios: false).download(algeria()),
        throwsA(isA<AdhanDownloadException>()));
    expect(Directory('${support.path}/adhan/${algeria().id}/v2').existsSync(),
        isFalse);
  });

  test('an HTML page served as the file (wrong MEDIA_BASE_URL) is refused',
      () async {
    final files = filesOf(2)
      ..['/adhan/algeria/v2/regular.mp3'] = '<!doctype html>'.codeUnits;
    await expectLater(store(FakeServer(files), ios: false).download(algeria()),
        throwsA(isA<AdhanDownloadException>()));
  });

  test('a new version replaces the old files', () async {
    final s = store(FakeServer({...filesOf(2), ...filesOf(3)}), ios: true);
    final v2 = await s.download(algeria(version: 2));
    final v3 = await s.download(algeria(version: 3));
    await s.deleteExcept(v3);

    expect(s.isComplete(v2), isFalse);
    expect(s.isComplete(v3), isTrue);
    final sounds = Directory('${library.path}/Sounds')
        .listSync()
        .map((f) => f.uri.pathSegments.last);
    expect(sounds, unorderedEquals(v3.iosSounds.values));
  });
}
