import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../domain/ayah.dart';
import '../../domain/surah_detail.dart';
import 'reciter_providers.dart';

/// Which ayah is being recited right now.
class AyahPlayback {
  const AyahPlayback({
    required this.surah,
    required this.ayah,
    required this.playing,
  });

  final int surah;
  final int ayah;
  final bool playing;

  AyahPlayback copyWith({int? ayah, bool? playing}) => AyahPlayback(
        surah: surah,
        ayah: ayah ?? this.ayah,
        playing: playing ?? this.playing,
      );
}

/// Plays a surah ayah by ayah from the reader, continuing to the end of the
/// surah. Separate from [QuranAudioService], which plays full-surah files
/// for the reciters tab; starting one pauses the other.
class AyahAudioNotifier extends StateNotifier<AyahPlayback?> {
  AyahAudioNotifier(this._ref) : super(null);

  static const String _reciterPath = 'ar.alafasy';

  final Ref _ref;
  AudioPlayer? _player;
  List<Ayah> _queue = const [];
  StreamSubscription<int?>? _indexSub;
  StreamSubscription<PlayerState>? _stateSub;

  static String urlFor(int globalAyahNumber) =>
      'https://cdn.islamic.network/quran/audio/128/$_reciterPath/$globalAyahNumber.mp3';

  /// Plays [detail] starting at [fromAyah]. Throws if the audio can't load.
  Future<void> playFrom(SurahDetail detail, int fromAyah) async {
    final queue = detail.ayahs
        .where((a) => a.numberInSurah >= fromAyah && a.number > 0)
        .toList();
    if (queue.isEmpty) return;

    await _ref.read(quranAudioServiceProvider).pause();

    final player = _player ??= _createPlayer();
    _queue = queue;
    state = AyahPlayback(
      surah: detail.number,
      ayah: queue.first.numberInSurah,
      playing: true,
    );

    try {
      await player.setAudioSource(
        ConcatenatingAudioSource(
          children: [
            for (final a in queue) AudioSource.uri(Uri.parse(urlFor(a.number))),
          ],
        ),
      );
      unawaited(player.play());
    } catch (e) {
      state = null;
      rethrow;
    }
  }

  AudioPlayer _createPlayer() {
    final player = AudioPlayer();
    _indexSub = player.currentIndexStream.listen((index) {
      final current = state;
      if (current == null || index == null || index >= _queue.length) return;
      state = current.copyWith(ayah: _queue[index].numberInSurah);
    });
    _stateSub = player.playerStateStream.listen((s) {
      final current = state;
      if (current == null) return;
      if (s.processingState == ProcessingState.completed) {
        state = null;
      } else if (current.playing != s.playing) {
        state = current.copyWith(playing: s.playing);
      }
    });
    return player;
  }

  Future<void> pause() async => _player?.pause();

  Future<void> resume() async {
    final player = _player;
    if (player != null) unawaited(player.play());
  }

  Future<void> stop() async {
    await _player?.stop();
    state = null;
  }

  @override
  void dispose() {
    _indexSub?.cancel();
    _stateSub?.cancel();
    _player?.dispose();
    super.dispose();
  }
}

final ayahAudioProvider =
    StateNotifierProvider<AyahAudioNotifier, AyahPlayback?>((ref) {
  return AyahAudioNotifier(ref);
});
