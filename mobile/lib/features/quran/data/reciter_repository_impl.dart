import '../domain/reciter.dart';
import '../domain/reciter_repository.dart';
import '../domain/surah_audio.dart';
import 'reciter_local_data_source.dart';

class ReciterRepositoryImpl implements ReciterRepository {
  ReciterRepositoryImpl(this._dataSource);

  final ReciterLocalDataSource _dataSource;

  @override
  Future<List<Reciter>> getReciters() async {
    return _dataSource.fetchReciters();
  }

  @override
  Future<List<SurahAudio>> getAvailableSurahs(Reciter reciter) async {
    return _dataSource.fetchAvailableSurahs(reciter);
  }
}
