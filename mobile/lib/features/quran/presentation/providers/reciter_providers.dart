import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/network/api_client.dart';
import '../../data/reciter_local_data_source.dart';
import '../../data/reciter_repository_impl.dart';
import '../../domain/reciter.dart';
import '../../domain/reciter_repository.dart';
import '../../domain/surah_audio.dart';
import '../../services/quran_audio_service.dart';

// ── Repository ───────────────────────────────────────────────────────────────

final reciterDataSourceProvider = Provider<ReciterLocalDataSource>(
  (ref) => ReciterLocalDataSource(ApiClient()),
);

final reciterRepositoryProvider = Provider<ReciterRepository>((ref) {
  return ReciterRepositoryImpl(ref.watch(reciterDataSourceProvider));
});

// ── Data ─────────────────────────────────────────────────────────────────────

final reciterListProvider = FutureProvider<List<Reciter>>((ref) async {
  return ref.watch(reciterRepositoryProvider).getReciters();
});

final surahsForReciterProvider =
    FutureProvider.family<List<SurahAudio>, Reciter>((ref, reciter) async {
  return ref.watch(reciterRepositoryProvider).getAvailableSurahs(reciter);
});

// ── Audio service (singleton — outlives individual screens) ──────────────────

final quranAudioServiceProvider = Provider<QuranAudioService>((ref) {
  final service = QuranAudioService();
  ref.onDispose(service.dispose);
  return service;
});

// ── Player state ─────────────────────────────────────────────────────────────

/// Broadcasts just_audio PlayerState changes (playing, paused, completed…)
final audioPlayerStateProvider = StreamProvider<PlayerState>((ref) {
  return ref.watch(quranAudioServiceProvider).playerStateStream;
});

/// Broadcasts current playback position in real-time.
final audioPositionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(quranAudioServiceProvider).positionStream;
});

/// Broadcasts total duration (null until loaded).
final audioDurationProvider = StreamProvider<Duration?>((ref) {
  return ref.watch(quranAudioServiceProvider).durationStream;
});

// ── Active track context ──────────────────────────────────────────────────────

/// Currently loaded reciter (null when nothing is playing).
final activeReciterProvider = StateProvider<Reciter?>((ref) => null);

/// Currently loaded surah (null when nothing is playing).
final activeSurahAudioProvider = StateProvider<SurahAudio?>((ref) => null);
