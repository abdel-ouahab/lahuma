import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';

/// On-device list of favourite MP3Quran reciter ids (SharedPreferences).
class ReciterFavoritesRepository {
  Future<Set<int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(StorageKeys.reciterFavorites) ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
  }

  Future<void> save(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      StorageKeys.reciterFavorites,
      [for (final id in ids) '$id'],
    );
  }
}
