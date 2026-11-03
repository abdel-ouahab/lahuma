import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/core/utils/arabic_text.dart';
import 'package:lahuma/features/quran/domain/surah.dart';
import 'package:lahuma/features/quran/presentation/providers/quran_providers.dart';

Surah _surah(int number, String name, String english, String translation) =>
    Surah(
      number: number,
      arabicName: name,
      englishName: english,
      englishNameTranslation: translation,
      ayahCount: 1,
      revelationType: 'Meccan',
    );

void main() {
  // Names exactly as api.alquran.cloud returns them.
  final surahs = [
    _surah(1, 'سُورَةُ ٱلْفَاتِحَةِ', 'Al-Faatiha', 'The Opening'),
    _surah(2, 'سُورَةُ البَقَرَةِ', 'Al-Baqara', 'The Cow'),
    _surah(5, 'سُورَةُ المَائـِدَةِ', 'Al-Maaida', 'The Table'),
    _surah(32, 'سُورَةُ السَّجۡدَةِ', 'As-Sajda', 'The Prostration'),
    _surah(36, 'سُورَةُ يسٓ', 'Yaseen', 'Yaseen'),
    _surah(112, 'سُورَةُ الإِخۡلَاصِ', 'Al-Ikhlaas', 'Sincerity'),
  ];

  List<int> search(String q) =>
      filterSurahs(surahs, q).map((s) => s.number).toList();

  test('plain Arabic matches the vowelled Uthmani names', () {
    expect(search('السجدة'), [32]);
    expect(search('الفاتحة'), [1]);
    expect(search('الفاتحه'), [1]);
    expect(search('البقرة'), [2]);
    expect(search('المائدة'), [5]);
    expect(search('الاخلاص'), [112]);
    expect(search('يس'), [36]);
  });

  test('the "سورة" prefix is optional in the query', () {
    expect(search('سورة البقرة'), [2]);
    expect(search('سورة'), hasLength(surahs.length));
  });

  test('numbers match in Western and Arabic-Indic digits', () {
    expect(search('36'), [36]);
    expect(search('٣٦'), [36]);
  });

  test('English names and translations still match', () {
    expect(search('baqara'), [2]);
    expect(search('cow'), [2]);
    expect(search(''), hasLength(surahs.length));
  });

  test('normalizeArabic drops Quranic marks and tatweel', () {
    expect(normalizeArabic('السَّجۡدَةِ'), 'السجده');
    expect(normalizeArabic('المَائـِدَةِ'), 'المائده');
    expect(normalizeArabic('ٱلرَّحۡمَٰنِ'), 'الرحمن');
  });
}
