import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/glass_navigation_bar.dart';
import '../../domain/reciter.dart';
import '../providers/reciter_providers.dart';
import 'reciter_card.dart';

/// Renders the list of Quran reciters. Lives inside the القرّاء tab of
/// [SurahListScreen].
class ReciterListView extends ConsumerWidget {
  const ReciterListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recitersAsync = ref.watch(reciterListProvider);
    final activeReciter = ref.watch(activeReciterProvider);
    final playerStateAsync = ref.watch(audioPlayerStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isPlaying = playerStateAsync.when(
      data: (state) => state.playing,
      loading: () => false,
      error: (_, __) => false,
    );

    return recitersAsync.when(
      data: (reciters) {
        if (reciters.isEmpty) {
          return _EmptyState(isDark: isDark);
        }
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            GlassNavigationBar.totalHeight(context) + AppSpacing.md,
          ),
          itemCount: reciters.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final reciter = reciters[index];
            final isActive = activeReciter?.id == reciter.id;
            return ReciterCard(
              reciter: reciter,
              isActive: isActive,
              isPlaying: isActive && isPlaying,
              onTap: () => _onReciterTap(context, ref, reciter),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48,
                  color: isDark ? AppColors.mutedDark : AppColors.mutedLight),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.tr('تعذّر تحميل القرّاء', 'Could not load reciters'),
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color:
                      isDark ? AppColors.subtextDark : AppColors.subtextLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onReciterTap(BuildContext context, WidgetRef ref, Reciter reciter) {
    // Navigate to the player; the player will load surahs for this reciter.
    context.push('/quran/reciters/${reciter.id}');
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? AppColors.surfaceElevatedDark
                    : AppColors.primaryContainer,
              ),
              child: Icon(
                Icons.mic_off_rounded,
                size: 36,
                color: isDark ? AppColors.mutedDark : AppColors.inkMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.tr('لا يوجد قرّاء حالياً', 'No reciters yet'),
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textDark : AppColors.textLight,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.tr('سيتم إضافة ملفات التلاوة قريباً', 'Recitations will be added soon'),
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: isDark ? AppColors.subtextDark : AppColors.subtextLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
