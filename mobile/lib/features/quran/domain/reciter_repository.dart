import 'reciter.dart';
import 'surah_audio.dart';

/// Abstract contract for reciter data access.
/// Swap the implementation (local / API / Supabase) without touching UI.
abstract class ReciterRepository {
  /// Returns all available reciters.
  Future<List<Reciter>> getReciters();

  /// Returns the list of Surah audio entries available for [reciter].
  /// This lets callers know which surahs are downloadable/playable.
  Future<List<SurahAudio>> getAvailableSurahs(Reciter reciter);
}
