import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/audio/audio_focus.dart';
import '../data/adhan_scheduler.dart';

/// Bundled full-length fallback adhan (Flutter asset). There is no Fajr
/// recording yet, so Fajr plays the same one.
///
/// just_audio copies an asset to its cache the first time and keeps that
/// copy, so a new recording needs a new file name (bump the `_v` suffix).
String adhanDefaultAsset({required bool fajr}) =>
    'assets/audio/adhan/default_regular_v3.mp3';

/// What the adhan player is doing. [key] names what is loaded (a muezzin
/// id for a preview, or [AdhanScheduler.playRoute] for the full adhan).
class AdhanPlaybackState {
  const AdhanPlaybackState({
    this.key,
    this.loading = false,
    this.playing = false,
    this.failed = false,
  });

  final String? key;
  final bool loading;
  final bool playing;
  final bool failed;

  bool isActive(String k) => key == k && (loading || playing);
}

/// One player for the picker's previews and the full adhan opened from a
/// notification; it takes audio focus from the Quran players.
class AdhanPlayback extends StateNotifier<AdhanPlaybackState> {
  AdhanPlayback(
      {required Future<void> Function() beforePlay, AudioPlayer? player})
      : _beforePlay = beforePlay,
        _player = player ?? AudioPlayer(),
        super(const AdhanPlaybackState()) {
    _sub = _player.playerStateStream.listen((s) {
      if (!mounted) return;
      debugPrint('Adhan: player ${s.processingState.name}'
          '${s.playing ? ' playing' : ''} (${state.key})');
      if (s.processingState == ProcessingState.completed) {
        state = AdhanPlaybackState(key: state.key);
        return;
      }
      state = AdhanPlaybackState(
        key: state.key,
        loading: s.processingState == ProcessingState.loading ||
            s.processingState == ProcessingState.buffering,
        playing: s.playing,
      );
    });
    // A failure while playing (not while loading) only arrives here.
    _errors = _player.playbackEventStream.listen((_) {}, onError: (Object e) {
      debugPrint('Adhan: playback error: $e');
      if (mounted) state = AdhanPlaybackState(key: state.key, failed: true);
    });
  }

  final Future<void> Function() _beforePlay;
  final AudioPlayer _player;
  StreamSubscription<PlayerState>? _sub;
  StreamSubscription<PlaybackEvent>? _errors;

  /// Plays a local [file], else streams [url], else the bundled [asset].
  /// Tapping the same [key] again while it plays stops it.
  Future<void> toggle(String key,
      {String? file, String? url, String? asset}) async {
    if (state.isActive(key)) return stop();
    await play(key, file: file, url: url, asset: asset);
  }

  Future<void> play(String key,
      {String? file, String? url, String? asset}) async {
    await _beforePlay();
    state = AdhanPlaybackState(key: key, loading: true);
    try {
      await _player.stop();
      if (file != null) {
        await _player.setFilePath(file);
      } else if (url != null) {
        await _player.setUrl(url);
      } else {
        await _player.setAsset(asset!);
      }
      unawaited(_player.play());
    } catch (e) {
      debugPrint('Adhan: playback failed: $e');
      // A broken download still has the bundled adhan behind it.
      if (file != null && asset != null) {
        return play(key, asset: asset);
      }
      if (mounted) state = AdhanPlaybackState(key: key, failed: true);
    }
  }

  Future<void> stop() async {
    await _player.stop();
    if (mounted) state = AdhanPlaybackState(key: state.key);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _errors?.cancel();
    _player.dispose();
    super.dispose();
  }
}

final adhanPlaybackProvider =
    StateNotifierProvider.autoDispose<AdhanPlayback, AdhanPlaybackState>((ref) {
  final focus = ref.read(audioFocusProvider);
  late final AdhanPlayback playback;
  playback = AdhanPlayback(beforePlay: () => focus.claim(playback));
  focus.register(playback, playback.stop);
  ref.onDispose(() => focus.unregister(playback));
  return playback;
});
