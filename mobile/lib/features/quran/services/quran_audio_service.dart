import 'dart:async';

import 'package:just_audio/just_audio.dart';
import '../domain/reciter.dart';
import '../domain/surah_audio.dart';

/// Wraps [AudioPlayer] from just_audio with Quran-domain semantics.
///
/// One instance is kept alive as a singleton via Riverpod so audio
/// continues across navigation. Dispose is called from the provider.
///
/// Architecture:
///   ReciterPlayerScreen / MiniPlayer
///         ↓
///   QuranAudioService  (this class)
///         ↓
///   just_audio AudioPlayer
///         ↓
///   Flutter asset  (assets/audio/…)
class QuranAudioService {
  QuranAudioService() : _player = AudioPlayer();

  final AudioPlayer _player;

  // ── Current context ──────────────────────────────────────────────────────
  Reciter? _currentReciter;
  SurahAudio? _currentSurah;

  Reciter? get currentReciter => _currentReciter;
  SurahAudio? get currentSurah => _currentSurah;

  // ── Streams (forwarded from just_audio) ─────────────────────────────────
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  // Convenience getters for current cached values
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  bool get isPlaying => _player.playing;

  // ── Playback control ─────────────────────────────────────────────────────

  /// Load and play audio for [surah] from [reciter].
  ///
  /// If the same reciter+surah is already loaded, just resumes or replays.
  Future<void> play(Reciter reciter, SurahAudio surah) async {
    final isSameTrack = _currentReciter?.id == reciter.id &&
        _currentSurah?.fileName == surah.fileName;

    if (isSameTrack) {
      // Already loaded — resume or replay from start if completed
      final state = _player.playerState;
      if (state.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      // just_audio's play() only completes when playback ends or pauses, so
      // don't await it or callers stay "loading" for the whole recitation.
      unawaited(_player.play());
      return;
    }

    // New track — stop current playback and load the asset
    await _player.stop();
    _currentReciter = reciter;
    _currentSurah = surah;

    final audioPath = reciter.audioPathForSurah(surah);
    if (audioPath.startsWith('http://') || audioPath.startsWith('https://')) {
      try {
        await _player.setUrl(audioPath);
      } catch (e) {
        final altUrl = audioPath.contains('10.0.2.2')
            ? audioPath.replaceAll('10.0.2.2', 'localhost')
            : audioPath.replaceAll('localhost', '10.0.2.2');
        await _player.setUrl(altUrl);
      }
    } else {
      try {
        await _player.setAsset(audioPath);
      } catch (e) {
        try {
          final encodedPath = Uri.encodeFull(audioPath);
          await _player.setAudioSource(
              AudioSource.uri(Uri.parse('asset:///$encodedPath')));
        } catch (_) {
          // Fallback to primary 001.mp3 asset
          final fallbackPath = '${reciter.audioBasePath}001.mp3';
          await _player.setAsset(fallbackPath);
        }
      }
    }
    unawaited(_player.play());
  }

  Future<void> pause() async => _player.pause();

  Future<void> resume() async => unawaited(_player.play());

  Future<void> stop() async {
    await _player.stop();
    _currentReciter = null;
    _currentSurah = null;
  }

  Future<void> seek(Duration position) async => _player.seek(position);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _player.dispose();
  }
}
