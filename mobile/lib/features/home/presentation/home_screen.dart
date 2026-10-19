import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/localization/tr.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/continue_reading_card.dart';
import '../../../core/widgets/feature_card.dart';
import '../../../core/widgets/lahuma_icon_button.dart';
import '../../../core/widgets/progress_card.dart';
import '../../../core/widgets/sadaqah_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../dedication/presentation/dedication_providers.dart';
import '../../dedication/presentation/dedication_sheet.dart';
import '../../reading_progress/presentation/reading_progress_providers.dart';
import '../../wird/presentation/goal_sheet.dart';
import '../../wird/presentation/wird_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(readingProgressProvider);
    final wird = ref.watch(wirdProvider);
    final dedication = ref.watch(dedicationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    const gutter = AppSpacing.lg;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, 0),
                child: Row(
                  children: [
                    LahumaIconButton(
                      icon: Icons.person_outline_rounded,
                      tooltip: context.tr('حسابي', 'My account'),
                      onTap: () => context.push('/account'),
                    ),
                    const Spacer(),
                    Text(
                      'لهما',
                      style: GoogleFonts.scheherazadeNew(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    LahumaIconButton(
                      icon: Icons.tune_rounded,
                      tooltip: context.tr('الإعدادات', 'Settings'),
                      onTap: () => context.go('/settings'),
                    ),
                  ],
                ),
              ),
            ),

            // ── Greeting ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(gutter, gutter, gutter, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('السلام عليكم', 'Assalamu alaikum'),
                      style: GoogleFonts.cairo(
                        fontSize: 32,
                        height: 1.15,
                        // Tracking tightens as type grows, but never on Arabic:
                        // letter-spacing breaks the joined script.
                        letterSpacing: context.isArabic ? 0 : -0.8,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textDark : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.tr('ابدأ يومك بتلاوة آيات من كلام الله',
                          'Begin your day with the words of Allah'),
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        color: isDark ? AppColors.subtextDark : AppColors.subtextLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Continue reading ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(gutter, gutter, gutter, 0),
                child: progressAsync.when(
                  data: (progress) => ContinueReadingCard(
                    surahName: progress?.surahName,
                    ayahNumber: progress?.ayahNumber,
                    progressPercent: progress?.percent,
                    onTap: () => context.push(
                      progress != null
                          ? '/quran/${progress.surahId}?ayah=${progress.ayahNumber}'
                          : '/quran/1',
                    ),
                  ),
                  loading: () => _placeholderCard(height: 170),
                  error: (_, __) => ContinueReadingCard(
                    onTap: () => context.push('/quran/1'),
                  ),
                ),
              ),
            ),

            // ── Shortcuts ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(gutter, AppSpacing.xl + 4, gutter, 0),
                child: SectionTitle(title: context.tr('اختصارات', 'Shortcuts')),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: gutter),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.3,
                children: [
                  FeatureCard(
                    title: context.tr('القرآن الكريم', 'The Quran'),
                    icon: Icons.menu_book_rounded,
                    iconColor: AppColors.primary,
                    subtitle: context.tr('السور والأجزاء', 'Surahs and juz\''),
                    onTap: () => context.go('/quran'),
                  ),
                  FeatureCard(
                    title: context.tr('الاستماع', 'Listen'),
                    icon: Icons.headphones_rounded,
                    iconColor: const Color(0xFF8E5CF7),
                    subtitle: context.tr('تلاوات القرّاء', 'Reciters'),
                    onTap: () => context.go('/quran?tab=2'),
                  ),
                  FeatureCard(
                    title: context.tr('العلامات', 'Bookmarks'),
                    icon: Icons.bookmark_rounded,
                    iconColor: const Color(0xFF0A84FF),
                    subtitle: context.tr('آياتك المحفوظة', 'Your saved ayahs'),
                    onTap: () => context.go('/bookmarks'),
                  ),
                  FeatureCard(
                    title: context.tr('الهدف اليومي', 'Daily goal'),
                    icon: Icons.flag_rounded,
                    iconColor: const Color(0xFFFF6482),
                    subtitle: context.tr('${wird.goal} آية', '${wird.goal} ayahs'),
                    onTap: () => GoalSheet.show(context),
                  ),
                ],
              ),
            ),

            // ── Today's wird ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(gutter, AppSpacing.xl + 4, gutter, 0),
                child: SectionTitle(title: context.tr('وردك اليوم', 'Today\'s wird')),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: gutter),
                child: ProgressCard(
                  wird: wird,
                  onTap: () => GoalSheet.show(context),
                ),
              ),
            ),

            // ── Dedication ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(gutter, AppSpacing.xl + 4, gutter, 0),
                child: SectionTitle(title: context.tr('نية القراءة', 'Your intention')),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, gutter),
                child: SadaqahCard(
                  dedication: dedication,
                  onTap: () => DedicationSheet.show(context),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          ],
        ),
      ),
    );
  }

  Widget _placeholderCard({double height = 120}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
    );
  }
}
