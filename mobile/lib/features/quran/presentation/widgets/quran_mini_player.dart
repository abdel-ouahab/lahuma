import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design.dart';
import '../providers/reciter_providers.dart';

/// Persistent mini-player that sits above the tab bar whenever a Quran
/// reciter track is loaded.
///
/// Tapping the mini-player navigates back to the full player screen.
class QuranMiniPlayer extends ConsumerWidget {
  const QuranMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeReciter = ref.watch(activeReciterProvider);
    final activeSurah = ref.watch(activeSurahAudioProvider);

    // Only render when something is loaded
    if (activeReciter == null || activeSurah == null) {
      return const SizedBox.shrink();
    }

    final playerStateAsync = ref.watch(audioPlayerStateProvider);
    final positionAsync = ref.watch(audioPositionProvider);
    final durationAsync = ref.watch(audioDurationProvider);

    final isPlaying = playerStateAsync.maybeWhen(
      data: (s) => s.playing,
      orElse: () => false,
    );

    final position = positionAsync.maybeWhen(
      data: (d) => d,
      orElse: () => Duration.zero,
    );

    final duration = durationAsync.maybeWhen(
      data: (d) => d ?? Duration.zero,
      orElse: () => Duration.zero,
    );

    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return AppMiniPlayerBar(
      artwork: const AppArtworkTile(icon: CupertinoIcons.mic_fill),
      title: activeSurah.surahArabicName,
      titleStyle:
          AppTypography.quran(size: 17, weight: FontWeight.w700, height: 1.3)
              .copyWith(color: context.palette.label),
      subtitle: activeReciter.displayName,
      playing: isPlaying,
      progress: progress,
      onTap: () => context.push('/quran/reciters/${activeReciter.id}'),
      onTogglePlay: () {
        final service = ref.read(quranAudioServiceProvider);
        isPlaying ? service.pause() : service.resume();
      },
    );
  }
}
