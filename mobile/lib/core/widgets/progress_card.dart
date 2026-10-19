import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/wird/data/wird_repository.dart';
import '../localization/tr.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';

/// Today's wird: ayahs read against the daily goal. Calm, not competitive —
/// the only streak shown is the one the reader has actually earned.
class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key, required this.wird, this.onTap});

  final WirdState wird;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = (wird.fraction * 100).toInt();
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    final message = wird.goalReached
        ? context.tr('أتممت وردك اليوم، تقبّل الله منك', 'You finished today\'s wird. May Allah accept it.')
        : wird.ayahsToday == 0
            ? context.tr('ابدأ وردك اليوم', 'Start today\'s wird')
            : context.tr(
                'بقي ${wird.goal - wird.ayahsToday} آية على هدفك',
                '${wird.goal - wird.ayahsToday} ayahs to reach your goal');

    return LahumaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: Semantics(
        label: context.tr(
          '${wird.ayahsToday} من ${wird.goal} آية اليوم. اضغط لتغيير الهدف.',
          '${wird.ayahsToday} of ${wird.goal} ayahs today. Tap to change the goal.',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wb_sunny_rounded,
                    size: 18, color: Color(0xFFFF9F0A)),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  context.tr('وردك اليوم', 'Today\'s wird'),
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  ),
                ),
                const Spacer(),
                Text(
                  context.tr('${wird.ayahsToday} / ${wird.goal} آية',
                      '${wird.ayahsToday} / ${wird.goal} ayahs'),
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.subtextDark : AppColors.subtextLight,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: wird.fraction),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    message,
                    style: GoogleFonts.cairo(fontSize: 12, color: subtext),
                  ),
                ),
                Text(
                  '$percent%',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            if (wird.streak >= 2) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      size: 16, color: Color(0xFFE08A33)),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    context.tr('${wird.streak} أيام متتالية', '${wird.streak}-day streak'),
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: subtext,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
