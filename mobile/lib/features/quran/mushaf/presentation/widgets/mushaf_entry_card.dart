import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/localization/tr.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_card.dart';
import '../../domain/mushaf_meta.dart';
import '../mushaf_providers.dart';
import '../screens/mushaf_screen.dart';

/// Quran-tab banner that opens the Mushaf where the reader left off.
class MushafEntryCard extends ConsumerWidget {
  const MushafEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mushaf = ref.watch(mushafProvider);
    final page = mushaf.lastPage;
    final resume = mushaf.loaded && page > 1;
    final surah = MushafMeta.surahOf(page);
    final subtitle = resume
        ? context.tr('تابع من صفحة $page · سورة ${MushafMeta.surahName(surah)}',
            'Continue from page $page · ${MushafMeta.surahNameLatin(surah)}')
        : context.tr(
            'مصحف المدينة صفحةً صفحة', 'The Madinah Mushaf, page by page');

    return LahumaCard(
      onTap: () => context.push(MushafScreen.path),
      padding: const EdgeInsets.all(AppSpacing.md),
      gradient: const LinearGradient(
        colors: [AppColors.primary, AppColors.primaryDark],
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      shadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      child: Semantics(
        button: true,
        label: context.tr('افتح المصحف الشريف', 'Open the Mushaf'),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('المصحف الشريف', 'The Mushaf'),
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}
