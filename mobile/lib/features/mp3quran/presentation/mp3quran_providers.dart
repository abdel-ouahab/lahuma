import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/audio/audio_focus.dart';
import '../../../core/utils/arabic_text.dart';
import '../data/mp3quran_api.dart';
import '../data/player_backdrop_repository.dart';
import '../data/reciter_favorites_repository.dart';
import '../data/reciter_photos_api.dart';
import '../data/surah_download_store.dart';
import '../domain/mp3quran_models.dart';
import '../domain/player_backdrop.dart';
import '../domain/reciter_photos.dart';

final mp3QuranApiProvider =
    Provider<Mp3QuranApi>((ref) => Mp3QuranApi(null, Mp3QuranCache()));

final mp3RecitersProvider = FutureProvider<List<Mp3Reciter>>(
  (ref) => ref.watch(mp3QuranApiProvider).fetchReciters(),
);

/// Surah id → Arabic name. Failure is non-fatal for playback: callers fall
/// back to "سورة N".
final mp3SuwarProvider = FutureProvider<Map<int, String>>((ref) async {
  final list = await ref.watch(mp3QuranApiProvider).fetchSuwar();
  return {for (final s in list) s.id: s.name};
});

final reciterPhotosApiProvider =
    Provider<ReciterPhotosApi>((ref) => ReciterPhotosApi());

/// Portraits for the reciters list. Optional: on failure every reciter
/// shows a monogram.
final reciterPhotosProvider = FutureProvider<ReciterPhotos>((ref) async {
  try {
    return await ref.watch(reciterPhotosApiProvider).fetch();
  } catch (_) {
    return ReciterPhotos.empty;
  }
});

final mp3RecitersSearchProvider = StateProvider.autoDispose<String>((_) => '');

List<Mp3Reciter> filterReciters(List<Mp3Reciter> all, String query) {
  final q = normalizeArabic(query);
  if (q.isEmpty) return all;
  return all.where((r) => normalizeArabic(r.name).contains(q)).toList();
}

/// Moves [favorites] to the top, keeping the API order within each group.
List<Mp3Reciter> sortFavoritesFirst(List<Mp3Reciter> list, Set<int> favorites) {
  if (favorites.isEmpty) return list;
  return [
    ...list.where((r) => favorites.contains(r.id)),
    ...list.where((r) => !favorites.contains(r.id)),
  ];
}

// ── Favourites ──────────────────────────────────────────────────────────────

final reciterFavoritesRepositoryProvider =
    Provider((ref) => ReciterFavoritesRepository());

class ReciterFavoritesNotifier extends StateNotifier<Set<int>> {
  ReciterFavoritesNotifier(this._repository) : super(const {}) {
    _load();
  }

  final ReciterFavoritesRepository _repository;
  bool _touched = false;

  Future<void> _load() async {
    final saved = await _repository.load();
    // A toggle made before loading finished already saved the full set.
    if (!_touched && mounted) state = saved;
  }

  /// Adds or removes [reciter]; returns true when it is now a favourite.
  bool toggle(Mp3Reciter reciter) {
    _touched = true;
    final next = Set<int>.from(state);
    final added = next.add(reciter.id);
    if (!added) next.remove(reciter.id);
    state = next;
    _repository.save(next);
    return added;
  }
}

final reciterFavoritesProvider =
    StateNotifierProvider<ReciterFavoritesNotifier, Set<int>>((ref) {
  return ReciterFavoritesNotifier(
      ref.watch(reciterFavoritesRepositoryProvider));
});

// ── Now Playing background ──────────────────────────────────────────────────

final playerBackdropRepositoryProvider =
    Provider((ref) => PlayerBackdropRepository());

class PlayerBackdropNotifier extends StateNotifier<PlayerBackdrop> {
  PlayerBackdropNotifier(this._repository) : super(PlayerBackdrop.none) {
    _load();
  }

  final PlayerBackdropRepository _repository;
  bool _touched = false;

  Future<void> _load() async {
    final saved = await _repository.load();
    // A pick made before loading finished wins over the stored one.
    if (!_touched && mounted) state = saved;
  }

  void select(PlayerBackdrop backdrop) {
    _touched = true;
    if (backdrop == state) return;
    state = backdrop;
    _repository.save(backdrop);
  }
}

final playerBackdropProvider =
    StateNotifierProvider<PlayerBackdropNotifier, PlayerBackdrop>((ref) {
  return PlayerBackdropNotifier(ref.watch(playerBackdropRepositoryProvider));
});

