import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/dhikr.dart';
import '../adhkar_providers.dart';
import '../widgets/adhkar_widgets.dart';

/// Which list the screen shows.
enum AdhkarTab {
  morning,
  evening,
  favorites;

  AdhkarPeriod? get period => switch (this) {
        AdhkarTab.morning => AdhkarPeriod.morning,
        AdhkarTab.evening => AdhkarPeriod.evening,
        AdhkarTab.favorites => null,
      };

  static AdhkarTab parse(String? name, {DateTime? now}) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    // Rough default: morning adhkar before noon, evening adhkar after.
    return (now ?? DateTime.now()).hour < 12
        ? AdhkarTab.morning
        : AdhkarTab.evening;
  }
}

/// Morning / evening adhkar and the user's favourites, with today's progress.
/// Tapping a dhikr opens it in [AdhkarReaderScreen] to count repetitions.
class AdhkarScreen extends ConsumerStatefulWidget {
  const AdhkarScreen({super.key, this.initialTab});

  final AdhkarTab? initialTab;

  @override
  ConsumerState<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends ConsumerState<AdhkarScreen> {
  late AdhkarTab _tab = widget.initialTab ?? AdhkarTab.parse(null);

  void _open(Dhikr dhikr) =>
      context.push('/adhkar/${dhikr.period.name}?index=${dhikr.index}');

  Future<void> _confirmReset(List<Dhikr> adhkar, AdhkarPeriod period) async {
    final ok = await showAppDialog<bool>(
      context,
      title: context.tr('إعادة العدّ؟', 'Reset counters?'),
      message: context.tr('سيُصفَّر عدّ ${period.title(context)} لهذا اليوم.',
          'Today\'s counts for ${period.title(context).toLowerCase()} will be cleared.'),
      actions: [
        AppDialogAction(label: context.tr('إلغاء', 'Cancel'), value: false),
        AppDialogAction(
            label: context.tr('إعادة', 'Reset'),
            value: true,
            isDestructive: true),
      ],
    );
    if (ok == true) {
      ref.read(adhkarProgressProvider.notifier).resetAll(adhkar);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adhkarAsync = ref.watch(adhkarProvider);
    final progress = ref.watch(adhkarProgressProvider);
    final favorites = ref.watch(adhkarFavoritesProvider);
    final period = _tab.period;

    final List<Dhikr> items = adhkarAsync.valueOrNull == null
        ? const []
        : period != null
            ? adhkarAsync.value!.of(period)
            : [
                for (final p in AdhkarPeriod.values)
                  ...adhkarAsync.value!
                      .of(p)
                      .where((d) => favorites.contains(d.id)),
              ];

    const margin = AppSpacing.screenMargin;

    return AppScaffold.largeTitle(
      title: context.tr('الأذكار', 'Adhkar'),
      trailing: period == null || items.isEmpty
          ? null
          : AppIconButton(
              icon: CupertinoIcons.arrow_counterclockwise,
              label: context.tr('إعادة العدّ', 'Reset counters'),
              onPressed: () => _confirmReset(items, period),
            ),
      bottom: AppNavBarBottom(
        child: AppSegmentedControl<AdhkarTab>(
          segments: {
            AdhkarTab.morning: context.tr('الصباح', 'Morning'),
            AdhkarTab.evening: context.tr('المساء', 'Evening'),
            AdhkarTab.favorites: context.tr('المفضلة', 'Favorites'),
          },
          value: _tab,
          onChanged: (t) => setState(() => _tab = t),
        ),
      ),
      slivers: adhkarAsync.when(
        loading: () => const [
          SliverFillRemaining(hasScrollBody: false, child: AppLoader()),
        ],
        error: (error, _) => [
          SliverFillRemaining(
            hasScrollBody: false,
            child: AdhkarErrorView(
              error: error,
              onRetry: () => ref.invalidate(adhkarProvider),
            ),
          ),
        ],
        data: (_) {
          if (items.isEmpty) {
            return [
              SliverFillRemaining(
                hasScrollBody: false,
                child: period == null
                    ? AppEmptyState(
                        icon: CupertinoIcons.bookmark,
                        title: context.tr(
                            'لا توجد أذكار مفضلة', 'No favorites yet'),
                        message: context.tr(
                            'اضغط على علامة الحفظ في أي ذكر لتجده هنا.',
                            'Tap the bookmark on any dhikr to keep it here.'),
                      )
                    : AppEmptyState(
                        icon: CupertinoIcons.tray,
                        title: context.tr('لا توجد أذكار', 'No adhkar found'),
                      ),
              ),
            ];
          }

          final completed =
              items.where((d) => progress.countOf(d.id) >= d.count).length;

          return [
            if (period != null)
              SliverPadding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    margin, AppSpacing.md, margin, 0),
                sliver: SliverToBoxAdapter(
                  child: _SummaryCard(
                    completed: completed,
                    total: items.length,
                    onStart: () {
                      final next = items.firstWhere(
                          (d) => progress.countOf(d.id) < d.count,
                          orElse: () => items.first);
                      _open(next);
                    },
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  margin, AppSpacing.md, margin, 0),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.ms),
                itemBuilder: (context, i) {
                  final d = items[i];
                  return _DhikrCard(
                    dhikr: d,
                    showPeriod: period == null,
                    done: progress.countOf(d.id),
                    favorite: favorites.contains(d.id),
                    onTap: () => _open(d),
                    onToggleFavorite: () =>
                        ref.read(adhkarFavoritesProvider.notifier).toggle(d),
                  );
                },
              ),
            ),
            const SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(
                  margin, AppSpacing.lg, margin, 0),
              sliver: SliverToBoxAdapter(child: AdhkarSourceNote()),
            ),
          ];
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.completed,
    required this.total,
    required this.onStart,
  });

