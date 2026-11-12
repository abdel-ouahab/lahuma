import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/adhkar/data/adhkar_service.dart';
import 'package:lahuma/features/adhkar/domain/dhikr.dart';
import 'package:lahuma/features/quran/mushaf/domain/mushaf_meta.dart';

/// The dataset as bundled with the app.
final String bundled = File('assets/data/adhkar.json').readAsStringSync();

AdhkarCollection parse(String raw) =>
    AdhkarService.parse(raw, verse: MushafMeta.ayahText);

/// Letters only: no harakat, tatweel, Quranic marks or punctuation.
String letters(String s) =>
    s.replaceAll(RegExp('[ٱآأإ]'), 'ا').replaceAll(RegExp('[^ء-غف-ي]'), '');

void main() {
  final collection = parse(bundled);

  test('has every category the Adhkar screen lists', () {
    expect(collection.categories.map((c) => c.id), [
      'morning', 'evening', 'after_prayer', 'sleep', 'waking', 'home',
      'mosque', 'wudu', 'food', 'travel', 'riding', 'distress', 'istikhara',
      'weather', 'sick', 'quran', 'prophetic', //
    ]);
    for (final c in collection.categories) {
      expect(c.items, isNotEmpty, reason: c.id);
      expect(c.title, isNotEmpty);
      expect(c.titleEn, isNotEmpty);
    }
  });

  test('Hisn al-Muslim texts keep their tashkeel and cite a reference', () {
    for (final c in collection.categories) {
      for (final d in c.items) {
        expect(d.count, greaterThanOrEqualTo(1));
        expect(d.text, matches(RegExp('[ً-ْ]')),
            reason: '${d.id} has no diacritics');
        expect(d.reference, isNotNull, reason: '${d.id} has no reference');
        expect(d.text, isNot(contains('  ')));
      }
    }
  });

  test('counts follow the book, including ones stated in the text', () {
    Dhikr find(String category, String start) => collection
        .category(category)!
        .items
        .firstWhere((d) => letters(d.text).contains(letters(start)));
    expect(find('morning', 'سبحان الله وبحمده مائة').count, 100);
    expect(find('morning', 'حسبي الله لا إله إلا هو').count, 7);
    expect(find('after_prayer', 'وله الحمد يحيي ويميت').count, 10);
    expect(find('sick', 'أسأل الله العظيم').count, 7);
  });

  test('morning and evening differ only where the book says so', () {
    final morning = collection.of(AdhkarPeriod.morning).map((d) => d.text);
    final evening = collection.of(AdhkarPeriod.evening).map((d) => d.text);
    final onlyMorning = morning.where((t) => !evening.contains(t)).toList();
    final onlyEvening = evening.where((t) => !morning.contains(t)).toList();
    expect(onlyMorning, hasLength(3));
    expect(onlyMorning.every((t) => t.contains('إذا أصبحَ')), isTrue);
    expect(onlyEvening, hasLength(1));
    expect(onlyEvening.single, contains('إذا أمسى'));
  });

  test('a virtue is never attached to the wrong dhikr', () {
    // al-Bukhari 3293 / Muslim 2691: the virtue of tahlil said 100 times.
    final istighfar = collection.of(AdhkarPeriod.morning).firstWhere((d) =>
        letters(d.text) == letters('أستغفر الله وأتوب إليه مائة مرة في اليوم'));
    expect(istighfar.virtue, isNull);
    // Abu Dawud 5088: «لم يضره شيء», without "من الله".
    final bismillah = collection
        .of(AdhkarPeriod.morning)
        .firstWhere((d) => letters(d.text).contains(letters('لا يضر مع اسمه')));
    expect(bismillah.virtue, contains('لم يضره شيء'));
    expect(bismillah.virtue, isNot(contains('من الله')));
  });

  test('Quranic duas are read from the Mushaf text, verse by verse', () {
    final quran = collection.category('quran')!.items;
    expect(quran, hasLength(34));
    for (final d in quran) {
      expect(d.quran, isTrue);
      expect(d.reference, startsWith('سورة '));
      // Every one of them calls on Allah as Lord, or is Yunus's dua.
      final text = letters(d.text);
      expect(text.contains('رب') || text.contains('لاالهالاانتسبحنك'), isTrue,
          reason: '${d.reference}: ${d.text}');
    }
    final rabbana = quran.firstWhere((d) => d.reference == 'سورة البقرة، 201');
    expect(rabbana.text, '${MushafMeta.ayahText(2, 201).trim()} ﴿٢٠١﴾');
    final sharh = quran.firstWhere((d) => d.reference == 'سورة طه، 25–28');
    expect('﴿'.allMatches(sharh.text), hasLength(4));
  });

  test('categories that gather several chapters name each one', () {
    final travel = collection.category('travel')!.items;
    expect(travel.first.occasion, 'دعاء السفر');
    expect(travel.map((d) => d.occasion), contains('ذكر الرجوع من السفر'));
    expect(collection.category('istikhara')!.items.single.occasion, isNull);
  });

  test('ids are stable per category and position', () {
    final d = collection.category('travel')!.items.first;
    expect(d.id, 'travel-0');
    expect(collection.byId('travel-0'), d);
    expect(
        collection.of(AdhkarPeriod.morning).first.period, AdhkarPeriod.morning);
    expect(d.period, isNull);
  });

  group('parse', () {
    String verse(int s, int a) => 'آية $s:$a';

    test('rejects invalid JSON and a missing category list', () {
      expect(
          () => AdhkarService.parse('{oops', verse: verse),
          throwsA(isA<AdhkarException>()
              .having((e) => e.failure, 'failure', AdhkarFailure.malformed)));
      expect(
          () => AdhkarService.parse('{"x": []}', verse: verse),
          throwsA(isA<AdhkarException>()
              .having((e) => e.failure, 'failure', AdhkarFailure.malformed)));
    });

    test('an empty dataset is an error', () {
      expect(
          () => AdhkarService.parse(
              '{"categories": [{"id": "a", "items": []}]}',
              verse: verse),
          throwsA(isA<AdhkarException>()
              .having((e) => e.failure, 'failure', AdhkarFailure.empty)));
    });

    test('skips broken items and defaults the count', () {
      final c = AdhkarService.parse('''
        {"categories": [{"id": "a", "group": "travel", "items": [
          {"text": "  ذِكْرٌ  ", "count": 0},
          {"count": 3},
          "nope",
          {"quran": {"surah": 2, "from": 5, "to": 4}},
          {"quran": {"surah": 1, "from": 2, "to": 3}, "reference": "الفاتحة"}
        ]}]}''', verse: verse);
      final items = c.category('a')!.items;
      expect(c.category('a')!.group, AdhkarGroup.travel);
      expect(items.map((d) => d.text), ['ذِكْرٌ', 'آية 1:2 ﴿٢﴾ آية 1:3 ﴿٣﴾']);
      expect(items.first.count, 1);
      expect(items.map((d) => d.index), [0, 1]);
    });
  });

  test('loads through the injected source', () async {
    final service =
        AdhkarService(load: () async => bundled, verse: MushafMeta.ayahText);
    expect((await service.load()).categories, hasLength(17));
  });
}
