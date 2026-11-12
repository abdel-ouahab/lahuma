import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// A player that can be driven from the lock screen, the notification shade,
/// headphones and the car: the Lahuma reciters player and the MP3Quran
/// player each provide one.
abstract class NowPlayingSource {
  AudioPlayer get player;
  bool get hasNext;
  bool get hasPrevious;
  Future<void> play();
  Future<void> pause();
  Future<void> skipToNext();
  Future<void> skipToPrevious();

  /// Ends the recitation, as the mini player's close button does.
  Future<void> stop();
}

/// The app's one media session: Android's media notification and
/// lock-screen card, iOS's Now Playing (lock screen, Control Centre), and
/// the media buttons of headphones and cars.
///
/// Whichever recitation is on [show]s itself here; commands from the system
/// go back to it. Only one source at a time — `AudioFocus` already stops the
/// others when one starts.
class NowPlayingHandler extends BaseAudioHandler with SeekHandler {
  NowPlayingSource? _source;
  final List<StreamSubscription<Object?>> _subs = [];

  /// Shows [item] for [source], taking over from any other source. Calling
  /// it again with the same source only updates the item.
  void show(NowPlayingSource source, MediaItem item) {
    if (!identical(_source?.player, source.player)) {
      _detach();
      _source = source;
      final p = source.player;
      _subs
        ..add(p.playbackEventStream
            .listen((_) => _broadcast(), onError: (Object _, StackTrace __) {}))
        ..add(p.playingStream.listen((_) => _broadcast()))
        // The length arrives after loading; Android needs it for the bar.
        ..add(p.durationStream.listen((d) {
          final current = mediaItem.value;
          if (d != null && current != null && current.duration != d) {
            mediaItem.add(current.copyWith(duration: d));
          }
        }));
    } else {
      _source = source;
    }
    final known = source.player.duration;
    final current = mediaItem.value;
    if (current == null ||
        current.id != item.id ||
        current.title != item.title ||
        current.artist != item.artist ||
        current.artUri != item.artUri) {
      mediaItem.add(item.duration == null && known != null
          ? item.copyWith(duration: known)
          : item);
    }
    _broadcast();
  }

  /// Removes [source]'s card, if it is the one shown.
  void clear(NowPlayingSource source) {
    if (!identical(_source?.player, source.player)) return;
    _detach();
    mediaItem.add(null);
    playbackState.add(PlaybackState(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  /// Removes whatever is shown (nothing is playing any more).
  void clearAll() {
    final s = _source;
    if (s != null) clear(s);
  }

  void _detach() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _source = null;
  }

  void _broadcast() {
    final s = _source;
    if (s == null) return;
    final p = s.player;
    final playing = p.playing;
    final controls = [
      if (s.hasPrevious) MediaControl.skipToPrevious,
      playing ? MediaControl.pause : MediaControl.play,
      if (s.hasNext) MediaControl.skipToNext,
    ];
    playbackState.add(PlaybackState(
      controls: controls,
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      // Previous / play-pause / next all fit the compact view.
      androidCompactActionIndices: [
        for (var i = 0; i < controls.length; i++) i,
      ],
      processingState: switch (p.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: playing,
      updatePosition: p.position,
      bufferedPosition: p.bufferedPosition,
      speed: p.speed,
    ));
  }

  // ── Commands from the system ─────────────────────────────────────────────

  @override
  Future<void> play() async => _source?.play();

  @override
  Future<void> pause() async => _source?.pause();

  @override
  Future<void> seek(Duration position) async => _source?.player.seek(position);

  @override
  Future<void> skipToNext() async => _source?.skipToNext();

  @override
  Future<void> skipToPrevious() async => _source?.skipToPrevious();

  @override
  Future<void> stop() async {
    final s = _source;
    if (s == null) return;
    await s.stop();
    clear(s);
  }

  /// Swiping the app away from recents (Android) ends the recitation.
  @override
  Future<void> onTaskRemoved() => stop();
}

/// The media session. `main` replaces it with the one registered with the
/// system ([initNowPlaying]); tests get a handler that talks to nothing.
final nowPlayingProvider = Provider<NowPlayingHandler>((ref) {
  return NowPlayingHandler();
});

/// Registers [NowPlayingHandler] with the system. Falls back to an
/// unregistered handler if that fails, so playback never depends on it.
Future<NowPlayingHandler> initNowPlaying() async {
  try {
    // Recitations are spoken audio the listener chose: they keep playing
    // with the screen locked (iOS) and take audio focus (Android).
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
  } catch (e) {
    debugPrint('Audio session not configured: $e');
  }
  try {
    return await AudioService.init(
      builder: NowPlayingHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.lahuma.app.recitation',
        androidNotificationChannelName: 'Recitation',
        androidNotificationChannelDescription:
            'Controls for the surah being played',
        androidNotificationIcon: 'drawable/ic_stat_recitation',
        androidStopForegroundOnPause: true,
        // Tapping the notification opens the app where it was.
        androidResumeOnClick: true,
      ),
    );
  } catch (e) {
    debugPrint('Now Playing unavailable: $e');
    return NowPlayingHandler();
  }
}

/// Artwork for reciters without a portrait: the app's logo, copied once to a
/// file because the system can't read Flutter assets.
Future<Uri?> nowPlayingFallbackArt() => _fallbackArt ??= _copyFallbackArt();
Future<Uri?>? _fallbackArt;

Future<Uri?> _copyFallbackArt() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/now_playing_v1.png');
    if (!await file.exists()) {
      final data = await rootBundle.load('assets/images/now_playing.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return file.uri;
  } catch (e) {
    debugPrint('Now Playing artwork unavailable: $e');
    return null;
  }
}
