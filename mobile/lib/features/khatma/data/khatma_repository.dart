import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';
import '../domain/khatma.dart';

/// Everything the khatma keeps, as JSON in SharedPreferences: the active
/// (or paused) khatma, the completed ones, and the daily reading log.
/// Nothing here is uploaded.
class KhatmaRepository {
  Future<Khatma?> loadActive() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.khatmaActive);
    if (raw == null) return null;
    try {
      return Khatma.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> saveActive(Khatma? khatma) async {
    final prefs = await SharedPreferences.getInstance();
    if (khatma == null) {
      await prefs.remove(StorageKeys.khatmaActive);
    } else {
      await prefs.setString(
          StorageKeys.khatmaActive, jsonEncode(khatma.toJson()));
    }
  }

  /// Completed khatmas, newest first.
  Future<List<Khatma>> loadHistory() async => [
        for (final item in await _readList(StorageKeys.khatmaHistory))
          if (Khatma.fromJson(item) case final k?) k,
      ];

  Future<void> saveHistory(List<Khatma> history) =>
      _write(StorageKeys.khatmaHistory, [for (final k in history) k.toJson()]);

  Future<List<DailyLog>> loadLogs() async => [
        for (final item in await _readList(StorageKeys.khatmaLogs))
          if (DailyLog.fromJson(item) case final log?) log,
      ];

  Future<void> saveLogs(List<DailyLog> logs) =>
      _write(StorageKeys.khatmaLogs, [for (final l in logs) l.toJson()]);

  Future<List<Object?>> _readList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : const [];
    } on FormatException {
      return const [];
    }
  }

  Future<void> _write(String key, List<Object?> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }
}
