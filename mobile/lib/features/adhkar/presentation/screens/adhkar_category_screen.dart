import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/widgets/segment_bar.dart';
import '../../domain/dhikr.dart';
import '../adhkar_providers.dart';
import '../widgets/adhkar_widgets.dart';

/// One category's adhkar laid out like a wird booklet: passages on the page,
/// the one to say now lit, a verse rosette counting each. Tapping a passage
/// counts one repetition; once it is complete the list moves on to the next.
/// Today's counts are kept until the day changes.
class AdhkarCategoryScreen extends ConsumerStatefulWidget {
  const AdhkarCategoryScreen({super.key, required this.categoryId});

  /// Pseudo-category gathering the user's saved adhkar.
  static const String favorites = 'favorites';

  static String pathFor(String id) => '/adhkar/$id';

  final String categoryId;

  @override
  ConsumerState<AdhkarCategoryScreen> createState() =>
      _AdhkarCategoryScreenState();
}

class _AdhkarCategoryScreenState extends ConsumerState<AdhkarCategoryScreen> {
  final Map<String, GlobalKey> _keys = {};

  bool get _isFavorites => widget.categoryId == AdhkarCategoryScreen.favorites;

  GlobalKey _keyFor(Dhikr d) => _keys.putIfAbsent(d.id, GlobalKey.new);

  void _count(Dhikr dhikr, List<Dhikr> items) {
    final progress = ref.read(adhkarProgressProvider);
    if (progress.countOf(dhikr.id) >= dhikr.count) return;
    final completed =
        ref.read(adhkarProgressProvider.notifier).increment(dhikr);
    dhikrHaptic(completed: completed);
    if (!completed) return;
    ref.read(adhkarCompletionsProvider.notifier).record(dhikr);

    final now = ref.read(adhkarProgressProvider);
    if (items.every((d) => now.countOf(d.id) >= d.count)) {
      AppToast.show(
        context,
        context.tr('أتممتها كلها، تقبّل الله منك',
            'All done. May Allah accept it from you'),
        icon: CupertinoIcons.checkmark_seal_fill,
      );
      return;
    }

    // Bring the next unfinished dhikr into view after a beat.
    final at = items.indexOf(dhikr);
    final next = [...items.skip(at + 1), ...items.take(at)]
        .where((d) => now.countOf(d.id) < d.count)
        .firstOrNull;
    if (next == null) return;
    final duration = AppMotion.of(context, AppMotion.standard);
    Future.delayed(const Duration(milliseconds: 380), () {
      final target = _keys[next.id]?.currentContext;
      if (!mounted || target == null || !target.mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.06,
        duration: duration,
        curve: AppMotion.curve,
      );
    });
  }

  Future<void> _confirmReset(List<Dhikr> items) async {
    final ok = await showAppDialog<bool>(
      context,
      title: context.tr('إعادة العدّ؟', 'Reset counters?'),
      message: context.tr('سيُصفَّر عدّ هذه الأذكار لهذا اليوم.',
          'Today\'s counts for these adhkar will be cleared.'),
      actions: [
        AppDialogAction(label: context.tr('إلغاء', 'Cancel'), value: false),
        AppDialogAction(
            label: context.tr('إعادة', 'Reset'),
            value: true,
            isDestructive: true),
      ],
    );
    if (ok == true) {
      ref.read(adhkarProgressProvider.notifier).resetAll(items);
    }
  }

  Future<void> _copy(Dhikr dhikr) async {
    await Clipboard.setData(ClipboardData(text: dhikrShareText(dhikr)));
    if (!mounted) return;
    AppToast.show(context, context.tr('نُسخ الذكر', 'Copied'),
        icon: CupertinoIcons.doc_on_doc);
  }

  Future<void> _share(Dhikr dhikr) =>
      SharePlus.instance.share(ShareParams(text: dhikrShareText(dhikr)));

  void _toggleFavorite(Dhikr dhikr) {
    final added = ref.read(adhkarFavoritesProvider.notifier).toggle(dhikr);
    AppToast.show(
      context,
      added
          ? context.tr('أُضيف إلى المفضلة', 'Added to favourites')
          : context.tr('أُزيل من المفضلة', 'Removed from favourites'),
      icon: added ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
    );
  }