  final int completed;
  final int total;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final allDone = completed >= total;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  allDone
                      ? context.tr('أتممت أذكار اليوم', 'All done for today')
                      : context.tr('تقدّمك اليوم', 'Today\'s progress'),
                  style: AppTypography.headline.copyWith(color: c.label),
                ),
              ),
              LtrText(
                '$completed / $total',
                style: AppTypography.tabular(AppTypography.subheadline)
                    .copyWith(color: c.secondaryLabel),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppProgressBar(
            value: total == 0 ? 0 : completed / total,
            color: allDone ? c.success : null,
          ),
          const SizedBox(height: AppSpacing.ms),
          AppButton.filled(
            label: allDone
                ? context.tr('القراءة من البداية', 'Read from the start')
                : completed == 0
                    ? context.tr('ابدأ', 'Start')
                    : context.tr('تابع', 'Continue'),
            icon: CupertinoIcons.play_fill,
            expand: true,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

class _DhikrCard extends StatelessWidget {
  const _DhikrCard({
    required this.dhikr,
    required this.showPeriod,
    required this.done,
    required this.favorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final Dhikr dhikr;
  final bool showPeriod;
  final int done;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final complete = done >= dhikr.count;
    final meta = AppTypography.footnote.copyWith(color: c.secondaryLabel);

    return AppCard(
      onTap: onTap,
      semanticLabel: context.tr('افتح الذكر للعدّ', 'Open to count'),
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.xs, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    if (showPeriod) dhikr.period.title(context),
                    repetitionLabel(context, dhikr.count),
                  ].join(' · '),
                  style: meta,
                ),
              ),
              AppIconButton(
                icon: favorite
                    ? CupertinoIcons.bookmark_fill
                    : CupertinoIcons.bookmark,
                label: favorite
                    ? context.tr('إزالة من المفضلة', 'Remove from favorites')
                    : context.tr('إضافة إلى المفضلة', 'Add to favorites'),
                onPressed: onToggleFavorite,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.ms),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DhikrText(dhikr.text, size: 21),
                DhikrNotes(dhikr: dhikr),
                const SizedBox(height: AppSpacing.ms),
                Row(
                  children: [
                    Expanded(
                      child: AppProgressBar(
                        value: done / dhikr.count,
                        color: complete ? c.success : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (complete)
                      Icon(CupertinoIcons.checkmark_circle_fill,
                          size: 18, color: c.success)
                    else
                      LtrText(
                        '$done / ${dhikr.count}',
                        style: AppTypography.tabular(meta),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