// ── Downloads ───────────────────────────────────────────────────────────────

final surahDownloadStoreProvider = Provider((ref) => SurahDownloadStore());

class SurahDownloadsState {
  const SurahDownloadsState({
    this.saved = const {},
    this.progress = const {},
    this.queued = const {},
    this.failed = const {},
  });

  /// Saved surahs, by [SurahDownloadStore.editionKey].
  final Map<String, Set<int>> saved;

  /// The surah downloading now, 0…1, by [_id].
  final Map<String, double> progress;

  /// Waiting their turn, by [_id].
  final Set<String> queued;

  /// The last attempt failed, by [_id].
  final Set<String> failed;

  static String _id(Mp3Moshaf m, int surah) =>
      '${SurahDownloadStore.editionKey(m)}/$surah';

  Set<int> savedIn(Mp3Moshaf m) =>
      saved[SurahDownloadStore.editionKey(m)] ?? const {};
  bool isSaved(Mp3Moshaf m, int surah) => savedIn(m).contains(surah);
  double? progressOf(Mp3Moshaf m, int surah) => progress[_id(m, surah)];
  bool isQueued(Mp3Moshaf m, int surah) => queued.contains(_id(m, surah));
  bool hasFailed(Mp3Moshaf m, int surah) => failed.contains(_id(m, surah));

  /// Any of [m]'s surahs is downloading or waiting.
  bool busyIn(Mp3Moshaf m) {
    final prefix = '${SurahDownloadStore.editionKey(m)}/';
    return progress.keys.any((k) => k.startsWith(prefix)) ||
        queued.any((k) => k.startsWith(prefix));
  }

  SurahDownloadsState copyWith({
    Map<String, Set<int>>? saved,
    Map<String, double>? progress,
    Set<String>? queued,
    Set<String>? failed,
  }) =>
      SurahDownloadsState(
        saved: saved ?? this.saved,
        progress: progress ?? this.progress,
        queued: queued ?? this.queued,
        failed: failed ?? this.failed,
      );
}

/// Saves surahs for offline listening, one at a time, in the order asked.
/// App-wide, so downloads go on after leaving the reciter's page.
class SurahDownloadsNotifier extends StateNotifier<SurahDownloadsState> {
  SurahDownloadsNotifier(this._store) : super(const SurahDownloadsState()) {
    ready = _load();
  }

  final SurahDownloadStore _store;
  late final Future<void> ready;
  final _queue = <(Mp3Moshaf, int)>[];
  (Mp3Moshaf, int)? _current;
  CancelToken? _cancel;

  Future<void> _load() async {
    final saved = await _store.scan();
    if (mounted) state = state.copyWith(saved: saved);
  }

  static String _id(Mp3Moshaf m, int s) => SurahDownloadsState._id(m, s);

  /// Queues [surah] (no-op when saved, waiting or downloading).
  void download(Mp3Moshaf moshaf, int surah) {
    final id = _id(moshaf, surah);
    if (state.isSaved(moshaf, surah) ||
        state.queued.contains(id) ||
        state.progress.containsKey(id) ||
        !moshaf.hasSurah(surah)) {
      return;
    }
    _queue.add((moshaf, surah));
    state = state.copyWith(
      queued: {...state.queued, id},
      failed: {...state.failed}..remove(id),
    );
    _pump();
  }

  /// Queues every surah of [moshaf] not saved yet.
  void downloadAll(Mp3Moshaf moshaf) {
    for (final s in moshaf.surahNumbers) {
      download(moshaf, s);
    }
  }

  /// Stops [surah]'s download, or takes it out of the queue.
  void cancel(Mp3Moshaf moshaf, int surah) {
    final id = _id(moshaf, surah);
    _queue.removeWhere((e) => _id(e.$1, e.$2) == id);
    if (_current != null && _id(_current!.$1, _current!.$2) == id) {
      _cancel?.cancel();
    }
    state = state.copyWith(queued: {...state.queued}..remove(id));
  }

  /// Stops and unqueues every download of [moshaf].
  void cancelAll(Mp3Moshaf moshaf) {
    final key = SurahDownloadStore.editionKey(moshaf);
    _queue.removeWhere((e) => SurahDownloadStore.editionKey(e.$1) == key);
    if (_current != null &&
        SurahDownloadStore.editionKey(_current!.$1) == key) {
      _cancel?.cancel();
    }
    state = state.copyWith(
        queued: state.queued.where((k) => !k.startsWith('$key/')).toSet());
  }

