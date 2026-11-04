import 'package:qcf_quran/qcf_quran.dart' as qcf;
import '../../quran/mushaf/domain/mushaf_meta.dart';
import 'hizb_data.dart';

/// Page → juz' / hizb / surah lookups on the Madinah Mushaf (604 pages,
/// 30 juz', 60 ahzab), the reference every khatma is measured in.
class QuranPages {
  QuranPages._();

  static const int total = MushafMeta.pageCount;
  static const int juzCount = MushafMeta.juzCount;
  static const int hizbCount = 60;

  /// Average pages in one juz' / hizb, for "≈ 1 juz'" style previews.
  static const double pagesPerJuz = total / juzCount;
  static const double pagesPerHizb = total / hizbCount;

  static final List<int> _hizbStartPages = [
    for (final h in hizbStarts) qcf.getPageNumber(h.surah, h.ayah),
  ];

  /// The page hizb [hizb] (1–60) begins on.
  static int hizbStartPage(int hizb) => _hizbStartPages[hizb - 1];

  /// The hizb being read on [page]: the last one that has begun by then.
  static int hizbAt(int page) {
    var hizb = 1;
    while (hizb < hizbCount && _hizbStartPages[hizb] <= page) {
      hizb++;
    }
    return hizb;
  }

  /// The last page of [hizb] at page granularity: the page before the next
  /// hizb's start page (604 for the last hizb).
  static int hizbEndPage(int hizb) =>
      hizb >= hizbCount ? total : _hizbStartPages[hizb] - 1;

  /// The juz' being read on [page], counted the same way as [hizbAt].
  static int juzAt(int page) {
    var juz = 1;
    while (juz < juzCount && MushafMeta.juzStartPage(juz + 1) <= page) {
      juz++;
    }
    return juz;
  }

  /// The surah a page opens with.
  static int surahAt(int page) => MushafMeta.surahOf(page.clamp(1, total));

  static String surahName(int page, {required bool arabic}) {
    final surah = surahAt(page);
    return arabic
        ? MushafMeta.surahName(surah)
        : MushafMeta.surahNameLatin(surah);
  }

  static int surahStartPage(int surah) => MushafMeta.surahStartPage(surah);

  /// The first [words] words of the ayah that opens [page] (Madinah pages
  /// always open on a whole ayah), with "…" when the ayah goes on.
  static String openingWords(int page, {int words = 6}) {
    final first = MushafMeta.surahsOn(page.clamp(1, total)).first;
    final text = MushafMeta.ayahText(first.surah, first.firstAyah).trim();
    final parts = text.split(RegExp(r'\s+'));
    return parts.length <= words ? text : '${parts.take(words).join(' ')} …';
  }
}