  Future<void> _actions(Dhikr dhikr, bool favorite) async {
    final choice = await showAppActionSheet<String>(
      context,
      actions: [
        AppSheetAction(
            label: context.tr('نسخ', 'Copy'),
            value: 'copy',
            icon: CupertinoIcons.doc_on_doc),
        AppSheetAction(
            label: context.tr('مشاركة', 'Share'),
            value: 'share',
            icon: CupertinoIcons.share),
        AppSheetAction(
          label: favorite
              ? context.tr('إزالة من المفضلة', 'Remove from favourites')
              : context.tr('إضافة إلى المفضلة', 'Add to favourites'),
          value: 'favorite',
          icon:
              favorite ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
        ),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'copy':
        await _copy(dhikr);
      case 'share':
        await _share(dhikr);
      case 'favorite':
        _toggleFavorite(dhikr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adhkarAsync = ref.watch(adhkarProvider);
    final collection = adhkarAsync.valueOrNull;
    final favorites = ref.watch(adhkarFavoritesProvider);
    final category =
        _isFavorites ? null : collection?.category(widget.categoryId);

    final List<Dhikr> items = collection == null
        ? const []
        : _isFavorites
            ? [
                for (final c in collection.categories)
                  ...c.items.where((d) => favorites.contains(d.id)),
              ]
            : category?.items ?? const [];

    final title = _isFavorites
        ? context.tr('أذكاري المفضلة', 'My favourites')
        : category?.label(context) ?? context.tr('الأذكار', 'Adhkar');

    return AppScaffold.largeTitle(
      title: title,
      trailing: items.isEmpty
          ? null
          : AppIconButton(
              icon: CupertinoIcons.arrow_counterclockwise,
              label: context.tr('إعادة العدّ', 'Reset counters'),
              onPressed: () => _confirmReset(items),
            ),
      bottom:
          items.isEmpty ? null : AppNavBarBottom(child: _Header(items: items)),
      slivers: adhkarAsync.when(
        loading: () => const [
          SliverToBoxAdapter(
            child: AppSkeletonList(
                itemCount: 4,
                lines: 4,
                leadingSize: null,
                spacing: AppSpacing.lg),
          ),
        ],
        error: (_, __) => [
          SliverFillRemaining(
            hasScrollBody: false,
            child:
                AdhkarErrorView(onRetry: () => ref.invalidate(adhkarProvider)),
          ),
        ],
        data: (_) {
          if (items.isEmpty) {
            return [
              SliverFillRemaining(
                hasScrollBody: false,
                child: _isFavorites
                    ? AppEmptyState(
                        icon: CupertinoIcons.bookmark,
                        title: context.tr(
                            'لا توجد أذكار مفضلة', 'No favourites yet'),
                        message: context.tr(
                            'اضغط على ⋯ تحت أي ذكر واختر «إضافة إلى المفضلة».',
                            'Tap ⋯ under any dhikr and choose Add to favourites.'),
                      )
                    : AppEmptyState(
                        icon: CupertinoIcons.tray,
                        title: context.tr('لا توجد أذكار', 'No adhkar found'),
                      ),
              ),
            ];
          }
          const margin = AppSpacing.screenMargin;
          final fontSize = ref.watch(adhkarFontSizeProvider);
          final progress = ref.watch(adhkarProgressProvider);
          final today = ref.watch(adhkarProgressRepositoryProvider).today;
          int doneOf(Dhikr d) =>
              progress.date == today ? progress.countOf(d.id) : 0;
          // The first one not yet said is the one to say now.
          final current = items.where((d) => doneOf(d) < d.count).firstOrNull;

          return [
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  margin - AppSpacing.sm,
                  AppSpacing.sm,
                  margin - AppSpacing.sm,
                  0),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, i) => _Rule(
                  // No rule against the lit passage: its surface sets it off.
                  hidden: items[i] == current || items[i + 1] == current,
                ),
                itemBuilder: (context, i) {
                  final d = items[i];
                  final done = doneOf(d);
                  return _Passage(
                    key: _keyFor(d),
                    dhikr: d,
                    done: done,
                    state: done >= d.count
                        ? DhikrState.done
                        : d == current
                            ? DhikrState.current
                            : DhikrState.ahead,
                    fontSize: fontSize,
                    favorite: favorites.contains(d.id),
                    // Favourites mix categories: say where each comes from.
                    label: _isFavorites
                        ? collection!.category(d.categoryId)?.label(context)
                        : d.occasion,
                    onTap: () => _count(d, items),
                    onMore: () => _actions(d, favorites.contains(d.id)),
                  );
                },
              ),
            ),
            const SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(
                  margin, AppSpacing.xl, margin, AppSpacing.lg),
              sliver: SliverToBoxAdapter(child: AdhkarSourceNote()),
            ),
          ];
        },
      ),
    );
  }
}