  Future<void> delete(Mp3Moshaf moshaf, int surah) async {
    cancel(moshaf, surah);
    await _store.delete(moshaf, surah);
    _setSaved(moshaf, (s) => s..remove(surah));
  }

  Future<void> deleteAll(Mp3Moshaf moshaf) async {
    cancelAll(moshaf);
    await _store.deleteAll(moshaf);
    _setSaved(moshaf, (s) => s..clear());
  }

  Future<int> sizeOf(Mp3Moshaf moshaf) => _store.sizeOf(moshaf);

  void _setSaved(Mp3Moshaf moshaf, Set<int> Function(Set<int>) edit) {
    if (!mounted) return;
    final key = SurahDownloadStore.editionKey(moshaf);
    final next = edit({...state.savedIn(moshaf)});
    state = state.copyWith(
        saved: {
      ...state.saved,
      key: next,
    }..removeWhere((_, v) => v.isEmpty));
  }

  bool _running = false;

  /// Works through the queue, one surah at a time. Set before any await, so
  /// several taps in a row never start two downloads at once.
  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      await ready;
      while (_queue.isNotEmpty && mounted) {
        await _downloadOne(_queue.removeAt(0));
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _downloadOne((Mp3Moshaf, int) item) async {
    final (moshaf, surah) = _current = item;
    final id = _id(moshaf, surah);
    final cancel = _cancel = CancelToken();
    state = state.copyWith(
      queued: {...state.queued}..remove(id),
      progress: {...state.progress, id: 0},
    );
    try {
      await _store.download(moshaf, surah, cancel: cancel, onProgress: (p) {
        if (mounted) {
          state = state.copyWith(progress: {...state.progress, id: p});
        }
      });
      _setSaved(moshaf, (s) => s..add(surah));
    } catch (e) {
      debugPrint('Recitation download failed: $e');
      final cancelled = e is DioException && CancelToken.isCancel(e);
      if (mounted && !cancelled) {
        // Offline or the server is down: the rest of this edition would fail
        // the same way, so they wait for the user to try again.
        cancelAll(moshaf);
        state = state.copyWith(failed: {...state.failed, id});
      }
    } finally {
      _current = null;
      _cancel = null;
      if (mounted) {
        state = state.copyWith(progress: {...state.progress}..remove(id));
      }
    }
  }

  @override
  void dispose() {
    _queue.clear();
    _cancel?.cancel();
    super.dispose();
  }
}

final surahDownloadsProvider =
    StateNotifierProvider<SurahDownloadsNotifier, SurahDownloadsState>(
        (ref) => SurahDownloadsNotifier(ref.watch(surahDownloadStoreProvider)));

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
  Mp3PlaybackController(this._moshaf, {this.beforePlay, this.localFile})
      : super(const Mp3PlaybackState()) {
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

  /// Runs before playback starts or resumes; the provider uses it to claim
  /// audio focus so the app's other players stop.
  final Future<void> Function()? beforePlay;

  /// The surah's file on the device, if it was downloaded; played instead
  /// of the stream, so it works offline.
  final Future<String?> Function(int surah)? localFile;

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
    await beforePlay?.call();
    if (token != _token) return;
    try {
      await player.stop();
      final file = await localFile?.call(surah);
      if (token != _token) return;
      if (file != null) {
        await player.setFilePath(file);
      } else {
        await player.setUrl(url);
      }
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
      await beforePlay?.call();
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      unawaited(player.play());
    }
  }

  /// Stops playback and forgets the current surah (another player took over,
  /// or the mini-player was closed).
  Future<void> stop() async {
    if (!mounted) return;
    _token++;
    state = const Mp3PlaybackState();
    await player.stop();
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
    final focus = ref.read(audioFocusProvider);
    late final Mp3PlaybackController controller;
    final store = ref.read(surahDownloadStoreProvider);
    controller = Mp3PlaybackController(
      moshaf,
      beforePlay: () => focus.claim(controller),
      localFile: (surah) => store.fileFor(moshaf, surah),
    );
    // Another player took over: stop, and end the session so the mini-player
    // goes away (and, unless the player screen is open, the controller too).
    focus.register(controller, () async {
      await controller.stop();
      if (ref.read(mp3SessionProvider)?.moshaf == moshaf) {
        ref.read(mp3SessionProvider.notifier).state = null;
      }
    });
    ref.onDispose(() => focus.unregister(controller));
    return controller;
  },
);
