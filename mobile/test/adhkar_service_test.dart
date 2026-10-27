import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/adhkar/data/adhkar_service.dart';
import 'package:lahuma/features/adhkar/domain/dhikr.dart';
import 'helpers/adhkar_fakes.dart';

/// Letters only: no whitespace, no harakat, no tatweel.
String letters(String s) =>
    s.replaceAll(RegExp(r'[\s\u064B-\u0652\u0640]'), '');

void main() {
  group('parse (real dataset)', () {
    final collection = AdhkarService.parse(fixture);
    final source = jsonDecode(fixture) as Map<String, dynamic>;

    test('reads 25 morning and 25 evening adhkar in source order', () {
      for (final p in AdhkarPeriod.values) {
        final list = collection.of(p);
        expect(list, hasLength(25));
        expect(list.map((d) => d.index), List.generate(25, (i) => i));
      }
    });

    test('never changes a letter of the source text', () {
      for (final p in AdhkarPeriod.values) {
        final raw = (source[p.sourceKey] as List).cast<Map<String, dynamic>>();
        for (final d in collection.of(p)) {
          expect(letters(d.text), letters(raw[d.index]['content'] as String),
              reason: d.id);
        }
      }
    });

    test('parses zero-padded counts', () {
      final m = collection.of(AdhkarPeriod.morning);
      final e = collection.of(AdhkarPeriod.evening);
      expect(m[0].count, 1);
      expect(m[4].count, 7);
      expect(m[22].count, 100);
      expect(e[0].count, 1); // "01"
      expect(e[5].count, 7); // "07"
      expect(e[24].count, 100);
    });

    test('removes the harakah stranded after a space', () {
      expect(
          (source['أذكار الصباح'] as List)[3]['content'], contains(' \u064F '));
      for (final p in AdhkarPeriod.values) {
        for (final d in collection.of(p)) {
          expect(RegExp(r'\s[\u064B-\u0652]').hasMatch(d.text), isFalse,
              reason: d.id);
        }
      }
    });

    test('keeps source virtues verbatim, minus the withheld ones', () {
      final m = collection.of(AdhkarPeriod.morning);
      final e = collection.of(AdhkarPeriod.evening);
      expect(m[1].virtue,
          'من قالها موقنا بها حين يمسى ومات من ليلته دخل الجنة وكذلك حين يصبح.');

      // Withheld: misattributed (istighfar) and misquoted (bismillah).
      expect(m[24].text, 'أسْتَغْفِرُ اللهَ وَأتُوبُ إلَيْهِ');
      expect(m[24].virtue, isNull);
      expect(m[5].virtue, isNull);
      expect(e[6].virtue, isNull);

      // The correct virtue of the tahlil 100 times stays.
      expect(m[22].virtue, startsWith('كانت له عدل عشر رقاب'));
      expect(m.where((d) => d.virtue != null), hasLength(7));
      expect(e.where((d) => d.virtue != null), hasLength(8));
    });

    test('has no references for morning / evening (the source gives none)', () {
      for (final p in AdhkarPeriod.values) {
        expect(collection.of(p).every((d) => d.reference == null), isTrue);
      }
    });
  });

  group('parse (bad input)', () {
    Matcher fails(AdhkarFailure f) =>
        throwsA(isA<AdhkarException>().having((e) => e.failure, 'failure', f));

    String entry(String content, {String count = '1'}) => jsonEncode({
          'category': '',
          'count': count,
          'description': '',
          'reference': '',
          'content': content,
        });

    test('invalid JSON is malformed', () {
      expect(() => AdhkarService.parse('{"أذكار الصباح": ['),
          fails(AdhkarFailure.malformed));
      expect(() => AdhkarService.parse('404: Not Found'),
          fails(AdhkarFailure.malformed));
    });

    test('wrong shape is malformed', () {
      expect(() => AdhkarService.parse('[]'), fails(AdhkarFailure.malformed));
      expect(() => AdhkarService.parse('{"أذكار الصباح": []}'),
          fails(AdhkarFailure.malformed));
      expect(
          () => AdhkarService.parse('{"أذكار الصباح": {}, "أذكار المساء": []}'),
          fails(AdhkarFailure.malformed));
    });

    test('no usable entries is empty', () {
      expect(
          () => AdhkarService.parse('{"أذكار الصباح": [], "أذكار المساء": []}'),
          fails(AdhkarFailure.empty));
      expect(
          () => AdhkarService.parse(
              '{"أذكار الصباح": [${entry('  ')}, 3, null], "أذكار المساء": []}'),
          fails(AdhkarFailure.empty));
    });

    test('skips bad entries and defaults bad counts to 1', () {
      final c = AdhkarService.parse('{"أذكار الصباح": ['
          '${entry('سُبْحَانَ اللَّهِ', count: 'abc')}, "x", '
          '${entry('الحَمْدُ لِلَّهِ', count: '0')}'
          '], "أذكار المساء": []}');
      final m = c.of(AdhkarPeriod.morning);
      expect(m.map((d) => d.index), [0, 2]);
      expect(m.map((d) => d.count), [1, 1]);
      expect(c.of(AdhkarPeriod.evening), isEmpty);
    });
  });

  group('load', () {
    test('fetches, then caches the raw dataset', () async {
      final adapter = FakeAdapter(body: fixture);
      final cache = MemoryCache();
      final c = await service(adapter, cache).load();
      expect(c.of(AdhkarPeriod.morning), hasLength(25));
      expect(cache.value, fixture);
      expect(adapter.calls, 1);
    });

    test('works offline from the cache without touching the network', () async {
      final adapter = FakeAdapter(error: DioExceptionType.connectionError);
      final c = await service(adapter, MemoryCache(fixture)).load();
      expect(c.of(AdhkarPeriod.evening), hasLength(25));
      expect(adapter.calls, 0);
    });

    test('offline with no cache reports offline', () async {
      final adapter = FakeAdapter(error: DioExceptionType.connectionTimeout);
      await expectLater(
        service(adapter, MemoryCache()).load(),
        throwsA(isA<AdhkarException>()
            .having((e) => e.failure, 'failure', AdhkarFailure.offline)),
      );
    });

    test('a server error with no cache is generic', () async {
      final adapter = FakeAdapter(error: DioExceptionType.badResponse);
      await expectLater(
        service(adapter, MemoryCache()).load(),
        throwsA(isA<AdhkarException>()
            .having((e) => e.failure, 'failure', AdhkarFailure.generic)),
      );
    });

    test('never caches a malformed response', () async {
      final cache = MemoryCache();
      await expectLater(
        service(FakeAdapter(body: '<html>'), cache).load(),
        throwsA(isA<AdhkarException>()
            .having((e) => e.failure, 'failure', AdhkarFailure.malformed)),
      );
      expect(cache.value, isNull);
    });

    test('replaces a corrupt cache with a fresh download', () async {
      final adapter = FakeAdapter(body: fixture);
      final cache = MemoryCache('{broken');
      final c = await service(adapter, cache).load();
      expect(c.of(AdhkarPeriod.morning), hasLength(25));
      expect(cache.value, fixture);
      expect(adapter.calls, 1);
    });

    test('refresh falls back to the cache when offline', () async {
      final adapter = FakeAdapter(error: DioExceptionType.connectionError);
      final c =
          await service(adapter, MemoryCache(fixture)).load(refresh: true);
      expect(c.of(AdhkarPeriod.morning), hasLength(25));
      expect(adapter.calls, 1);
    });
  });
}
