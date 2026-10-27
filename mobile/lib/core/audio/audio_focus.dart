import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Makes sure only one of the app's players is heard at a time.
///
/// The app has three: ayah-by-ayah recitation in the reader
/// (`AyahAudioNotifier`), the Lahuma reciters player (`QuranAudioService`) and
/// the MP3Quran player (`Mp3PlaybackController`). Each registers how to stop
/// itself; before it starts or resumes, it [claim]s focus, which stops every
/// other player. Stopping also ends that player's session, so its mini-player
/// goes away.
class AudioFocus {
  final Map<Object, AsyncCallback> _players = {};

  /// Registers [stop] for [owner], usually the player object itself.
  void register(Object owner, AsyncCallback stop) => _players[owner] = stop;

  void unregister(Object owner) => _players.remove(owner);

  /// Stops every registered player except [owner].
  Future<void> claim(Object owner) => _stopWhere((o) => !identical(o, owner));

  /// Stops every registered player (the mini-player's close button).
  Future<void> stopAll() => _stopWhere((_) => true);

  Future<void> _stopWhere(bool Function(Object owner) test) async {
    // Copy first: a stop can dispose its player, which unregisters it.
    final stops = [
      for (final e in _players.entries)
        if (test(e.key)) e.value,
    ];
    for (final stop in stops) {
      try {
        await stop();
      } catch (e) {
        // One player failing to stop must not keep another from starting.
        debugPrint('AudioFocus: stop failed: $e');
      }
    }
  }
}

final audioFocusProvider = Provider<AudioFocus>((ref) => AudioFocus());
