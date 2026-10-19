import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';
import '../domain/reading_progress.dart';

/// Local-only reading progress. No authentication required — this is
/// intentional per the MVP spec (guest usage must always work).
class ReadingProgressRepository {
  Future<ReadingProgress?> getLastProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final surahId = prefs.getInt(StorageKeys.lastReadSurahId);
    final surahName = prefs.getString(StorageKeys.lastReadSurahName);
    final ayahNumber = prefs.getInt(StorageKeys.lastReadAyahNumber);

    if (surahId == null || surahName == null || ayahNumber == null) {
      return null;
    }

    return ReadingProgress(
      surahId: surahId,
      surahName: surahName,
      ayahNumber: ayahNumber,
      totalAyahs: prefs.getInt(StorageKeys.lastReadTotalAyahs) ?? 0,
    );
  }

  Future<void> saveProgress(ReadingProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.lastReadSurahId, progress.surahId);
    await prefs.setString(StorageKeys.lastReadSurahName, progress.surahName);
    await prefs.setInt(StorageKeys.lastReadAyahNumber, progress.ayahNumber);
    await prefs.setInt(StorageKeys.lastReadTotalAyahs, progress.totalAyahs);
  }
}
