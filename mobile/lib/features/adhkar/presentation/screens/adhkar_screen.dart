import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/widgets/segment_bar.dart';
import '../../../../core/widgets/shortcut_tile.dart';
import '../../domain/dhikr.dart';
import '../adhkar_providers.dart';
import '../widgets/adhkar_widgets.dart';
import 'adhkar_category_screen.dart';

/// The Adhkar tab: the collection for this time of day as a hero, then
/// every category grouped by when it is said.
class AdhkarScreen extends ConsumerWidget {
  const AdhkarScreen({super.key, this.now});

  static const String path = '/adhkar';

  /// Clock for the hero's morning / evening choice; tests pin it.
  final DateTime Function()? now;

  /// Morning adhkar before noon, evening adhkar after, as Home does.
  static AdhkarPeriod periodAt(DateTime time) =>
      time.hour < 12 ? AdhkarPeriod.morning : AdhkarPeriod.evening;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adhkarAsync = ref.watch(adhkarProvider);
    const margin = AppSpacing.screenMargin;

    return AppScaffold.largeTitle(
      title: context.tr('الأذكار والأدعية', 'Adhkar & duas'),
      slivers: adhkarAsync.when(
        loading: () => const [
          SliverToBoxAdapter(
            child: AppSkeletonList(itemCount: 6, lines: 2),
          ),
        ],
        error: (_, __) => [
          SliverFillRemaining(
            hasScrollBody: false,
            child:
                AdhkarErrorView(onRetry: () => ref.invalidate(adhkarProvider)),
          ),
        ],
        data: (collection) {
          final period = periodAt((now ?? DateTime.now)());
          final favorites = ref.watch(adhkarFavoritesProvider);
          final favoriteCount =
              favorites.where((id) => collection.byId(id) != null).length;

          return [
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  margin, AppSpacing.sm, margin, 0),
              sliver: SliverToBoxAdapter(
                child: _NowCard(
                  period: period,
                  category: collection.category(period.categoryId),
                ),
              ),
            ),
            for (final group in AdhkarGroup.values)
              if (collection.categories.where((c) => c.group == group)
                  case final categories when categories.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      margin, AppSpacing.xl, margin, 0),
                  sliver: SliverToBoxAdapter(
                    child: _Group(
                      title: group.title(context),
                      categories: categories.toList(),
                    ),
                  ),
                ),
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  margin, AppSpacing.xl, margin, 0),
              sliver: SliverToBoxAdapter(
                child: ShortcutTile(
                  title: context.tr('أذكاري المفضلة', 'My favourites'),
                  icon: CupertinoIcons.bookmark_fill,
                  color: AppColors.tileBlue,
                  caption: favoriteCount == 0
                      ? context.tr('احفظ أي ذكر لتجده هنا',
                          'Save any dhikr to find it here')
                      : adhkarCountLabel(context, favoriteCount),
                  wide: true,
                  scene: TileScene.ribbons,
                  onTap: () => context.push(AdhkarCategoryScreen.pathFor(
                      AdhkarCategoryScreen.favorites)),
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(
                  margin, AppSpacing.lg, margin, AppSpacing.lg),
              sliver: SliverToBoxAdapter(child: AdhkarSourceNote()),
            ),
          ];
        },
      ),
    );
  }
}

/// The collection for this time of day: green and gilded like Home's
/// Continue reading card, with one segment per dhikr.
class _NowCard extends ConsumerWidget {
  const _NowCard({required this.period, required this.category});

  final AdhkarPeriod period;
  final AdhkarCategory? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(adhkarTodayProvider(period));
    const onHero = AppColors.onAccent;
    final onHeroDim = onHero.withValues(alpha: 0.78);
    final gold = context.palette.gold;
    final done = today?.done ?? 0;
    final total = today?.total ?? 0;
    final allDone = total > 0 && done >= total;

