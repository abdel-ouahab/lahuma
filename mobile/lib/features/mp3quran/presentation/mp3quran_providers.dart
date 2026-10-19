import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../quran/presentation/providers/reciter_providers.dart';
import '../data/mp3quran_api.dart';
import '../domain/mp3quran_models.dart';

final mp3QuranApiProvider = Provider<Mp3QuranApi>((ref) => Mp3QuranApi());

final mp3RecitersProvider = FutureProvider<List<Mp3Reciter>>(
  (ref) => ref.watch(mp3QuranApiProvider).fetchReciters(),
);

/// Surah id → Arabic name. Failure is non-fatal for playback: callers fall
/// back to "سورة N".
final mp3SuwarProvider = FutureProvider<Map<int, String>>((ref) async {
  final list = await ref.watch(mp3QuranApiProvider).fetchSuwar();
  return {for (final s in list) s.id: s.name};
});

final mp3RecitersSearchProvider = StateProvider.autoDispose<String>((_) => '');

/// Strips Arabic diacritics and unifies alef/yaa/taa-marbuta forms so that
/// searching "احمد" matches "أحمد".
String normalizeArabic(String s) {
  return s
      .replaceAll(RegExp('[ً-ٰٟـ]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .toLowerCase()
      .trim();
}

List<Mp3Reciter> filterReciters(List<Mp3Reciter> all, String query) {
  final q = normalizeArabic(query);
  if (q.isEmpty) return all;
  return all.where((r) => normalizeArabic(r.name).contains(q)).toList();
}

// ── Playback ────────────────────────────────────────────────────────────────

enum Mp3PlaybackStatus { idle, loading, ready, error }

class Mp3PlaybackState {
  const Mp3PlaybackState({
    this.surah,
    this.status = Mp3PlaybackStatus.idle,
    this.error,
  });

  final int? surah;
  final Mp3PlaybackStatus status;
  final String? error;
}

/// Owns a dedicated [AudioPlayer] for one reciter/Moshaf; auto-disposed (and
/// the player released) when the player screen is left.
class Mp3PlaybackController extends StateNotifier<Mp3PlaybackState> {
  Mp3PlaybackController(this._moshaf) : super(const Mp3PlaybackState()) {
    _completeSub = player.processingStateStream.listen((s) {
      if (s != ProcessingState.completed) return;
      final current = state.surah;
      if (repeat.value && current != null) {
        unawaited(playSurah(current));
      } else if (shuffle.value) {
        unawaited(playRandom());
      } else {
        unawaited(next());
      }
    });
  }

  final Mp3Moshaf _moshaf;
  final AudioPlayer player = AudioPlayer();
  late final StreamSubscription<ProcessingState> _completeSub;
  final _random = Random();
  int _token = 0;

  /// Play-order toggles surfaced by the Now Playing screen.
  final ValueNotifier<bool> shuffle = ValueNotifier(false);
  final ValueNotifier<bool> repeat = ValueNotifier(false);

  List<int> get available => _moshaf.surahNumbers;

  /// Plays a random surah (different from the current one when possible).
  Future<void> playRandom() async {
    if (available.isEmpty) return;
    final pool = available.length > 1
        ? available.where((s) => s != state.surah).toList()
        : available;
    await playSurah(pool[_random.nextInt(pool.length)]);
  }

  int? _neighbour(int offset) {
    final current = state.surah;
    if (current == null) return null;
    final i = available.indexOf(current) + offset;
    return (i >= 0 && i < available.length) ? available[i] : null;
  }

  bool get hasNext => _neighbour(1) != null;
  bool get hasPrevious => _neighbour(-1) != null;

  Future<void> playSurah(int surah) async {
    final url = _moshaf.audioUrlFor(surah);
    if (url == null) {
      state = Mp3PlaybackState(
          surah: surah, status: Mp3PlaybackStatus.error, error: 'unavailable');
      return;
    }
    final token = ++_token;
    state = Mp3PlaybackState(surah: surah, status: Mp3PlaybackStatus.loading);
    try {
      await player.stop();
      await player.setUrl(url);
      if (token != _token) return;
      state = Mp3PlaybackState(surah: surah, status: Mp3PlaybackStatus.ready);
      // play() completes only when playback ends/pauses; don't await it.
      unawaited(player.play());
    } catch (_) {
      if (token != _token) return;
      state = Mp3PlaybackState(
          surah: surah, status: Mp3PlaybackStatus.error, error: 'playback');
    }
  }

  Future<void> togglePlay() async {
    if (state.surah == null || state.status == Mp3PlaybackStatus.error) {
      final s = state.surah ?? (available.isEmpty ? null : available.first);
      if (s != null) await playSurah(s);
      return;
    }
    if (player.playing) {
      await player.pause();
    } else {
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      unawaited(player.play());
    }
  }

  Future<void> seek(Duration position) => player.seek(position);

  double _volumeBeforeMute = 1;

  /// Takes effect immediately and never interrupts playback. The player is
  /// reused for every surah, so the level carries over when switching.
  Future<void> setVolume(double volume) {
    final v = volume.clamp(0.0, 1.0);
    if (v > 0) _volumeBeforeMute = v;
    return player.setVolume(v);
  }

  Future<void> toggleMute() =>
      setVolume(player.volume > 0 ? 0 : _volumeBeforeMute);

  Future<void> next() async {
    final n = _neighbour(1);
    if (n != null) await playSurah(n);
  }

  Future<void> previous() async {
    final p = _neighbour(-1);
    if (p != null) await playSurah(p);
  }

  @override
  void dispose() {
    _token++;
    _completeSub.cancel();
    shuffle.dispose();
    repeat.dispose();
    player.dispose();
    super.dispose();
  }
}

/// The recitation currently owned by the app-wide mini player. While set, the
/// shell watches its [mp3PlaybackProvider], which keeps playback alive after
/// the player screen is left.
class Mp3Session extends Equatable {
  const Mp3Session(this.reciter, this.moshaf);

  final Mp3Reciter reciter;
  final Mp3Moshaf moshaf;

  @override
  List<Object?> get props => [reciter, moshaf];
}

final mp3SessionProvider = StateProvider<Mp3Session?>((_) => null);

final mp3PlaybackProvider = StateNotifierProvider.autoDispose
    .family<Mp3PlaybackController, Mp3PlaybackState, Mp3Moshaf>(
  (ref, moshaf) {
    // Only one audio source at a time: silence the app's other reciter player.
    unawaited(ref.read(quranAudioServiceProvider).stop());
    return Mp3PlaybackController(moshaf);
  },
);
