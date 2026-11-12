import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/audio/audio_focus.dart';
import '../../domain/ayah.dart';
import '../../domain/surah_detail.dart';

/// Which ayah is being recited right now.
class AyahPlayback {
  const AyahPlayback({
    required this.surah,
    required this.surahName,
    required this.totalAyahs,
    required this.ayah,
    required this.playing,
  });

  final int surah;

  /// Arabic name of the surah, for the mini-player.
  final String surahName;
  final int totalAyahs;
  final int ayah;
  final bool playing;

  AyahPlayback copyWith({int? ayah, bool? playing}) => AyahPlayback(
        surah: surah,
        surahName: surahName,
        totalAyahs: totalAyahs,
        ayah: ayah ?? this.ayah,
        playing: playing ?? this.playing,
      );
}

/// Plays a surah ayah by ayah from the reader, continuing to the end of the
/// surah. Separate from the reciter players; [AudioFocus] stops them when
/// this one starts, and stops this one when they start. Playback carries on
/// after the reader is closed, with the shell's mini-player as its control.
class AyahAudioNotifier extends StateNotifier<AyahPlayback?> {
  AyahAudioNotifier(Ref ref)
      : _focus = ref.read(audioFocusProvider),
        super(null) {
    _focus.register(this, stop);
  }

  static const String _reciterPath = 'ar.alafasy';
  static const String reciterNameAr = 'مشاري العفاسي';
  static const String reciterNameEn = 'Mishary Alafasy';

  final AudioFocus _focus;
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

    await _focus.claim(this);

    final player = _player ??= _createPlayer();
    _queue = queue;
    state = AyahPlayback(
      surah: detail.number,
      surahName: detail.arabicName,
      totalAyahs: detail.numberOfAyahs,
      ayah: queue.first.numberInSurah,
      playing: true,
    );

    try {
      await player.setAudioSources([
        for (final a in queue) AudioSource.uri(Uri.parse(urlFor(a.number))),
      ]);
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
    if (player == null || state == null) return;
    await _focus.claim(this);
    unawaited(player.play());
  }

  Future<void> stop() async {
    await _player?.stop();
    state = null;
  }

  @override
  void dispose() {
    _focus.unregister(this);
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
