import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// `lahuma/adhan`: Android only. Turns a downloaded file into a
/// `content://` URI the system can play as a channel sound (MediaStore
/// Notifications on Android 10+, a FileProvider with a read grant before).
/// See `AdhanSoundChannel.kt`.
class AdhanSoundPlatform {
  const AdhanSoundPlatform();

  static const _channel = MethodChannel('lahuma/adhan');

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Publishes [path] under [name] and returns its URI, or null when that
  /// failed (the caller falls back to the bundled sound).
  Future<String?> exposeSound(String path, String name) async {
    if (!_android) return null;
    try {
      return await _channel
          .invokeMethod<String>('exposeSound', {'path': path, 'name': name});
    } catch (e) {
      debugPrint('Adhan: exposeSound failed: $e');
      return null;
    }
  }

  /// Removes every sound this app published except [keep] (by name).
  Future<void> removeSoundsExcept(Set<String> keep) async {
    if (!_android) return;
    try {
      await _channel
          .invokeMethod<void>('removeSounds', {'keep': keep.toList()});
    } catch (e) {
      debugPrint('Adhan: removeSounds failed: $e');
    }
  }
}
