import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/mp3quran/data/mp3quran_api.dart';
import 'package:lahuma/features/mp3quran/domain/mp3quran_models.dart';
import 'package:lahuma/features/mp3quran/presentation/mp3quran_providers.dart';

void main() {
  final payload = {
    'reciters': [
      {
        'id': 1,
        'name': 'أحمد العجمي',
        'moshaf': [
          {
            'id': 10,
            'name': 'حفص عن عاصم - مرتل',
            'server': 'https://cdn.example.com/a/r1', // no trailing slash
            'surah_list': '1,2,3,114',
          },
          {
            'id': 11,
            'name': 'ورش عن نافع',
            'server': 'https://cdn.example.com/a/r2/',
            'surah_list': '2, 5 ,x,200,5',
          },
          {'id': 12, 'name': 'empty', 'server': 'https://x/', 'surah_list': ''},
        ],
      },
      {'id': 2, 'name': 'No audio', 'moshaf': []},
      {'id': 3, 'name': 'bad', 'moshaf': 'oops'},
    ],
  };

  test('parses reciters, dropping unplayable ones', () {
    final list = Mp3QuranApi.parseReciters(payload);
    expect(list.map((r) => r.id), [1]);
    expect(list.first.moshaf.map((m) => m.id), [10, 11]);
  });

  test('reciter with multiple moshaf keeps ids distinct', () {
    final r = Mp3QuranApi.parseReciters(payload).first;
    expect(r.moshafById(11)!.name, 'ورش عن نافع');
    expect(r.moshafById(1), isNull); // reciter id is not a moshaf id
  });

  test('surah_list parsing is sorted, deduped and range-checked', () {
    expect(Mp3Moshaf.parseSurahList('2, 5 ,x,200,5,0'), [2, 5]);
    expect(Mp3Moshaf.parseSurahList(null), isEmpty);
  });

  test('audio URL only for available surahs, 3-digit padded', () {
    final m = Mp3QuranApi.parseReciters(payload).first.moshaf.first;
    expect(m.audioUrlFor(1), 'https://cdn.example.com/a/r1/001.mp3');
    expect(m.audioUrlFor(114), 'https://cdn.example.com/a/r1/114.mp3');
    expect(m.audioUrlFor(4), isNull);
    expect(m.hasSurah(4), isFalse);
  });

  test('parses suwar and rejects malformed payloads', () {
    final s = Mp3QuranApi.parseSuwar({
      'suwar': [
        {'id': 1, 'name': 'الفاتحة'},
        {'id': 2, 'name': 'البقرة'},
      ]
    });
    expect(s.map((e) => e.id), [1, 2]);
    expect(() => Mp3QuranApi.parseSuwar('<html>'), throwsA(anything));
  });

  test('search ignores hamza and diacritics', () {
    final all = Mp3QuranApi.parseReciters(payload);
    expect(filterReciters(all, 'احمد'), hasLength(1));
    expect(filterReciters(all, 'zzz'), isEmpty);
    expect(filterReciters(all, ''), all);
  });
}
