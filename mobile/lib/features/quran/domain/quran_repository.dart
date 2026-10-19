import 'surah.dart';
import 'surah_detail.dart';

/// Abstract boundary so the Quran data provider can be swapped
/// (different API, bundled offline dataset, etc.) without any change
/// to providers or UI.
abstract class QuranRepository {
  Future<List<Surah>> getSurahList();
  Future<SurahDetail> getSurah(int number);

  /// Text of another edition (translation / tafsir) keyed by ayah number in
  /// the surah, e.g. `en.sahih` or `ar.muyassar`.
  Future<Map<int, String>> getEdition(int surahNumber, String edition);
}

/// Edition identifiers on api.alquran.cloud.
class QuranEditions {
  QuranEditions._();

  static const String translationEn = 'en.sahih';
  static const String tafsirAr = 'ar.muyassar';
}
