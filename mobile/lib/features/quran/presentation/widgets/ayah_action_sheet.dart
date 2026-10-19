import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Bottom sheet displayed when the user taps a Quran ayah.
/// Offers: play, bookmark, share, copy, tafsir, translation, note.
class AyahActionSheet extends StatelessWidget {
  const AyahActionSheet({
    super.key,
    required this.surahName,
    required this.ayahNumber,
    this.isBookmarked = false,
    this.hasNote = false,
    this.onPlay,
    this.onBookmark,
    this.onShare,
    this.onCopy,
    this.onTafseer,
    this.onTranslation,
    this.onNote,
  });

  final String surahName;
  final int ayahNumber;
  final bool isBookmarked;
  final bool hasNote;
  final VoidCallback? onPlay;
  final VoidCallback? onBookmark;
  final VoidCallback? onShare;
  final VoidCallback? onCopy;
  final VoidCallback? onTafseer;
  final VoidCallback? onTranslation;
  final VoidCallback? onNote;

  /// Shows the sheet modally.
  static Future<void> show(
    BuildContext context, {
    required String surahName,
    required int ayahNumber,
    bool isBookmarked = false,
    bool hasNote = false,
    VoidCallback? onPlay,
    VoidCallback? onBookmark,
    VoidCallback? onShare,
    VoidCallback? onCopy,
    VoidCallback? onTafseer,
    VoidCallback? onTranslation,
    VoidCallback? onNote,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AyahActionSheet(
        surahName: surahName,
        ayahNumber: ayahNumber,
        isBookmarked: isBookmarked,
        hasNote: hasNote,
        onPlay: onPlay,
        onBookmark: onBookmark,
        onShare: onShare,
        onCopy: onCopy,
        onTafseer: onTafseer,
        onTranslation: onTranslation,
        onNote: onNote,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subtextColor = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    final actions = [
      _ActionItem(
        icon: Icons.play_circle_outline_rounded,
        label: context.tr('استماع', 'Listen'),
        color: AppColors.primary,
        onTap: onPlay,
      ),
      _ActionItem(
        icon: isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
        label: isBookmarked
            ? context.tr('إزالة العلامة', 'Remove bookmark')
            : context.tr('حفظ العلامة', 'Bookmark'),
        color: isBookmarked ? AppColors.bookmarkActive : const Color(0xFF2E7DC0),
        onTap: onBookmark,
      ),
      _ActionItem(
        icon: Icons.share_outlined,
        label: context.tr('مشاركة', 'Share'),
        color: const Color(0xFF7B5EA7),
        onTap: onShare,
      ),
      _ActionItem(
        icon: Icons.copy_outlined,
        label: context.tr('نسخ', 'Copy'),
        color: const Color(0xFFC2507A),
        onTap: onCopy,
      ),
      _ActionItem(
        icon: Icons.book_outlined,
        label: context.tr('التفسير', 'Tafsir'),
        color: const Color(0xFF2BAFA5),
        onTap: onTafseer,
      ),
      _ActionItem(
        icon: Icons.translate_outlined,
        label: context.tr('الترجمة', 'Translation'),
        color: const Color(0xFF4CAF7D),
        onTap: onTranslation,
      ),
      _ActionItem(
        icon: Icons.edit_note_rounded,
        label: hasNote
            ? context.tr('تعديل الملاحظة', 'Edit note')
            : context.tr('إضافة ملاحظة', 'Add note'),
        color: const Color(0xFFE08A33),
        onTap: onNote,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surahName,
                      style: GoogleFonts.scheherazadeNew(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    Text(
                      context.tr('الآية $ayahNumber', 'Ayah $ayahNumber'),
                      style: GoogleFonts.cairo(fontSize: 12, color: subtextColor),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: context.tr('إغلاق', 'Close'),
                  icon: Icon(Icons.close_rounded, size: 18, color: textColor),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            indent: AppSpacing.lg,
            endIndent: AppSpacing.lg,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: actions
                  .map((action) => _ActionTile(item: action, isDark: isDark))
                  .toList(),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + AppSpacing.sm),
        ],
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.item, required this.isDark});

  final _ActionItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.of(context).size.width -
            AppSpacing.lg * 2 -
            AppSpacing.sm * 2) /
        3;

    return Semantics(
      button: true,
      label: item.label,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).pop();
          item.onTap?.call();
        },
        child: Container(
          width: w,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, color: item.color, size: 22),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: item.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
