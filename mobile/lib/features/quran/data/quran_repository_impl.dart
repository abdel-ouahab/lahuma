import '../domain/quran_repository.dart';
import '../domain/surah.dart';
import '../domain/surah_detail.dart';
import 'quran_remote_data_source.dart';

class QuranRepositoryImpl implements QuranRepository {
  QuranRepositoryImpl(this._dataSource);

  final QuranRemoteDataSource _dataSource;

  @override
  Future<List<Surah>> getSurahList() async {
    final raw = await _dataSource.fetchSurahList();
    return raw.map(Surah.fromJson).toList();
  }

  @override
  Future<SurahDetail> getSurah(int number) async {
    final raw = await _dataSource.fetchSurah(number);
    return SurahDetail.fromJson(raw);
  }

  @override
  Future<Map<int, String>> getEdition(int surahNumber, String edition) async {
    final raw = await _dataSource.fetchEdition(surahNumber, edition);
    return {
      for (final a in (raw['ayahs'] as List).cast<Map<String, dynamic>>())
        a['numberInSurah'] as int: a['text'] as String,
    };
  }
}