/// Pinned under the title: one segment per dhikr, lit as each is said, and
/// the text size.
class _Header extends ConsumerWidget {
  const _Header({required this.items});

  final List<Dhikr> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.palette;
    final progress = ref.watch(adhkarProgressProvider);
    final today = ref.watch(adhkarProgressRepositoryProvider).today;
    final completed = progress.date != today
        ? 0
        : items.where((d) => progress.countOf(d.id) >= d.count).length;
    final allDone = completed == items.length;
    ref.watch(adhkarFontSizeProvider);
    final font = ref.read(adhkarFontSizeProvider.notifier);

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.screenMargin),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: context.tr('أتممت $completed من ${items.length}',
                  '$completed of ${items.length} completed'),
              excludeSemantics: true,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allDone
                        ? context.tr('أتممتها اليوم', 'Done today')
                        : context.tr(
                            'أتممت ${ltr('$completed')} من ${ltr('${items.length}')}',
                            '$completed of ${items.length} said'),
                    style: AppTypography.tabular(AppTypography.footnote)
                        .weight(FontWeight.w600)
                        .copyWith(color: c.secondaryLabel),
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  SegmentBar(
                    filled: completed,
                    total: items.length,
                    color: allDone ? c.success : c.accent,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          _SizeStepper(
            onShrink: font.canShrink ? font.shrink : null,
            onGrow: font.canGrow ? font.grow : null,
          ),
        ],
      ),
    );
  }
}

/// A− | A+ in one capsule, read left to right in either language like the
/// system's own steppers.
class _SizeStepper extends StatelessWidget {
  const _SizeStepper({required this.onShrink, required this.onGrow});

  final VoidCallback? onShrink;
  final VoidCallback? onGrow;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    Widget button(String glyph, String label, double size, VoidCallback? on) =>
        Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(46, 36),
            onPressed: on,
            child: Text(
              glyph,
              style: AppTypography.headline.copyWith(
                fontSize: size,
                fontWeight: FontWeight.w700,
                color: on == null ? c.tertiaryLabel : c.label,
              ),
            ),
          ),
        );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DecoratedBox(
        decoration:
            ShapeDecoration(shape: const StadiumBorder(), color: c.fill),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(
                'A−', context.tr('تصغير الخط', 'Smaller text'), 13, onShrink),
            Container(width: 0.5, height: 18, color: c.separator),
            button('A+', context.tr('تكبير الخط', 'Larger text'), 17, onGrow),
          ],
        ),
      ),
    );
  }
}

/// Hairline between passages, inset like a printed booklet's.
class _Rule extends StatelessWidget {
  const _Rule({required this.hidden});

  final bool hidden;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
        child: Container(
          height: 0.5,
          color: hidden ? null : context.palette.separator,
        ),
      );
}

/// One dhikr as a passage on the page. The one to say now sits on a lit
/// surface; those already said fade back. The whole passage counts on tap.
class _Passage extends StatefulWidget {
  const _Passage({
    super.key,
    required this.dhikr,
    required this.done,
    required this.state,
    required this.fontSize,
    required this.favorite,
    required this.label,
    required this.onTap,
    required this.onMore,
  });

