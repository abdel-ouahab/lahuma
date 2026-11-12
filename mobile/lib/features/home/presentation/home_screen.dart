import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_settings_enum.dart';
import '../../../core/constants/features.dart';
import '../../../core/design/design.dart';
import '../../../core/localization/tr.dart';
import '../../../core/widgets/continue_reading_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/segment_bar.dart';
import '../../../core/widgets/shortcut_tile.dart';
import '../../adhkar/domain/dhikr.dart';
import '../../adhkar/presentation/adhkar_providers.dart';
import '../../adhkar/presentation/screens/adhkar_category_screen.dart';
import '../../bookmarks/presentation/screens/bookmarks_screen.dart';
import '../../fajr_call/presentation/screens/fajr_call_lists_screen.dart';
import '../../fajr_call/presentation/widgets/fajr_call_home_card.dart';
import '../../khatma/presentation/widgets/khatma_home_card.dart';
import '../../prayer_times/presentation/widgets/prayer_times_section.dart';
import '../../qibla/presentation/widgets/qibla_home_card.dart';
import '../../quran/mushaf/presentation/mushaf_providers.dart';
import '../../quran/mushaf/presentation/screens/mushaf_screen.dart';
import '../../reading_progress/presentation/reading_progress_providers.dart';
import '../../settings/presentation/theme_mode_switcher.dart';
import '../../tasbih/presentation/screens/tasbih_screen.dart';
import '../../tasbih/presentation/tasbih_providers.dart';
import '../../tasbih/presentation/widgets/tasbih_labels.dart';
import '../../wird/presentation/goal_sheet.dart';
import '../../wird/presentation/wird_card.dart';
import '../../wird/presentation/wird_providers.dart';
import 'home_sidebar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(readingProgressProvider);
    final wird = ref.watch(wirdProvider);
    final tasbihToday = ref.watch(tasbihTodayProvider);
    final mushafPage = ref.watch(mushafProvider.select((m) => m.lastPage));
    final c = context.palette;
    final isDark = c.isDark;

    const margin = AppSpacing.screenMargin;

    Widget box(Widget child, {double top = AppSpacing.lg}) => SliverPadding(
          padding: EdgeInsetsDirectional.fromSTEB(margin, top, margin, 0),
          sliver: SliverToBoxAdapter(child: child),
        );

    // A morning / evening adhkar tile: today's progress as one segment
    // per dhikr, lit as each is finished.
    Widget adhkarTile(
      AdhkarPeriod period, {
      required String title,
      required IconData icon,
      required Color color,
      required TileScene scene,
    }) {
      final today = ref.watch(adhkarTodayProvider(period));
      final String caption;
      if (today == null) {
        caption = period == AdhkarPeriod.morning
            ? context.tr('أول النهار', 'Start of the day')
            : context.tr('آخر النهار', 'End of the day');
      } else if (today.done == 0) {
        caption = context.tr('لم تبدأ اليوم', 'Not started today');
      } else if (today.done >= today.total) {
        caption = context.tr('أتممتها اليوم', 'Done today');
      } else {
        caption = context.tr('قرأت ${today.done} من ${today.total}',
            'Read ${today.done} of ${today.total}');
      }
      return ShortcutTile(
        title: title,
        icon: icon,
        color: color,
        caption: caption,
        scene: scene,
        footer: today == null
            ? null
            : SegmentBar(
                filled: today.done,
                total: today.total,
                color: ShortcutTile.onScene,
              ),
        onTap: () =>
            context.go(AdhkarCategoryScreen.pathFor(period.categoryId)),
      );
    }

    // Tiles side by side, all as tall as the tallest: heights follow the
    // text so nothing clips under large Dynamic Type.
    Widget tiles(List<Widget> row) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < row.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.ms),
                Expanded(child: row[i]),
              ],
            ],
          ),
        );

    // No large title: the prayer-times hero is the top of Home.
    return AppScaffold.largeTitle(
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
          // Settings stay one tap away under the "More" tab.
          AppIconButton(
            icon: CupertinoIcons.line_horizontal_3,
            label: context.tr('القائمة', 'Menu'),
            onPressed: () => HomeSidebar.show(context),
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
        // ── Prayer times (carries the greeting) ─────────────────────────────
        box(const PrayerTimesSection(), top: AppSpacing.xs),

        // ── Qibla ───────────────────────────────────────────────────────────
        box(const QiblaHomeCard(), top: AppSpacing.ms),

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
        // The khatma is the one live, daily item, so it takes the large
        // tile; destinations are small, Fajr Call a row of its own.
        box(
          Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Expanded(flex: 2, child: KhatmaHomeCard()),
                    const SizedBox(width: AppSpacing.ms),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ShortcutTile(
                              title: context.tr('المصحف', 'Mushaf'),
                              icon: CupertinoIcons.book_circle_fill,
                              color: AppColors.tileGreen,
                              caption: mushafPage > 1
                                  ? context.tr(
                                      'صفحة $mushafPage', 'Page $mushafPage')
                                  : context.tr(
                                      'مصحف المدينة', 'Madinah Mushaf'),
                              scene: TileScene.mushaf,
                              onTap: () => context.push(MushafScreen.path),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.ms),
                          Expanded(
                            child: ShortcutTile(
                              title: context.tr('الاستماع', 'Listen'),
                              icon: CupertinoIcons.headphones,
                              color: AppColors.tilePurple,
                              caption: context.tr('تلاوات القرّاء', 'Reciters'),
                              scene: TileScene.listen,
                              onTap: () => context.go('/quran?tab=2'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.ms),
              tiles([
                ShortcutTile(
                  title: context.tr('القرآن الكريم', 'The Quran'),
                  icon: CupertinoIcons.book_fill,
                  color: AppColors.tileTeal,
                  caption: context.tr('السور والأجزاء', 'Surahs and juz\''),
                  scene: TileScene.arcade,
                  onTap: () => context.go('/quran'),
                ),
                ShortcutTile(
                  title: context.tr('العلامات', 'Bookmarks'),
                  icon: CupertinoIcons.bookmark_fill,
                  color: AppColors.tileBlue,
                  caption: context.tr('آياتك المحفوظة', 'Saved ayahs'),
                  scene: TileScene.ribbons,
                  onTap: () => context.go(BookmarksScreen.path),
                ),
                ShortcutTile(
                  title: context.tr('الهدف اليومي', 'Daily goal'),
                  icon: CupertinoIcons.flag_fill,
                  color: AppColors.tilePink,
                  caption: context.tr('${wird.goal} آية', '${wird.goal} ayahs'),
                  scene: TileScene.summit,
                  onTap: () => GoalSheet.show(context),
                ),
              ]),
              const SizedBox(height: AppSpacing.ms),
              ShortcutTile(
                title: context.tr('نداء الفجر', 'Fajr Call'),
                icon: CupertinoIcons.sunrise_fill,
                color: AppColors.tileOrange,
                caption: context.tr('أيقظ والديك ومن تحب للصلاة',
                    'Wake your parents and loved ones for prayer'),
                wide: true,
                scene: TileScene.minaret,
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
          tiles([
            adhkarTile(
              AdhkarPeriod.morning,
              title: context.tr('أذكار الصباح', 'Morning adhkar'),
              icon: CupertinoIcons.sun_max_fill,
              color: AppColors.tileYellow,
              scene: TileScene.sunrise,
            ),
            adhkarTile(
              AdhkarPeriod.evening,
              title: context.tr('أذكار المساء', 'Evening adhkar'),
              icon: CupertinoIcons.moon_fill,
              color: AppColors.tileIndigo,
              scene: TileScene.dusk,
            ),
          ]),
          top: 0,
        ),
        box(
          ShortcutTile(
            title: context.tr('التسبيح', 'Tasbih'),
            icon: CupertinoIcons.circle_grid_hex_fill,
            color: AppColors.tileRed,
            caption: tasbihToday > 0
                ? tasbihatToday(context, tasbihToday)
                : context.tr(
                    'مسبحة لعدّ أذكارك', 'Prayer beads for your dhikr'),
            wide: true,
            scene: TileScene.beads,
            onTap: () => context.push(TasbihScreen.path),
          ),
          top: AppSpacing.ms,
        ),

        // ── Today's wird ────────────────────────────────────────────────────
        box(SectionTitle(title: context.tr('وردك اليوم', 'Today\'s wird')),
            top: AppSpacing.xl),
        box(
          WirdCard(
            wird: wird,
            today: DateTime.now(),
            onChangeGoal: () => GoalSheet.show(context),
            onRead: () {
              final progress = progressAsync.valueOrNull;
              context.push(
                progress != null
                    ? '/quran/${progress.surahId}?ayah=${progress.ayahNumber}'
                    : '/quran/1',
              );
            },
          ),
          top: 0,
        ),
        box(const FajrCallStatusCard(), top: AppSpacing.ms),
      ],
    );
  }
}
