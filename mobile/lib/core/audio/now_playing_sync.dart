import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../features/mp3quran/presentation/mp3quran_providers.dart';
import '../../features/quran/presentation/providers/reciter_providers.dart';
import '../../features/quran/services/quran_audio_service.dart';
import '../design/widgets/app_overlays.dart';
import '../localization/tr.dart';
import 'audio_focus.dart';
import 'now_playing.dart';

/// Keeps the system's Now Playing card (lock screen, notification shade,
/// Control Centre) on the surah the mini player shows. Lives in the tab
/// shell next to the mini player and draws nothing.
class NowPlayingSync extends ConsumerStatefulWidget {
  const NowPlayingSync({super.key});

  @override
  ConsumerState<NowPlayingSync> createState() => _NowPlayingSyncState();
}

class _NowPlayingSyncState extends ConsumerState<NowPlayingSync> {
  Uri? _fallbackArt;

  /// The last recitation checked for a silent phone, so it's said once.
  String? _checkedId;

  /// A recitation that starts with the phone's media volume at zero is
  /// silent through no fault of the app; say so instead of leaving the
  /// listener to think it's broken. Android only: iOS has no such reading.
  Future<void> _warnIfSilent(String id) async {
    if (_checkedId == id || !Platform.isAndroid) return;
    _checkedId = id;
    try {
      final volume =
          await AndroidAudioManager().getStreamVolume(AndroidStreamType.music);
      if (volume > 0 || !mounted) return;
      AppToast.show(
        context,
        context.tr('صوت الوسائط على الصفر، ارفعه لتسمع التلاوة',
            'Media volume is at zero. Turn it up to hear the recitation'),
        icon: CupertinoIcons.speaker_slash_fill,
        duration: const Duration(seconds: 5),
      );
    } catch (_) {
      // No reading on this device: say nothing.
    }
  }

  @override
  void initState() {
    super.initState();
    nowPlayingFallbackArt().then((uri) {
      if (mounted && uri != null) setState(() => _fallbackArt = uri);
    });
  }

  @override
  Widget build(BuildContext context) {
    final handler = ref.watch(nowPlayingProvider);
    final focus = ref.read(audioFocusProvider);
    void Function()? update;

    // MP3Quran reciters.
    final session = ref.watch(mp3SessionProvider);
    final mp3 =
        session == null ? null : ref.watch(mp3PlaybackProvider(session.moshaf));
    if (session != null && mp3?.surah != null) {
      final controller = ref.read(mp3PlaybackProvider(session.moshaf).notifier);
      final surah = mp3!.surah!;
      final names = ref.watch(mp3SuwarProvider).valueOrNull ?? const {};
      final photo = ref
          .watch(reciterPhotosProvider)
          .valueOrNull
          ?.urlFor(session.reciter.name);
      final item = MediaItem(
        id: 'mp3/${session.moshaf.id}/$surah',
        title: names[surah] ?? 'سورة $surah',
        artist: session.reciter.name,
        album: session.moshaf.name,
        artUri: photo == null ? _fallbackArt : Uri.tryParse(photo),
      );
      final source = _Mp3Source(controller, focus);
      update = () {
        handler.show(source, item);
        _warnIfSilent(item.id);
      };
    } else {
      // The app's own reciters.
      final reciter = ref.watch(activeReciterProvider);
      final surah = ref.watch(activeSurahAudioProvider);
      if (reciter != null && surah != null) {
        final service = ref.read(quranAudioServiceProvider);
        // Rebuild on play / pause so the card's button follows.
        ref.watch(audioPlayerStateProvider);
        final item = MediaItem(
          id: 'lahuma/${reciter.id}/${surah.surahNumber}',
          title: surah.surahArabicName,
          artist: reciter.displayName,
          artUri: _fallbackArt,
        );
        final source = _LahumaSource(service, focus);
        update = () {
          handler.show(source, item);
          _warnIfSilent(item.id);
        };
      }
    }

    // After the frame: the session is a side effect, not part of the build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (update != null) {
        update();
      } else {
        handler.clearAll();
        _checkedId = null;
      }
    });
    return const SizedBox.shrink();
  }
}

class _Mp3Source implements NowPlayingSource {
  _Mp3Source(this._controller, this._focus);

  final Mp3PlaybackController _controller;
  final AudioFocus _focus;

  @override
  AudioPlayer get player => _controller.player;

  @override
  bool get hasNext => _controller.hasNext;

  @override
  bool get hasPrevious => _controller.hasPrevious;

  @override
  Future<void> play() async {
    if (!player.playing) await _controller.togglePlay();
  }

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> skipToNext() => _controller.next();

  @override
  Future<void> skipToPrevious() => _controller.previous();

  @override
  Future<void> stop() => _focus.stopAll();
}

class _LahumaSource implements NowPlayingSource {
  _LahumaSource(this._service, this._focus);

  final QuranAudioService _service;
  final AudioFocus _focus;

  @override
  AudioPlayer get player => _service.player;

  // One surah at a time: the reciter's page picks the next.
  @override
  bool get hasNext => false;

  @override
  bool get hasPrevious => false;

  @override
  Future<void> play() => _service.resume();

  @override
  Future<void> pause() => _service.pause();

  @override
  Future<void> skipToNext() async {}

  @override
  Future<void> skipToPrevious() async {}

  @override
  Future<void> stop() => _focus.stopAll();
}
