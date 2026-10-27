import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/audio/audio_focus.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../providers/ayah_audio_provider.dart';

/// Mini-player for the reader's ayah-by-ayah recitation, shown above the tab
/// bar once the reader is closed while it is still playing (or paused).
///
/// Tapping it reopens the reader at the ayah being recited.
class AyahMiniPlayer extends ConsumerWidget {
  const AyahMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(ayahAudioProvider);
    if (playback == null) return const SizedBox.shrink();

    final audio = ref.read(ayahAudioProvider.notifier);
    final reciter = context.tr(
        AyahAudioNotifier.reciterNameAr, AyahAudioNotifier.reciterNameEn);

    return AppMiniPlayerBar(
      artwork: const AppArtworkTile(icon: CupertinoIcons.book_fill),
      title: playback.surahName,
      titleStyle:
          AppTypography.quran(size: 17, weight: FontWeight.w700, height: 1.3)
              .copyWith(color: context.palette.label),
      subtitle: context.tr(
        'الآية ${playback.ayah} · $reciter',
        'Ayah ${playback.ayah} · $reciter',
      ),
      playing: playback.playing,
      progress: playback.totalAyahs > 0
          ? playback.ayah / playback.totalAyahs
          : null,
      onTap: () =>
          context.push('/quran/${playback.surah}?ayah=${playback.ayah}'),
      onTogglePlay: playback.playing ? audio.pause : audio.resume,
      onClose: () => ref.read(audioFocusProvider).stopAll(),
    );
  }
}
