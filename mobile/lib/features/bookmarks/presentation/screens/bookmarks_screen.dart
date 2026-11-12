import 'package:flutter/cupertino.dart' show CupertinoNavigationBarBackButton;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/design/app_layout.dart';
import '../../../../core/design/widgets/app_entrance.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/bookmark.dart';
import '../bookmark_card.dart';
import '../bookmarks_providers.dart';

/// Saved ayahs. Opened from Home, the side menu and More (it was a tab
/// until Adhkar took its place).
class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  static const String path = '/home/bookmarks';

  void _delete(BuildContext context, WidgetRef ref, Bookmark bookmark) {
    final notifier = ref.read(bookmarksProvider.notifier);
    notifier.remove(bookmark.surahId, bookmark.ayahNumber);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(context.tr('تمت إزالة العلامة', 'Bookmark removed')),
        action: SnackBarAction(
          label: context.tr('تراجع', 'Undo'),
          onPressed: () => notifier.add(bookmark),
        ),
      ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return Scaffold(
      backgroundColor: background,
      // The lists scroll under the tab bar; they pad for it themselves.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
              child: Row(
                children: [
                  if (context.canPop()) ...[
                    CupertinoNavigationBarBackButton(
                      color: AppColors.primary,
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  // Wraps rather than pushing the count off a narrow screen.
                  Expanded(
                    child: Text(
                      context.tr('العلامات المرجعية', 'Bookmarks'),
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? AppColors.textDark : AppColors.textLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (bookmarks.isNotEmpty)
                    Text(
                      context.tr('${bookmarks.length} علامة',
                          '${bookmarks.length} saved'),
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: bookmarks.isEmpty
                  ? _EmptyState(isDark: isDark)
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          MediaQuery.paddingOf(context).bottom + AppSpacing.lg),
                      itemCount: bookmarks.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final bookmark = bookmarks[index];
                        return Dismissible(
                          key: ValueKey(bookmark.id),
                          direction: DismissDirection.horizontal,
                          background: _SwipeBackground(isDark: isDark),
                          onDismissed: (_) => _delete(context, ref, bookmark),
                          child: BookmarkCard(
                            bookmark: bookmark,
                            // Open the reader at the bookmarked ayah.
                            onTap: () => context.push(
                                '/quran/${bookmark.surahId}?ayah=${bookmark.ayahNumber}'),
                            onDelete: () => _delete(context, ref, bookmark),
                          ),
                        ).listEntrance(index);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // Scrolls in landscape and with large text instead of overflowing.
    return AppScrollableCenter(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_outline_rounded,
                size: 36,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.tr('لا توجد علامات مرجعية', 'No bookmarks yet'),
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textDark : AppColors.textLight,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr('اضغط على أيقونة العلامة بجانب أي آية لحفظها هنا',
                  'Tap the bookmark icon next to any ayah to save it here'),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: isDark ? AppColors.subtextDark : AppColors.subtextLight,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => context.go('/quran'),
              child: Text(context.tr('تصفح السور', 'Browse surahs')),
            ),
          ],
        ),
      ),
    );
  }
}
