import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/surah.dart';

/// Redesigned Surah list item with geometric number badge, Arabic name,
/// transliteration, revelation type, and ayah count.
class SurahListItem extends StatelessWidget {
  const SurahListItem({
    super.key,
    required this.surah,
    required this.onTap,
  });

  final Surah surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LahumaCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Row(
        children: [
          // ── Number badge (geometric octagon shape) ─────────────────────
          _SurahNumberBadge(number: surah.number),
          const SizedBox(width: AppSpacing.md),
          // ── Name & metadata ─────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  surah.englishName,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      surah.revelationTypeArabic,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      ' • ',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color:
                            isDark ? AppColors.mutedDark : AppColors.mutedLight,
                      ),
                    ),
                    Text(
                      context.tr('${surah.ayahCount} آية', '${surah.ayahCount} ayahs'),
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.subtextDark
                            : AppColors.subtextLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Arabic name ─────────────────────────────────────────────────
          Text(
            surah.arabicName,
            style: GoogleFonts.scheherazadeNew(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textDark : AppColors.inkDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// Octagonal number badge inspired by Islamic geometric shapes.
class _SurahNumberBadge extends StatelessWidget {
  const _SurahNumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(
        painter: _OctagonPainter(color: AppColors.primary),
        child: Center(
          child: Text(
            '$number',
            style: GoogleFonts.cairo(
              fontSize: number > 99 ? 10 : 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _OctagonPainter extends CustomPainter {
  _OctagonPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    const cut = 0.25; // proportion to cut at corners

    final path = Path()
      ..moveTo(w * cut, 0)
      ..lineTo(w * (1 - cut), 0)
      ..lineTo(w, h * cut)
      ..lineTo(w, h * (1 - cut))
      ..lineTo(w * (1 - cut), h)
      ..lineTo(w * cut, h)
      ..lineTo(0, h * (1 - cut))
      ..lineTo(0, h * cut)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OctagonPainter old) => old.color != color;
}

// Keep SurahCard as alias for backward compatibility
typedef SurahCard = SurahListItem;
