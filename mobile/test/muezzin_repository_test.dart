import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/adhan/data/muezzin_repository.dart';

void main() {
  final list = MuezzinRepository.catalogue;

  test('the catalogue keeps the ids a saved choice refers to', () {
    expect(list.map((m) => m.id).toSet(), hasLength(list.length));
    expect(list.first.id, '00000000-0000-4000-8000-000000000003'); // Algeria
    expect([for (final m in list) m.sortOrder], [0, 1, 2, 3, 4]);
  });

  test('full adhans come from the pinned source commit, percent-encoded', () {
    for (final m in list) {
      for (final url in [m.regularUrl, m.fajrUrl]) {
        final uri = Uri.parse(url);
        expect(uri.scheme, 'https');
        expect(uri.host, 'raw.githubusercontent.com');
        expect(url, contains('/b9180a2bb769f74cff8e378ef2cc7aaf8db5cd5b/'));
        expect(RegExp(r'^[\x21-\x7E]+$').hasMatch(url), isTrue,
            reason: 'the Arabic must be percent-encoded: $url');
        expect(uri.path, endsWith('.mp3'));
      }
    }
  });

  test('every short iOS clip is a bundled asset that exists', () {
    for (final m in list) {
      for (final url in [m.regularShortUrl, m.fajrShortUrl]) {
        expect(url, startsWith('asset:assets/audio/adhan/'));
        expect(File(url.substring('asset:'.length)).existsSync(), isTrue,
            reason: url);
      }
    }
  });

  test('cached and refresh need no network', () async {
    final repo = MuezzinRepository();
    expect(await repo.cached(), list);
    expect(await repo.refresh(), list);
  });
}
