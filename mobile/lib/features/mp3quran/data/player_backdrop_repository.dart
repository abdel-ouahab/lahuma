import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';
import '../domain/player_backdrop.dart';

/// The Now Playing background the listener picked (SharedPreferences).
class PlayerBackdropRepository {
  Future<PlayerBackdrop> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PlayerBackdrop.fromName(
        prefs.getString(StorageKeys.playerBackdrop));
  }

  Future<void> save(PlayerBackdrop backdrop) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.playerBackdrop, backdrop.name);
  }
}
