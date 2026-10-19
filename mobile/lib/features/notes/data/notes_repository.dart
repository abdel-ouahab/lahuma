import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';

/// Personal notes attached to individual ayahs, stored on-device as one JSON
/// map keyed by `surah:ayah`.
class NotesRepository {
  static String key(int surah, int ayah) => '$surah:$ayah';

  Future<Map<String, String>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.ayahNotes);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
  }

  Future<void> saveAll(Map<String, String> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.ayahNotes, jsonEncode(notes));
  }
}
