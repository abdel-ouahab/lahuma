import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';
import '../domain/call_session.dart';
import '../domain/fajr_call_list.dart';
import '../domain/prayer_settings.dart';

/// Fajr Call lists, their recent results and the prayer-time settings, as
/// JSON in SharedPreferences. Nothing here is uploaded.
class FajrCallRepository {
  /// The log keeps the most recent sessions only.
  static const int maxSessions = 30;

  Future<List<FajrCallList>> loadLists() async {
    final raw = await _readList(StorageKeys.fajrCallLists);
    return [
      for (final item in raw)
        if (item is Map) FajrCallList.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<void> saveLists(List<FajrCallList> lists) => _write(
      StorageKeys.fajrCallLists, [for (final l in lists) l.toJson()]);

  /// Newest first.
  Future<List<CallSession>> loadSessions() async {
    final raw = await _readList(StorageKeys.fajrCallSessions);
    final sessions = [
      for (final item in raw)
        if (item is Map) CallSession.fromJson(Map<String, dynamic>.from(item)),
    ];
    return _sorted(sessions);
  }

  Future<void> saveSessions(List<CallSession> sessions) {
    final kept = _sorted(sessions).take(maxSessions);
    return _write(
        StorageKeys.fajrCallSessions, [for (final s in kept) s.toJson()]);
  }

  /// Adds new sessions, or replaces stored ones with the same id (a session
  /// written by the native engine, then ticked on the wake list). Returns
  /// the stored log, newest first.
  Future<List<CallSession>> upsertSessions(List<CallSession> incoming) async {
    if (incoming.isEmpty) return loadSessions();
    final byId = {for (final s in await loadSessions()) s.id: s};
    for (final s in incoming) {
      byId[s.id] = s;
    }
    final all = _sorted(byId.values.toList()).take(maxSessions).toList();
    await saveSessions(all);
    return all;
  }

  Future<void> clearSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.fajrCallSessions);
  }

  Future<PrayerSettings> loadPrayerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.fajrCallPrayerSettings);
    if (raw == null) return const PrayerSettings();
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        return PrayerSettings.fromJson(Map<String, dynamic>.from(json));
      }
    } on FormatException {
      // Corrupt data: fall back to defaults rather than crash.
    }
    return const PrayerSettings();
  }

  Future<void> savePrayerSettings(PrayerSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        StorageKeys.fajrCallPrayerSettings, jsonEncode(settings.toJson()));
  }

  static List<CallSession> _sorted(List<CallSession> sessions) =>
      [...sessions]..sort((a, b) => b.firedAt.compareTo(a.firedAt));

  Future<List<dynamic>> _readList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return const [];
    try {
      final json = jsonDecode(raw);
      return json is List ? json : const [];
    } on FormatException {
      return const [];
    }
  }

  Future<void> _write(String key, List<Map<String, dynamic>> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }
}
