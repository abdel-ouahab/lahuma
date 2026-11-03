import 'khatma.dart';
import 'quran_pages.dart';

/// Counted nouns for the khatma, in both languages. Arabic follows the
/// number: 1 and 2 have their own forms, 3–10 take the plural, 11+ the
/// singular accusative.
class KhatmaText {
  KhatmaText._();

  static String _ar(int n, String one, String two, String few, String many) {
    if (n == 1) return one;
    if (n == 2) return two;
    final r = n % 100;
    return r >= 3 && r <= 10 ? '$n $few' : '$n $many';
  }

  /// "20 صفحة" / "20 pages".
  static String pages(int n, {required bool arabic}) => arabic
      ? _ar(n, 'صفحة واحدة', 'صفحتان', 'صفحات', 'صفحة')
      : n == 1
          ? '1 page'
          : '$n pages';

  /// "3 أيام" / "3 days".
  static String days(int n, {required bool arabic}) => arabic
      ? _ar(n, 'يوم واحد', 'يومان', 'أيام', 'يومًا')
      : n == 1
          ? '1 day'
          : '$n days';

  /// [pagesCount] pages in [unit], to the nearest quarter: "جزء ونصف",
  /// "1½ juz". Pages stay exact.
  static String amount(int pagesCount, ReadingUnit unit,
      {required bool arabic}) {
    if (unit == ReadingUnit.pages) return pages(pagesCount, arabic: arabic);
    final per = unit == ReadingUnit.juz
        ? QuranPages.pagesPerJuz
        : QuranPages.pagesPerHizb;
    final quarters = (pagesCount / per * 4).round();
    final whole = quarters ~/ 4;
    final part = quarters % 4;
    return arabic
        ? _amountAr(whole, part, unit)
        : _amountEn(whole, part, unit, quarters);
  }

  static String _amountAr(int whole, int part, ReadingUnit unit) {
    final juz = unit == ReadingUnit.juz;
    final noun = juz ? 'جزء' : 'حزب';
    const fractions = ['', 'ربع', 'نصف', 'ثلاثة أرباع'];
    if (whole == 0) {
      return part == 0 ? 'أقل من ربع $noun' : '${fractions[part]} $noun';
    }
    final count = whole == 1
        ? (part == 0 ? '$noun واحد' : noun)
        : _ar(whole, noun, juz ? 'جزءان' : 'حزبان', juz ? 'أجزاء' : 'أحزاب',
            juz ? 'جزءًا' : 'حزبًا');
    return part == 0 ? count : '$count و${fractions[part]}';
  }

  static String _amountEn(int whole, int part, ReadingUnit unit, int quarters) {
    const fractions = ['', '¼', '½', '¾'];
    final noun = unit == ReadingUnit.juz
        ? 'juz'
        : quarters > 4
            ? 'hizbs'
            : 'hizb';
    if (quarters == 0) return 'under ¼ $noun';
    final number = whole == 0 ? fractions[part] : '$whole${fractions[part]}';
    return '$number $noun';
  }

  /// "صفحة 142 (الأنعام)" / "page 142 (Al-An'am)".
  static String page(int page, {required bool arabic}) {
    final surah = QuranPages.surahName(page, arabic: arabic);
    return arabic ? 'صفحة $page ($surah)' : 'page $page ($surah)';
  }

  /// "من صفحة 142 (الأنعام) إلى 161" / "page 142 (Al-An'am) to 161".
  static String range(int from, int to, {required bool arabic}) {
    if (from >= to) return page(to, arabic: arabic);
    return arabic
        ? 'من ${page(from, arabic: true)} إلى $to'
        : '${page(from, arabic: false)} to $to';
  }
}
