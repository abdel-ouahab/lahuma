import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../dedication/presentation/dedication_providers.dart';
import '../../wird/presentation/wird_providers.dart';
import '../data/reading_progress_repository.dart';
import '../domain/reading_progress.dart';

final readingProgressRepositoryProvider = Provider((ref) => ReadingProgressRepository());

final readingProgressProvider =
    FutureProvider<ReadingProgress?>((ref) async {
  return ref.watch(readingProgressRepositoryProvider).getLastProgress();
});

/// Turns "ayah N is on screen" events from the reader into saved progress,
/// today's wird count and the dedication tally.
///
/// Only ayahs the reader moves *past* are counted, so reopening a surah or
/// jumping straight to an ayah never inflates the numbers.
class ReadingTracker {
  ReadingTracker(this._ref);

  final Ref _ref;

  /// Most ayahs credited per scroll event, so a fling can't skip a surah's
  /// worth of credit in one go.
  static const int maxCreditPerEvent = 8;

  int? _surah;
  int _furthest = 0;

  /// Call when the reader opens a surah; [startAyah] is where it begins.
  void begin(int surah, int startAyah) {
    _surah = surah;
    _furthest = startAyah;
  }

  Future<void> onAyahVisible({
    required int surah,
    required String surahName,
    required int ayah,
    required int totalAyahs,
  }) async {
    if (_surah != surah) begin(surah, ayah);

    await _ref.read(readingProgressRepositoryProvider).saveProgress(
          ReadingProgress(
            surahId: surah,
            surahName: surahName,
            // `ayah` may be totalAyahs + 1 to signal "reached the end".
            ayahNumber: ayah.clamp(1, totalAyahs).toInt(),
            totalAyahs: totalAyahs,
          ),
        );
    _ref.invalidate(readingProgressProvider);

    if (ayah > _furthest) {
      final credit = (ayah - _furthest).clamp(0, maxCreditPerEvent);
      _furthest = ayah;
      await _ref.read(wirdProvider.notifier).addRead(credit);
      await _ref.read(dedicationProvider.notifier).addRead(credit);
    }
  }
}

final readingTrackerProvider = Provider((ref) => ReadingTracker(ref));
