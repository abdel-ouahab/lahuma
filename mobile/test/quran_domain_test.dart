import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/quran/domain/juz_data.dart';
import 'package:lahuma/features/quran/domain/surah_detail.dart';
import 'package:lahuma/features/reading_progress/domain/reading_progress.dart';

Map<String, dynamic> _surahJson(int number, String firstAyahText) => {
      'number': number,
      'name': 'سورة',
      'englishName': 'Surah',
      'ayahs': [
        {'number': 1, 'numberInSurah': 1, 'text': firstAyahText},
        {'number': 2, 'numberInSurah': 2, 'text': 'الٓمٓ'},
      ],
    };

void main() {
  group('juz starts', () {
    test('has 30 juz in reading order', () {
      expect(juzStarts, hasLength(30));
      expect(arabicJuzNames, hasLength(30));
      for (var i = 1; i < juzStarts.length; i++) {
        final prev = juzStarts[i - 1];
        final cur = juzStarts[i];
        expect(cur.juz, prev.juz + 1);
        final later = cur.surah > prev.surah ||
            (cur.surah == prev.surah && cur.ayah > prev.ayah);
        expect(later, isTrue,
            reason: 'juz ${cur.juz} must start after ${prev.juz}');
      }
    });

    test('opens at the start of the Quran and ends at Juz Amma', () {
      expect((juzStarts.first.surah, juzStarts.first.ayah), (1, 1));
      expect((juzStarts.last.surah, juzStarts.last.ayah), (78, 1));
    });
  });

  group('SurahDetail basmala handling', () {
    const basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

    test('drops the basmala prepended to ayah 1', () {
      final detail = SurahDetail.fromJson(_surahJson(2, '$basmala الٓمٓ'));
      expect(detail.ayahs.first.text, 'الٓمٓ');
      expect(detail.ayahs.first.number, 1);
    });

    test('keeps ayah 1 of Al-Fatiha, where the basmala is the ayah', () {
      final detail = SurahDetail.fromJson(_surahJson(1, basmala));
      expect(detail.ayahs.first.text, basmala);
    });

    test('leaves ayah 1 alone when it does not start with the basmala', () {
      final detail =
          SurahDetail.fromJson(_surahJson(2, 'one two three four five'));
      expect(detail.ayahs.first.text, 'one two three four five');
    });
  });

  group('ReadingProgress.percent', () {
    test('is the share of the surah reached', () {
      const p = ReadingProgress(
          surahId: 2, surahName: 'x', ayahNumber: 50, totalAyahs: 200);
      expect(p.percent, 25);
    });

    test('is null when the surah length is unknown', () {
      const p = ReadingProgress(surahId: 2, surahName: 'x', ayahNumber: 5);
      expect(p.percent, isNull);
    });

    test('never exceeds 100', () {
      const p = ReadingProgress(
          surahId: 1, surahName: 'x', ayahNumber: 9, totalAyahs: 7);
      expect(p.percent, 100);
    });
  });
}
