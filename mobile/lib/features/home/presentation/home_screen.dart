import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_settings_enum.dart';
import '../../../core/constants/features.dart';
import '../../../core/design/design.dart';
import '../../../core/localization/tr.dart';
import '../../../core/widgets/continue_reading_card.dart';
import '../../../core/widgets/feature_card.dart';
import '../../../core/widgets/progress_card.dart';
import '../../../core/widgets/sadaqah_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../adhkar/domain/dhikr.dart';
import '../../adhkar/presentation/adhkar_providers.dart';
import '../../dedication/presentation/dedication_providers.dart';
import '../../dedication/presentation/dedication_sheet.dart';
import '../../fajr_call/presentation/screens/fajr_call_lists_screen.dart';
import '../../fajr_call/presentation/widgets/fajr_call_home_card.dart';
import '../../prayer_times/presentation/widgets/prayer_times_section.dart';
import '../../quran/mushaf/presentation/screens/mushaf_screen.dart';
import '../../reading_progress/presentation/reading_progress_providers.dart';
import '../../settings/presentation/theme_mode_switcher.dart';
import '../../tasbih/presentation/screens/tasbih_screen.dart';
import '../../tasbih/presentation/tasbih_providers.dart';
import '../../tasbih/presentation/widgets/tasbih_labels.dart';
import '../../wird/presentation/goal_sheet.dart';
import '../../wird/presentation/wird_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(readingProgressProvider);
    final wird = ref.watch(wirdProvider);
    final dedication = ref.watch(dedicationProvider);
    final adhkarDone = ref.watch(adhkarCompletionsProvider);
    final tasbihToday = ref.watch(tasbihTodayProvider);
    final c = context.palette;
    final isDark = c.isDark;

    const margin = AppSpacing.screenMargin;

    Widget box(Widget child, {double top = AppSpacing.lg}) => SliverPadding(
          padding: EdgeInsetsDirectional.fromSTEB(margin, top, margin, 0),
          sliver: SliverToBoxAdapter(child: child),
        );

    // Two tiles per row, as tall as the taller one: heights follow the text
    // so nothing clips under large Dynamic Type.
    Widget pair(Widget a, Widget b) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: a),
              const SizedBox(width: AppSpacing.ms),
              Expanded(child: b),
            ],
          ),
        );

    return AppScaffold.largeTitle(
      title: context.tr('السلام عليكم', 'Assalamu alaikum'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flips what is on screen now; from "system" it pins the opposite.
          ThemeModeSwitcher(
            builder: (context, switchTo) => AppIconButton(
              icon: isDark ? CupertinoIcons.sun_max : CupertinoIcons.moon,
              label: isDark
                  ? context.tr('الوضع الفاتح', 'Light mode')
                  : context.tr('الوضع الداكن', 'Dark mode'),
              onPressed: () =>
                  switchTo(isDark ? AppThemeMode.light : AppThemeMode.dark),
            ),
          ),
          AppIconButton(
            icon: CupertinoIcons.slider_horizontal_3,
            label: context.tr('الإعدادات', 'Settings'),
            onPressed: () => context.go('/settings'),
          ),
          if (Features.accounts)
            AppIconButton(
              icon: CupertinoIcons.person_crop_circle,
              size: 26,
              label: context.tr('حسابي', 'My account'),
              onPressed: () => context.push('/account'),
            ),
        ],
      ),
      slivers: [
        // ── Greeting subtitle ───────────────────────────────────────────────
        box(
          Text(
            context.tr('ابدأ يومك بتلاوة آيات من كلام الله',
                'Begin your day with the words of Allah'),
            style: AppTypography.subheadline.copyWith(color: c.secondaryLabel),
          ),
          top: 0,
        ),

        // ── Prayer times ────────────────────────────────────────────────────
        box(const PrayerTimesSection(), top: AppSpacing.md),

        // ── Continue reading ────────────────────────────────────────────────
        box(
          progressAsync.when(
            data: (progress) => ContinueReadingCard(
              surahName: progress?.surahName,
              ayahNumber: progress?.ayahNumber,
              progressPercent: progress?.percent,
              onTap: () => context.push(
                progress != null
                    ? '/quran/${progress.surahId}?ayah=${progress.ayahNumber}'
                    : '/quran/1',
              ),
              onOpenMushaf: progress != null
                  ? () => context.push(MushafScreen.path)
                  : null,
            ),
            loading: () => const AppShimmer(
              child: AppSkeleton(height: 170, radius: AppRadius.large),
            ),
            error: (_, __) => ContinueReadingCard(
              onTap: () => context.push('/quran/1'),
            ),
          ),
          top: AppSpacing.ms,
        ),

        // ── Shortcuts ───────────────────────────────────────────────────────
        box(SectionTitle(title: context.tr('اختصارات', 'Shortcuts')),
            top: AppSpacing.xl),
        box(
          Column(
            children: [
              pair(
                FeatureCard(
                  title: context.tr('القرآن الكريم', 'The Quran'),
                  icon: CupertinoIcons.book_fill,
                  iconColor: AppColors.accent,
                  subtitle: context.tr('السور والأجزاء', 'Surahs and juz\''),
                  onTap: () => context.go('/quran'),
                ),
                FeatureCard(
                  title: context.tr('الاستماع', 'Listen'),
                  icon: CupertinoIcons.headphones,
                  iconColor: AppColors.tilePurple,
                  subtitle: context.tr('تلاوات القرّاء', 'Reciters'),
                  onTap: () => context.go('/quran?tab=2'),
                ),
              ),
              const SizedBox(height: AppSpacing.ms),
              pair(
                FeatureCard(
                  title: context.tr('العلامات', 'Bookmarks'),
                  icon: CupertinoIcons.bookmark_fill,
                  iconColor: AppColors.tileBlue,
                  subtitle: context.tr('آياتك المحفوظة', 'Your saved ayahs'),
                  onTap: () => context.go('/bookmarks'),
                ),
                FeatureCard(
                  title: context.tr('الهدف اليومي', 'Daily goal'),
                  icon: CupertinoIcons.flag_fill,
                  iconColor: AppColors.tilePink,
                  subtitle:
                      context.tr('${wird.goal} آية', '${wird.goal} ayahs'),
                  onTap: () => GoalSheet.show(context),
                ),
              ),
              const SizedBox(height: AppSpacing.ms),
              FeatureCard(
                title: context.tr('المصحف الشريف', 'The Mushaf'),
                icon: CupertinoIcons.book_circle_fill,
                iconColor: AppColors.tileGreen,
                subtitle: context.tr('صفحات مصحف المدينة كما طُبعت',
                    'The Madinah Mushaf, page by page'),
                onTap: () => context.push(MushafScreen.path),
              ),
              const SizedBox(height: AppSpacing.ms),
              FeatureCard(
                title: context.tr('نداء الفجر', 'Fajr Call'),
                icon: CupertinoIcons.sunrise_fill,
                iconColor: AppColors.tileOrange,
                subtitle: context.tr('أيقظ والديك ومن تحب للصلاة',
                    'Wake your parents and loved ones for prayer'),
                onTap: () => context.go(FajrCallListsScreen.path),
              ),
            ],
          ),
          top: 0,
        ),

        // ── Adhkar ──────────────────────────────────────────────────────────
        box(SectionTitle(title: context.tr('الأذكار', 'Adhkar')),
            top: AppSpacing.xl),
        box(
          pair(
            FeatureCard(
              title: context.tr('أذكار الصباح', 'Morning adhkar'),
              icon: CupertinoIcons.sun_max_fill,
              iconColor: AppColors.tileOrange,
              subtitle: context.tr('أول النهار', 'Start of the day'),
              badge: adhkarDone.countOf(AdhkarPeriod.morning),
              badgeLabel: _adhkarRead(
                  context, adhkarDone.countOf(AdhkarPeriod.morning)),
              onTap: () => context.go('/home/adhkar?tab=morning'),
            ),
            FeatureCard(
              title: context.tr('أذكار المساء', 'Evening adhkar'),
              icon: CupertinoIcons.moon_fill,
              iconColor: AppColors.tileIndigo,
              subtitle: context.tr('آخر النهار', 'End of the day'),
              badge: adhkarDone.countOf(AdhkarPeriod.evening),
              badgeLabel: _adhkarRead(
                  context, adhkarDone.countOf(AdhkarPeriod.evening)),
              onTap: () => context.go('/home/adhkar?tab=evening'),
            ),
          ),
          top: 0,
        ),
        box(
          FeatureCard(
            title: context.tr('التسبيح', 'Tasbih'),
            icon: CupertinoIcons.circle_grid_hex_fill,
            iconColor: AppColors.tileTeal,
            subtitle: tasbihToday > 0
                ? tasbihatToday(context, tasbihToday)
                : context.tr('مسبحة لعدّ أذكارك', 'Prayer beads for your dhikr'),
            onTap: () => context.push(TasbihScreen.path),
          ),
          top: AppSpacing.ms,
        ),

        // ── Today's wird ────────────────────────────────────────────────────
        box(SectionTitle(title: context.tr('وردك اليوم', 'Today\'s wird')),
            top: AppSpacing.xl),
        box(
          ProgressCard(
            wird: wird,
            onTap: () => GoalSheet.show(context),
          ),
          top: 0,
        ),
        box(const FajrCallStatusCard(), top: AppSpacing.ms),

        // ── Dedication ──────────────────────────────────────────────────────
        box(SectionTitle(title: context.tr('نية القراءة', 'Your intention')),
            top: AppSpacing.xl),
        box(
          SadaqahCard(
            dedication: dedication,
            onTap: () => DedicationSheet.show(context),
          ),
          top: 0,
        ),
      ],
    );
  }
}

String _adhkarRead(BuildContext context, int n) =>
    context.tr('قرأت $n ذكراً', '$n adhkar read');
