import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/reciter_providers.dart';

/// Persistent floating mini-player that appears above the glass navigation bar
/// whenever a Quran reciter track is loaded.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    return GestureDetector(
      onTap: () => context.push('/quran/reciters/${activeReciter.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark.withValues(alpha: 0.88)
                    : Colors.white.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Content row ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        // Mic icon
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.mic_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),

                        // Track info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeSurah.surahArabicName,
                                style: GoogleFonts.scheherazadeNew(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.textDark
                                      : AppColors.textLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                activeReciter.displayName,
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Play / Pause
                        _MiniPlayerButton(
                          icon: isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          semanticLabel: isPlaying ? 'Pause' : 'Play',
                          onTap: () {
                            final service = ref.read(quranAudioServiceProvider);
                            isPlaying ? service.pause() : service.resume();
                          },
                        ),
                      ],
                    ),
                  ),

                  // ── Progress bar ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      0,
                      AppSpacing.sm,
                      AppSpacing.xs,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.12),
                        color: AppColors.primary,
                        minHeight: 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPlayerButton extends StatelessWidget {
  const _MiniPlayerButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
      ),
    );
  }
}
