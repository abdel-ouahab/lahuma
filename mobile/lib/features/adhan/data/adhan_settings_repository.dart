import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';
import '../domain/adhan_settings.dart';
import '../domain/muezzin.dart';

/// Adhan settings, the record of the downloaded muezzin and the last
/// adhan played, in prefs.
class AdhanSettingsRepository {
  Future<AdhanSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.adhanSettings);
    if (raw == null) return const AdhanSettings();
    try {
      return AdhanSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const AdhanSettings();
    }
  }

  Future<void> saveSettings(AdhanSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        StorageKeys.adhanSettings, jsonEncode(settings.toJson()));
  }

  Future<AdhanDownload?> loadDownload() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.adhanDownload);
    if (raw == null) return null;
    try {
      return AdhanDownload.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDownload(AdhanDownload? download) async {
    final prefs = await SharedPreferences.getInstance();
    if (download == null) {
      await prefs.remove(StorageKeys.adhanDownload);
    } else {
      await prefs.setString(
          StorageKeys.adhanDownload, jsonEncode(download.toJson()));
    }
  }

  /// The id of the last adhan played in the app (ids grow with time).
  Future<int?> loadLastPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(StorageKeys.adhanLastPlayed);
  }

  Future<void> saveLastPlayed(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.adhanLastPlayed, id);
  }
}
