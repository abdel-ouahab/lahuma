import 'package:qcf_quran/qcf_quran.dart' as qcf;
import '../../domain/juz_data.dart';

/// One surah's ayahs on a Mushaf page.
class PageSurah {
  const PageSurah(this.surah, this.firstAyah, this.lastAyah);

  final int surah;
  final int firstAyah;
  final int lastAyah;
}

/// Facts about the Madinah Mushaf (604 pages), read from the qcf_quran
/// tables so the page breaks always match the rendered fonts.
class MushafMeta {
  MushafMeta._();

  static const int pageCount = qcf.totalPagesCount;
  static const int surahCount = qcf.totalSurahCount;
  static const int juzCount = qcf.totalJuzCount;

  static List<PageSurah> surahsOn(int page) => [
        for (final r in qcf.getPageData(page))
          PageSurah(
            int.parse(r['surah'].toString()),
            int.parse(r['start'].toString()),
            int.parse(r['end'].toString()),
          ),
      ];

  /// The surah the page opens with (what a printed Mushaf names in its
  /// header).
  static int surahOf(int page) => surahsOn(page).first.surah;

  /// The juz' the page's first ayah belongs to.
  static int juzOf(int page) {
    final first = surahsOn(page).first;
    return qcf.getJuzNumber(first.surah, first.firstAyah);
  }

  static String surahName(int surah) => qcf.getSurahNameArabic(surah);

  static String surahNameLatin(int surah) => qcf.getSurahName(surah);

  static int ayahCount(int surah) => qcf.getVerseCount(surah);

  /// The package data spells the places inconsistently ("Makkah", "makkah",
  /// "Madinah", "Manidah"), so only the prefix is trusted.
  static bool isMakki(int surah) =>
      qcf.getPlaceOfRevelation(surah).toLowerCase().startsWith('mak');

  static String ayahText(int surah, int ayah) => qcf.getVerse(surah, ayah);

  static final List<int> _surahStartPages = [
    for (var s = 1; s <= surahCount; s++) qcf.getPageNumber(s, 1),
  ];

  static int surahStartPage(int surah) => _surahStartPages[surah - 1];

  static final List<int> _juzStartPages = [
    for (final j in juzStarts) qcf.getPageNumber(j.surah, j.ayah),
  ];

  static int juzStartPage(int juz) => _juzStartPages[juz - 1];

  /// The surah a juz' opens in.
  static int juzStartSurah(int juz) => juzStarts[juz - 1].surah;
}
