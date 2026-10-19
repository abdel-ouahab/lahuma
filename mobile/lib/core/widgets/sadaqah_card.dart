import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/dedication/data/dedication_repository.dart';
import '../../features/dedication/presentation/dedication_labels.dart';
import '../localization/tr.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';

/// The heart of Lahuma: who the reader's recitation is dedicated to, and how
/// much has been dedicated so far. Tapping it lets the reader change the
/// dedication.
class SadaqahCard extends StatelessWidget {
  const SadaqahCard({super.key, required this.dedication, this.onTap});

  final Dedication dedication;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.inkMedium;
    final names = dedication.names.trim();

    return LahumaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dedication.target.title(context),
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  ),
                ),
                if (names.isNotEmpty)
                  Text(
                    names,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textDark : AppColors.inkDark,
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  dedication.target.dua(context),
                  style: context.isArabic
                      ? GoogleFonts.scheherazadeNew(
                          fontSize: 16, height: 1.7, color: subtext)
                      : GoogleFonts.cairo(
                          fontSize: 13, height: 1.5, color: subtext),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  dedication.total > 0
                      ? context.tr(
                          'أُهدي حتى الآن ${dedication.total} آية',
                          '${dedication.total} ayahs dedicated so far')
                      : context.tr('اقرأ لتبدأ الإهداء', 'Read to begin your dedication'),
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: subtext,
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
