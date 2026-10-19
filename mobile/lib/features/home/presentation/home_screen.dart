import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/design.dart';
import '../../../core/localization/tr.dart';
import '../../../core/widgets/continue_reading_card.dart';
import '../../../core/widgets/feature_card.dart';
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
    final c = context.palette;

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
          AppIconButton(
            icon: CupertinoIcons.slider_horizontal_3,
            label: context.tr('الإعدادات', 'Settings'),
            onPressed: () => context.go('/settings'),
          ),
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
            ),
            loading: () => AppCard(
              color: c.tertiaryFill,
              child: const SizedBox(height: 170, child: AppLoader()),
            ),
            error: (_, __) => ContinueReadingCard(
              onTap: () => context.push('/quran/1'),
            ),
          ),
          top: AppSpacing.md,
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
            ],
          ),
          top: 0,
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