    final String status;
    if (allDone) {
      status = context.tr('أتممتها اليوم، تقبّل الله منك',
          'Done for today. May Allah accept it from you');
    } else if (done == 0) {
      status = context.tr('لم تبدأ بعد اليوم', 'Not started today');
    } else {
      status = context.tr(
          'قرأت ${ltr('$done')} من ${ltr('$total')}', 'Read $done of $total');
    }

    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AppCard(
      onTap: category == null
          ? null
          : () => context.push(AdhkarCategoryScreen.pathFor(category!.id)),
      semanticLabel: '${period.title(context)}، $status',
      padding: const EdgeInsetsDirectional.all(AppSpacing.ml),
      gradient: const LinearGradient(
        colors: AppColors.heroGradient,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderColor: gold.withValues(alpha: 0.7),
      ornament: CrescentCornersPainter(
        gold.withValues(alpha: 0.3),
        corners: [rtl ? Alignment.topLeft : Alignment.topRight],
        scale: 1.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            period == AdhkarPeriod.morning
                ? context.tr('وقت أذكار الصباح', 'Time for the morning adhkar')
                : context.tr('وقت أذكار المساء', 'Time for the evening adhkar'),
            style: AppTypography.footnote
                .weight(FontWeight.w600)
                .copyWith(color: onHeroDim),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            period.title(context),
            style: AppTypography.quran(
                    size: 32, weight: FontWeight.w700, height: 1.35)
                .copyWith(color: onHero),
          ),
          Text(status,
              style: AppTypography.subheadline.copyWith(color: onHeroDim)),
          if (total > 0) ...[
            const SizedBox(height: AppSpacing.md),
            SegmentBar(filled: done, total: total, color: onHero, height: 5),
          ],
          const SizedBox(height: AppSpacing.md),
          // The card is the tap target; the capsule says what it does.
          DecoratedBox(
            decoration: const ShapeDecoration(
              shape: StadiumBorder(),
              color: onHero,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.play_fill,
                      size: 14, color: AppColors.heroGradient.last),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Text(
                    allDone
                        ? context.tr('اقرأها مرة أخرى', 'Read them again')
                        : done == 0
                            ? context.tr('ابدأ', 'Start')
                            : context.tr('تابع', 'Continue'),
                    style: AppTypography.subheadline
                        .weight(FontWeight.w600)
                        .copyWith(color: AppColors.heroGradient.last),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled group of category tiles, two to a row; an odd last tile spans
/// the row.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.categories});

  final String title;
  final List<AdhkarCategory> categories;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < categories.length; i += 2) {
      final pair = categories.skip(i).take(2).toList();
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.ms));
      rows.add(pair.length == 1
          ? _CategoryTile(category: pair.first, wide: true)
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _CategoryTile(category: pair[0])),
                  const SizedBox(width: AppSpacing.ms),
                  Expanded(child: _CategoryTile(category: pair[1])),
                ],
              ),
            ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppTypography.title3
                .weight(FontWeight.w700)
                .copyWith(color: context.palette.label),
          ),
        ),
        const SizedBox(height: AppSpacing.ms),
        ...rows,
      ],
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category, this.wide = false});

  final AdhkarCategory category;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(adhkarCategoryTodayProvider(category.id));
    final tone = adhkarTone(category.tone);
    final total = category.items.length;
    final done = today?.done ?? 0;
    final caption = done == 0
        ? adhkarCountLabel(context, total)
        : done >= total
            ? context.tr('أتممتها اليوم', 'Done today')
            : context.tr('${ltr('$done')} من ${ltr('$total')} اليوم',
                '$done of $total today');
    return ShortcutTile(
      title: category.label(context),
      icon: adhkarIcon(category.icon),
      color: tone,
      caption: caption,
      wide: wide,
      scene: adhkarScene(category.icon),
      footer: done == 0 || wide
          ? null
          : SegmentBar(filled: done, total: total, color: ShortcutTile.onScene),
      onTap: () => context.push(AdhkarCategoryScreen.pathFor(category.id)),
    );
  }
}
