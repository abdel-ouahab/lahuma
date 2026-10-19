import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/localization/tr.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/bookmark.dart';

class BookmarkCard extends StatelessWidget {
  const BookmarkCard({
    super.key,
    required this.bookmark,
    required this.onTap,
    required this.onDelete,
  });

  final Bookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LahumaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Bookmark indicator
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.bookmark_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookmark.surahName,
                  style: GoogleFonts.scheherazadeNew(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('الآية ${bookmark.ayahNumber}', 'Ayah ${bookmark.ayahNumber}'),
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(context, bookmark.createdAt),
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.mutedDark
                        : AppColors.mutedLight,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: context.tr('إزالة العلامة', 'Remove bookmark'),
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: Colors.red.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return context.tr('اليوم', 'Today');
    if (diff.inDays == 1) return context.tr('أمس', 'Yesterday');
    if (diff.inDays < 7) {
      return context.tr('منذ ${diff.inDays} أيام', '${diff.inDays} days ago');
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
