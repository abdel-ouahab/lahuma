import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../localization/tr.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';

/// Hero "Continue Reading" card on the Home screen.
/// One idea: where you left off, and a single obvious way back in.
/// [progressPercent] is null when it isn't known.
class ContinueReadingCard extends StatelessWidget {
  const ContinueReadingCard({
    super.key,
    this.surahName,
    this.ayahNumber,
    this.progressPercent,
    this.onTap,
  });

  final String? surahName;
  final int? ayahNumber;
  final double? progressPercent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasProgress = surahName != null;
    const onHero = Colors.white;
    final onHeroDim = Colors.white.withValues(alpha: 0.72);

    return LahumaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      gradient: const LinearGradient(
        colors: AppColors.heroGradient,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 0.5),
      shadow: [
        BoxShadow(
          color: AppColors.primaryDark.withValues(alpha: 0.28),
          blurRadius: 30,
          spreadRadius: -6,
          offset: const Offset(0, 14),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                hasProgress
                    ? context.tr('آخر قراءة', 'Last read')
                    : context.tr('ابدأ القراءة', 'Start reading'),
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: onHeroDim,
                ),
              ),
              const Spacer(),
              if (progressPercent != null)
                Text(
                  '${progressPercent!.toInt()}%',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: onHeroDim,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hasProgress ? surahName! : context.tr('القرآن الكريم', 'The Holy Quran'),
            style: GoogleFonts.scheherazadeNew(
              fontSize: 34,
              height: 1.3,
              color: onHero,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hasProgress)
            Text(
              context.tr('الآية ${ayahNumber ?? 1}', 'Ayah ${ayahNumber ?? 1}'),
              style: GoogleFonts.cairo(fontSize: 14, color: onHeroDim),
            ),
          const SizedBox(height: AppSpacing.lg),
          if (progressPercent != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progressPercent! / 100),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  valueColor: const AlwaysStoppedAnimation<Color>(onHero),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Single clear action: a white pill, the card's only bright element.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow_rounded,
                    size: 18, color: AppColors.primaryDark),
                const SizedBox(width: 6),
                Text(
                  hasProgress
                      ? context.tr('متابعة القراءة', 'Continue')
                      : context.tr('ابدأ الآن', 'Begin'),
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
