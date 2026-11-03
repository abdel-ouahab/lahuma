import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/ayah.dart';

/// Displays a single Quran ayah with:
/// - Arabic text in Scheherazade New (dominant)
/// - Ayah number badge
/// - Action row: play, bookmark, share
/// - Optional English translation and the reader's own note
/// Tap the ayah to open the AyahActionSheet.
class AyahWidget extends StatelessWidget {
  const AyahWidget({
    super.key,
    required this.ayah,
    required this.surahNumber,
    this.fontSize = 26,
    this.translation,
    this.note,
    this.isBookmarked = false,
    this.isPlaying = false,
    this.onPlayToggle,
    this.onBookmarkToggle,
    this.onShare,
    this.onTap,
  });

  final Ayah ayah;
  final int surahNumber;
  final double fontSize;
  final String? translation;
  final String? note;
  final bool isBookmarked;

  /// True while this ayah is the one being recited.
  final bool isPlaying;
  final VoidCallback? onPlayToggle;
  final VoidCallback? onBookmarkToggle;
  final VoidCallback? onShare;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedLight;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final dividerColor =
        isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isPlaying
              ? AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _AyahNumberBadge(number: ayah.numberInSurah),
                const Spacer(),
                _ActionIcon(
                  icon: isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_outline_rounded,
                  color: isPlaying ? AppColors.primary : mutedColor,
                  tooltip: isPlaying
                      ? context.tr('إيقاف مؤقت', 'Pause')
                      : context.tr(
                          'استماع من هذه الآية', 'Listen from this ayah'),
                  onTap: onPlayToggle,
                ),
                _ActionIcon(
                  icon: isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  color: isBookmarked ? AppColors.bookmarkActive : mutedColor,
                  tooltip: isBookmarked
                      ? context.tr('إزالة العلامة', 'Remove bookmark')
                      : context.tr('حفظ العلامة', 'Bookmark'),
                  onTap: onBookmarkToggle,
                ),
                _ActionIcon(
                  icon: Icons.share_outlined,
                  color: mutedColor,
                  tooltip: context.tr('مشاركة', 'Share'),
                  onTap: onShare,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                ayah.text,
                style: GoogleFonts.scheherazadeNew(
                  fontSize: fontSize,
                  height: 2.0,
                  color: textColor,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.justify,
              ),
            ),
            if (translation != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  translation!,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    height: 1.6,
                    color: subtext,
                  ),
                ),
              ),
            ],
            if (note != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.tileOrange.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.edit_note_rounded,
                        size: 18, color: AppColors.tileOrange.color),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        note!,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          height: 1.5,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Container(height: 1, color: dividerColor),
          ],
        ),
      ),
    );
  }
}

class _AyahNumberBadge extends StatelessWidget {
  const _AyahNumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$number',
          style: GoogleFonts.cairo(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: 22, color: color),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }
}
