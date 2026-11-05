import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/core/network/api_client.dart';
import 'package:lahuma/features/mp3quran/data/mp3quran_api.dart';
import 'package:lahuma/features/mp3quran/data/surah_download_store.dart';
import 'package:lahuma/features/mp3quran/domain/mp3quran_models.dart';
import 'package:lahuma/features/mp3quran/presentation/mp3quran_providers.dart';

/// Serves [files] by URL path; anything else is a 404. With [gate], each
/// response waits for it, so a test can watch a download in flight.
class FakeServer implements HttpClientAdapter {
  FakeServer(this.files);
  final Map<String, List<int>> files;
  final requested = <String>[];
  bool offline = false;
  Completer<void>? gate;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requested.add(options.uri.path);
    if (offline) {
      throw DioException.connectionError(
          requestOptions: options, reason: 'offline');
    }
    await gate?.future;
    final body = files[options.uri.path];
    if (body == null) {
      return ResponseBody.fromString('<html>Not found</html>', 404);
    }
    return ResponseBody.fromBytes(body, 200, headers: {
      Headers.contentLengthHeader: ['${body.length}'],
      if (body.isNotEmpty && body.first == 0x7B) // "{"
        Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

final mp3 = [...'ID3'.codeUnits, 4, 0, 0, 0, 0, 0, 0, ...List.filled(400, 1)];

const moshaf = Mp3Moshaf(
  id: 1,
  name: 'حفص عن عاصم - مرتل',
  server: 'https://server8.mp3quran.net/ahmad_huth/',
  surahNumbers: [1, 2, 3],
);

Map<String, List<int>> allSurahs() => {
      for (final n in [1, 2, 3])
        '/ahmad_huth/${n.toString().padLeft(3, '0')}.mp3': mp3,
    };

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('recitations_'));
  tearDown(() => root.deleteSync(recursive: true));

  SurahDownloadStore store(FakeServer server) => SurahDownloadStore(
        dio: Dio()..httpClientAdapter = server,
        supportDir: () async => root,
      );

  group('SurahDownloadStore', () {
    test('saves a surah under its edition and finds it again', () async {
      final s = store(FakeServer(allSurahs()));
      final path = await s.download(moshaf, 2);

      expect(path, endsWith('/recitations/server8_mp3quran_net_ahmad_huth/002.mp3'));
      expect(File(path).readAsBytesSync(), mp3);
      expect(await s.fileFor(moshaf, 2), path);
      expect(await s.fileFor(moshaf, 1), isNull);
      expect(await s.scan(), {
        'server8_mp3quran_net_ahmad_huth': {2}
      });
    });

    test('a 404 or an HTML page leaves nothing behind', () async {
      final files = allSurahs()
        ..['/ahmad_huth/001.mp3'] = '<!doctype html>'.codeUnits
        ..remove('/ahmad_huth/002.mp3');
      final s = store(FakeServer(files));
      await expectLater(s.download(moshaf, 1), throwsA(anything));
      await expectLater(s.download(moshaf, 2), throwsA(anything));
      expect(await s.scan(), isEmpty);
      final dir = Directory('${root.path}/recitations/'
          'server8_mp3quran_net_ahmad_huth');
      expect(dir.listSync(), isEmpty);
    });

    test('remove one, then all', () async {
      final s = store(FakeServer(allSurahs()));
      await s.download(moshaf, 1);
      await s.download(moshaf, 3);
      await s.delete(moshaf, 1);
      expect((await s.scan()).values.single, {3});
      await s.deleteAll(moshaf);
      expect(await s.scan(), isEmpty);
    });
  });

  group('SurahDownloadsNotifier', () {
    /// The notifier's latest state, read through a listener.
    SurahDownloadsState Function() watch(SurahDownloadsNotifier n) {
      late SurahDownloadsState latest;
      n.addListener((v) => latest = v);
      return () => latest;
    }

    Future<void> settle(SurahDownloadsState Function() s) async {
      for (var i = 0; i < 50 && s().busyIn(moshaf); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    test('download all saves every surah, one after another', () async {
      final server = FakeServer(allSurahs());
      final n = SurahDownloadsNotifier(store(server));
      final s = watch(n);
      await n.ready;
      n.downloadAll(moshaf);
      expect(s().busyIn(moshaf), isTrue);
      await settle(s);

      expect(s().savedIn(moshaf), {1, 2, 3});
      expect(server.requested, [
        '/ahmad_huth/001.mp3',
        '/ahmad_huth/002.mp3',
        '/ahmad_huth/003.mp3',
      ]);
    });

    test('offline: the first failure stops the rest and can be retried',
        () async {
      final server = FakeServer(allSurahs())..offline = true;
      final n = SurahDownloadsNotifier(store(server));
      final s = watch(n);
      await n.ready;
      n.downloadAll(moshaf);
      await settle(s);

      expect(s().savedIn(moshaf), isEmpty);
      expect(s().hasFailed(moshaf, 1), isTrue);
      expect(server.requested, ['/ahmad_huth/001.mp3']);

      server.offline = false;
      n.download(moshaf, 1);
      await settle(s);
      expect(s().isSaved(moshaf, 1), isTrue);
      expect(s().hasFailed(moshaf, 1), isFalse);
    });

    test('stopping takes the queue away and keeps nothing half-done',
        () async {
      final server = FakeServer(allSurahs())..gate = Completer();
      final n = SurahDownloadsNotifier(store(server));
      final s = watch(n);
      await n.ready;
      n.downloadAll(moshaf);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(s().progressOf(moshaf, 1), isNotNull);
      expect(s().isQueued(moshaf, 2), isTrue);

      n.cancelAll(moshaf);
      server.gate!.complete();
      await settle(s);
      expect(s().savedIn(moshaf), isEmpty);
      expect(s().hasFailed(moshaf, 1), isFalse);
      expect(server.requested, ['/ahmad_huth/001.mp3']);
    });

    test('finds what was saved before', () async {
      await store(FakeServer(allSurahs())).download(moshaf, 3);
      final n = SurahDownloadsNotifier(store(FakeServer({})));
      final s = watch(n);
      await n.ready;
      expect(s().savedIn(moshaf), {3});
    });
  });

  test('the reciters list falls back to the last one fetched', () async {
    final server = FakeServer({});
    final client = ApiClient(baseUrl: Mp3QuranApi.baseUrl)
      ..dio.httpClientAdapter = server;
    final api = Mp3QuranApi(client, Mp3QuranCache(dir: () async => root));
    server.files['/api/v3/reciters'] = utf8.encode(
        '{"reciters":[{"id":5,"name":"أحمد","moshaf":[{"id":1,"name":"حفص",'
        '"server":"https://server8.mp3quran.net/ahmad_huth/",'
        '"surah_list":"1,2"}]}]}');

    expect((await api.fetchReciters()).single.name, 'أحمد');
    server.offline = true;
    expect((await api.fetchReciters()).single.moshaf.single.surahNumbers,
        [1, 2]);
  });
}
