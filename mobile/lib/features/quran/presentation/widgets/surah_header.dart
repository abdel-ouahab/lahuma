import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';

/// Beautiful surah header card displayed at the top of the reading screen.
/// Shows surah number, Arabic name, transliteration, revelation type & ayah count.
class SurahHeader extends StatelessWidget {
  const SurahHeader({
    super.key,
    required this.surahNumber,
    required this.arabicName,
    required this.englishName,
    required this.meta,
  });

  final int surahNumber;
  final String arabicName;
  final String englishName;

  /// Localized one-line summary, e.g. "مكية • 7 آية".
  final String meta;

  @override
  Widget build(BuildContext context) {
    return LahumaCard(
      padding: EdgeInsets.zero,
      gradient: const LinearGradient(
        colors: AppColors.heroGradient,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      shadow: [
        BoxShadow(
          color: AppColors.primaryDark.withValues(alpha: 0.26),
          blurRadius: 30,
          spreadRadius: -6,
          offset: const Offset(0, 14),
        ),
      ],
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Surah number badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$surahNumber',
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Arabic surah name
                Text(
                  arabicName,
                  style: GoogleFonts.scheherazadeNew(
                    fontSize: 38,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                // English transliteration
                Text(
                  englishName,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Metadata pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    meta,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
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
