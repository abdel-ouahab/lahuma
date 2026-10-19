import 'package:flutter_riverpod/flutter_riverpod.dart';
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
