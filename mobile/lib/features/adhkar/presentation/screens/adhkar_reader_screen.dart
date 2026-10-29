import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../settings/presentation/settings_providers.dart';
import '../../domain/dhikr.dart';
import '../adhkar_providers.dart';
import '../widgets/adhkar_widgets.dart';

/// One dhikr at a time: full text, the source's virtue / reference, a tap
/// counter up to the required count, and previous / next. Swipes between
/// adhkar (right-to-left in Arabic); moves on by itself once a dhikr is
/// complete.
class AdhkarReaderScreen extends ConsumerStatefulWidget {
  const AdhkarReaderScreen(
      {super.key, required this.period, this.initialIndex = 0});

  final AdhkarPeriod period;

  /// Source index of the dhikr to open at.
  final int initialIndex;

  @override
  ConsumerState<AdhkarReaderScreen> createState() => _AdhkarReaderScreenState();
}

class _AdhkarReaderScreenState extends ConsumerState<AdhkarReaderScreen> {
  PageController? _pages;
  int _page = 0;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  PageController _controllerFor(List<Dhikr> adhkar) {
    if (_pages == null) {
      final start = adhkar.indexWhere((d) => d.index == widget.initialIndex);
      _page = start < 0 ? 0 : start;
      _pages = PageController(initialPage: _page);
    }
    return _pages!;
  }

  void _goTo(int page) {
    _pages?.animateToPage(
      page,
      duration: AppMotion.of(context),
      curve: AppMotion.curve,
    );
  }

  void _count(List<Dhikr> adhkar) {
    final dhikr = adhkar[_page];
    final notifier = ref.read(adhkarProgressProvider.notifier);
    final completed = notifier.increment(dhikr);
    dhikrHaptic(completed: completed);
    if (!completed) return;
    ref.read(adhkarCompletionsProvider.notifier).record(dhikr);

    final progress = ref.read(adhkarProgressProvider);
    if (adhkar.every((d) => progress.countOf(d.id) >= d.count)) {
      AppToast.show(
        context,
        context.tr('أتممت ${widget.period.title(context)}، تقبّل الله منك',
            '${widget.period.title(context)} complete'),
        icon: CupertinoIcons.checkmark_seal_fill,
      );
      return;
    }

    // Move on after a beat, unless the user already moved.
    final from = _page;
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted && _page == from && from < adhkar.length - 1) {
        _goTo(from + 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final adhkarAsync = ref.watch(adhkarProvider);
    final adhkar = adhkarAsync.valueOrNull?.of(widget.period) ?? const [];
    final favorites = ref.watch(adhkarFavoritesProvider);
    if (adhkar.isNotEmpty) _controllerFor(adhkar);
    final current = adhkar.isEmpty ? null : adhkar[_page];

    return AppScaffold(
      title: widget.period.title(context),
      trailing: current == null
          ? null
          : AppIconButton(
              icon: favorites.contains(current.id)
                  ? CupertinoIcons.bookmark_fill
                  : CupertinoIcons.bookmark,
              label: favorites.contains(current.id)
                  ? context.tr('إزالة من المفضلة', 'Remove from favorites')
                  : context.tr('إضافة إلى المفضلة', 'Add to favorites'),
              onPressed: () {
                final added =
                    ref.read(adhkarFavoritesProvider.notifier).toggle(current);
                AppToast.show(
                  context,
                  added
                      ? context.tr('أُضيف إلى المفضلة', 'Added to favorites')
                      : context.tr(
                          'أُزيل من المفضلة', 'Removed from favorites'),
                  icon: added
                      ? CupertinoIcons.bookmark_fill
                      : CupertinoIcons.bookmark,
                );
              },
            ),
      child: SafeArea(
        child: adhkarAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: AppShimmer(
              child: AppSkeletonText(lines: 8, lineHeight: 14),
            ),
          ),
          error: (error, _) => AdhkarErrorView(
            error: error,
            onRetry: () => ref.invalidate(adhkarProvider),
          ),
          data: (_) => adhkar.isEmpty
              ? AppEmptyState(
                  icon: CupertinoIcons.tray,
                  title: context.tr('لا توجد أذكار', 'No adhkar found'),
                )
              : _body(adhkar),
        ),
      ),
    );
  }

  Widget _body(List<Dhikr> adhkar) {
    final c = context.palette;
    final progress = ref.watch(adhkarProgressProvider);
    final fontSize = ref.watch(readerFontSizeProvider);
    final controller = _pages!;
    final dhikr = adhkar[_page];
    final done = progress.countOf(dhikr.id);
    final completed =
        adhkar.where((d) => progress.countOf(d.id) >= d.count).length;
    final meta = AppTypography.tabular(AppTypography.footnote)
        .copyWith(color: c.secondaryLabel);

    return Column(
      children: [
        // ── Position + overall progress ─────────────────────────────────────
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screenMargin,
              AppSpacing.sm, AppSpacing.screenMargin, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr(
                          'الذكر ${ltr('${_page + 1} / ${adhkar.length}')}',
                          'Dhikr ${_page + 1} of ${adhkar.length}'),
                      style: meta,
                    ),
                  ),
                  Text(
                    context.tr(
                        'أتممت ${ltr('$completed')}', '$completed completed'),
                    style: meta,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs + 2),
              AppProgressBar(
                value: completed / adhkar.length,
                color: completed == adhkar.length ? c.success : null,
              ),
            ],
          ),
        ),

        // ── The dhikr ───────────────────────────────────────────────────────
        Expanded(
          child: PageView.builder(
            controller: controller,
            itemCount: adhkar.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => _DhikrPage(
              dhikr: adhkar[i],
              fontSize: fontSize,
            ),
          ),
        ),

        // ── Counter + previous / next ───────────────────────────────────────
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screenMargin,
              AppSpacing.sm, AppSpacing.screenMargin, AppSpacing.sm),
          child: Column(
            children: [
              Text(
                repetitionLabel(context, dhikr.count),
                style:
                    AppTypography.subheadline.copyWith(color: c.secondaryLabel),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppButton.tinted(
                      label: context.tr('السابق', 'Previous'),
                      small: true,
                      onPressed: _page > 0 ? () => _goTo(_page - 1) : null,
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: DhikrCounterButton(
                      done: done,
                      total: dhikr.count,
                      onTap: () => _count(adhkar),
                    ),
                  ),
                  Expanded(
                    child: AppButton.tinted(
                      label: context.tr('التالي', 'Next'),
                      small: true,
                      onPressed: _page < adhkar.length - 1
                          ? () => _goTo(_page + 1)
                          : null,
                    ),
                  ),
                ],
              ),
              // Reserve the row so the layout doesn't jump when it appears.
              Opacity(
                opacity: done > 0 ? 1 : 0,
                child: AppButton.plain(
                  label: context.tr('إعادة العدّ', 'Reset count'),
                  small: true,
                  onPressed: done > 0
                      ? () =>
                          ref.read(adhkarProgressProvider.notifier).reset(dhikr)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DhikrPage extends StatelessWidget {
  const _DhikrPage({required this.dhikr, required this.fontSize});

  final Dhikr dhikr;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screenMargin,
          AppSpacing.md, AppSpacing.screenMargin, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            padding: const EdgeInsetsDirectional.all(AppSpacing.ml),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DhikrText(dhikr.text,
                    size: fontSize, textAlign: TextAlign.center),
                DhikrNotes(dhikr: dhikr),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const AdhkarSourceNote(),
        ],
      ),
    );
  }
}
