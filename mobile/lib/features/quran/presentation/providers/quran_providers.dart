import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/arabic_text.dart';
import '../../data/quran_remote_data_source.dart';
import '../../data/quran_repository_impl.dart';
import '../../domain/quran_repository.dart';
import '../../domain/surah.dart';
import '../../domain/surah_detail.dart';

final quranRepositoryProvider = Provider<QuranRepository>((ref) {
  return QuranRepositoryImpl(QuranRemoteDataSource());
});

final surahListProvider = FutureProvider<List<Surah>>((ref) async {
  return ref.watch(quranRepositoryProvider).getSurahList();
});

final surahDetailProvider =
    FutureProvider.family<SurahDetail, int>((ref, surahNumber) async {
  return ref.watch(quranRepositoryProvider).getSurah(surahNumber);
});

/// Translation (English, Sahih International) for a surah.
final translationProvider =
    FutureProvider.family<Map<int, String>, int>((ref, surahNumber) async {
  return ref
      .watch(quranRepositoryProvider)
      .getEdition(surahNumber, QuranEditions.translationEn);
});

/// Arabic tafsir (Al-Muyassar) for a surah.
final tafsirProvider =
    FutureProvider.family<Map<int, String>, int>((ref, surahNumber) async {
  return ref
      .watch(quranRepositoryProvider)
      .getEdition(surahNumber, QuranEditions.tafsirAr);
});

final surahSearchQueryProvider = StateProvider<String>((ref) => '');

/// Surahs matching [query] by number, Arabic name or English name.
///
/// Arabic matching ignores diacritics and the "سورة" prefix: the API names
/// are fully vowelled Uthmani text (e.g. `سُورَةُ السَّجۡدَةِ`), so a plain
/// `السجدة` has to match it. Arabic-Indic digits count as numbers.
List<Surah> filterSurahs(List<Surah> surahs, String query) {
  final q = westernDigits(query).trim().toLowerCase();
  if (q.isEmpty) return surahs;
  final arabic = _withoutSurahWord(normalizeArabic(q));
  // Only "سورة" typed so far: every surah still matches.
  if (arabic.isEmpty && q.contains(RegExp('[؀-ۿ]'))) return surahs;
  return surahs
      .where((s) =>
          '${s.number}' == q ||
          (arabic.isNotEmpty &&
              _withoutSurahWord(normalizeArabic(s.arabicName))
                  .contains(arabic)) ||
          s.englishName.toLowerCase().contains(q) ||
          s.englishNameTranslation.toLowerCase().contains(q))
      .toList();
}

String _withoutSurahWord(String normalized) =>
    normalized.replaceFirst(RegExp(r'^سوره\s*'), '');