  final Dhikr dhikr;
  final int done;
  final DhikrState state;
  final double fontSize;
  final bool favorite;
  final String? label;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  State<_Passage> createState() => _PassageState();
}

class _PassageState extends State<_Passage> {
  bool _pressed = false;

  void _press(bool down) {
    if (widget.state == DhikrState.done || _pressed == down) return;
    setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final d = widget.dhikr;
    final state = widget.state;
    final isDone = state == DhikrState.done;
    final lit = state == DhikrState.current;
    final duration = AppMotion.of(context);
    final left = d.count - widget.done;
    const clear = Color(0x00000000);

    final body = AnimatedOpacity(
      opacity: isDone ? 0.5 : 1,
      duration: duration,
      curve: AppMotion.curve,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.label != null) ...[
            Text(widget.label!,
                style: AppTypography.footnote
                    .weight(FontWeight.w600)
                    .copyWith(color: c.secondaryLabel)),
            const SizedBox(height: AppSpacing.xs),
          ],
          DhikrText(d.text, size: widget.fontSize),
          if (d.virtue != null) ...[
            const SizedBox(height: AppSpacing.ms),
            _Virtue(text: d.virtue!),
          ],
          if (d.reference != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(d.reference!,
                  style:
                      AppTypography.caption1.copyWith(color: c.tertiaryLabel)),
            ),
          ],
        ],
      ),
    );

    // Its own node, so the options button inside stays reachable.
    return Semantics(
      container: true,
      button: !isDone,
      label: isDone
          ? context.tr('تمّ هذا الذكر', 'Said')
          : context.tr('اضغط للعدّ، $left متبقٍّ', 'Tap to count, $left left'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isDone ? null : widget.onTap,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1,
          duration: AppMotion.of(context, AppMotion.fast),
          child: AnimatedContainer(
            duration: duration,
            curve: AppMotion.curve,
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md, AppSpacing.ml, AppSpacing.md, AppSpacing.sm),
            decoration: ShapeDecoration(
              color: lit
                  ? c.secondaryGroupedBackground
                  : c.secondaryGroupedBackground.withValues(alpha: 0),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(AppRadius.large),
                side: BorderSide(
                  color: lit ? c.gold.withValues(alpha: 0.55) : clear,
                ),
              ),
              shadows: [
                BoxShadow(
                  color: lit ? c.shadow(0.35) : clear,
                  offset: const Offset(0, 8),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                body,
                const SizedBox(height: AppSpacing.ms),
                Row(
                  children: [
                    DhikrRosette(
                        done: widget.done, total: d.count, state: state),
                    const SizedBox(width: AppSpacing.ms),
                    Expanded(
                      child: Text(
                        isDone
                            ? context.tr('تمّ', 'Done')
                            : widget.done == 0
                                ? repetitionLabel(context, d.count)
                                : context.tr(
                                    'بقي ${repetitionLabel(context, left)}',
                                    '$left to go'),
                        style: AppTypography.subheadline
                            .copyWith(color: lit ? c.label : c.secondaryLabel),
                      ),
                    ),
                    if (widget.favorite)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                            end: AppSpacing.xs),
                        child: Icon(CupertinoIcons.bookmark_fill,
                            size: 16, color: c.gold),
                      ),
                    // A node of its own, not folded into the passage's.
                    Semantics(
                      container: true,
                      child: AppIconButton(
                        icon: CupertinoIcons.ellipsis,
                        label: context.tr('خيارات الذكر', 'Dhikr options'),
                        size: 20,
                        color: c.secondaryLabel,
                        onPressed: widget.onMore,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The book's statement of the dhikr's virtue, set off by a gold rule.
class _Virtue extends StatelessWidget {
  const _Virtue({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsetsDirectional.only(start: AppSpacing.ms),
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: c.gold.withValues(alpha: 0.7), width: 2),
          ),
        ),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
              text: 'الفضل: ',
              style: AppTypography.footnote
                  .weight(FontWeight.w700)
                  .copyWith(color: c.label),
            ),
            TextSpan(text: text),
          ]),
          style: AppTypography.subheadline.copyWith(color: c.secondaryLabel),
        ),
      ),
    );
  }
}
