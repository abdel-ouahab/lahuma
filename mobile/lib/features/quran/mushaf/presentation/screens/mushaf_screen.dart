import 'dart:math' as math;
import 'package:flutter/material.dart' show Material;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qcf_quran/qcf_quran.dart';
import '../../../../../core/design/design.dart';
import '../../../../../core/localization/tr.dart';
import '../../data/mushaf_repository.dart';
import '../../domain/mushaf_meta.dart';
import '../mushaf_providers.dart';
import '../widgets/ayah_sheet.dart';
import '../widgets/mushaf_overlay.dart';
import '../widgets/mushaf_page.dart';
import '../widgets/mushaf_themes.dart';

/// The Madinah Mushaf, page by page, drawn with the KFGQPC QCF page fonts.
///
/// Swipes in Arabic reading order (page 1 on the right) whatever the app
/// language. Opens on [initialPage], or on the last page read.
class MushafScreen extends ConsumerStatefulWidget {
  const MushafScreen({super.key, this.initialPage});

  static const String path = '/mushaf';

  final int? initialPage;

  @override
  ConsumerState<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends ConsumerState<MushafScreen> {
  // qcf_quran sizes its pages for this design size (its README's ScreenUtil
  // setup); [_scales] reproduces ScreenUtil's `sp` and `h` from it.
  static const Size _designSize = Size(392.72727272727275, 800.7272727272727);


  PageController? _controller;
  final ValueNotifier<int> _page = ValueNotifier(1);
  bool _zoomed = false;
  bool _overlayVisible = true;
  ({int surah, int ayah})? _selected;

  @override
  void dispose() {
    _controller?.dispose();
    _page.dispose();
    super.dispose();
  }

  PageController _controllerFor(MushafState mushaf) {
    final existing = _controller;
    if (existing != null) return existing;
    final start =
        (widget.initialPage ?? mushaf.lastPage).clamp(1, MushafMeta.pageCount);
    _page.value = start;
    if (start != mushaf.lastPage) {
      // onPageChanged does not fire for the initial page.
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(mushafProvider.notifier).setLastPage(start));
    }
    return _controller = PageController(initialPage: start - 1);
  }

  ({double sp, double h}) _scales(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final sw = size.width / _designSize.width;
    final sh = size.height / _designSize.height;
    return (sp: math.min(sw, sh), h: sh);
  }

  void _onPageChanged(int index) {
    final page = index + 1;
    _page.value = page;
    setState(() {
      _zoomed = false;
      _selected = null;
    });
    ref.read(mushafProvider.notifier).setLastPage(page);
  }

  void _jumpTo(int page) {
    if (page != _page.value) _controller?.jumpToPage(page - 1);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/quran');
    }
  }

  Future<void> _openIndex() async {
    final page = await context
        .push<int>('${MushafScreen.path}/index?page=${_page.value}');
    if (page != null && mounted) _jumpTo(page);
  }

  Future<void> _goToPage() async {
    final text = await showAppTextInputDialog(
      context,
      title: context.tr('الانتقال إلى صفحة', 'Go to page'),
      message: context.tr('أدخل رقمًا من 1 إلى ${MushafMeta.pageCount}',
          'Enter a number from 1 to ${MushafMeta.pageCount}'),
      placeholder: '${_page.value}',
      confirmLabel: context.tr('انتقال', 'Go'),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩۰-۹]')),
        LengthLimitingTextInputFormatter(3),
      ],
    );
    if (text == null || !mounted) return;
    final page = int.tryParse(_westernDigits(text.trim()));
    if (page == null || page < 1 || page > MushafMeta.pageCount) {
      AppToast.show(
          context, context.tr('رقم صفحة غير صحيح', 'Invalid page number'),
          icon: CupertinoIcons.exclamationmark_circle_fill);
      return;
    }
    _jumpTo(page);
  }

  Future<void> _toggleBookmark() async {
    HapticFeedback.lightImpact();
    final added =
        await ref.read(mushafProvider.notifier).toggleBookmark(_page.value);
    if (!mounted) return;
    AppToast.show(
      context,
      added
          ? context.tr('حُفظت الصفحة في العلامات', 'Page bookmarked')
          : context.tr('أُزيلت العلامة', 'Bookmark removed'),
      icon: added ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
    );
  }

  Future<void> _chooseTheme(MushafTheme current) async {
    AppSheetAction<MushafTheme> option(
            MushafTheme value, String label, IconData icon) =>
        AppSheetAction(
            label: label,
            value: value,
            icon: icon,
            isDefault: value == current);
    final theme = await showAppActionSheet<MushafTheme>(
      context,
      title: context.tr('مظهر المصحف', 'Mushaf appearance'),
      actions: [
        option(
            MushafTheme.auto,
            context.tr('تلقائي (حسب التطبيق)', 'Automatic (app theme)'),
            CupertinoIcons.circle_lefthalf_fill),
        option(MushafTheme.white, context.tr('أبيض', 'White'),
            CupertinoIcons.sun_max),
        option(MushafTheme.sepia, context.tr('ورقي', 'Sepia'),
            CupertinoIcons.book),
        option(
            MushafTheme.dark, context.tr('داكن', 'Dark'), CupertinoIcons.moon),
      ],
    );
    if (theme != null) ref.read(mushafProvider.notifier).setTheme(theme);
  }

  Future<void> _onAyahLongPress(int surah, int ayah) async {
    HapticFeedback.selectionClick();
    setState(() => _selected = (surah: surah, ayah: ayah));
    await showAyahSheet(context, surah: surah, ayah: ayah);
    if (mounted) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final mushaf = ref.watch(mushafProvider);
    final isDark = switch (mushaf.theme) {
      MushafTheme.auto => context.palette.isDark,
      MushafTheme.dark => true,
      MushafTheme.white || MushafTheme.sepia => false,
    };
    final theme = switch (mushaf.theme) {
      MushafTheme.white => MushafThemes.white,
      MushafTheme.sepia => MushafThemes.paper,
      _ => isDark ? MushafThemes.night : MushafThemes.paper,
    };
    final highlight = isDark
        ? AppColors.mushafNightHighlight
        : AppColors.mushafLightHighlight;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Material(
        color: theme.pageBackgroundColor,
        child: !mushaf.loaded
            ? const AppLoader()
            : Stack(
                children: [
                  Positioned.fill(child: _buildPages(mushaf, theme, highlight)),
                  Positioned.fill(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _page,
                      builder: (context, page, _) => MushafOverlay(
                        visible: _overlayVisible,
                        page: page,
                        theme: theme,
                        bookmarked: mushaf.isBookmarked(page),
                        onBack: _back,
                        onIndex: _openIndex,
                        onGoToPage: _goToPage,
                        onToggleBookmark: _toggleBookmark,
                        onChooseTheme: () => _chooseTheme(mushaf.theme),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPages(MushafState mushaf, QcfThemeData theme, Color highlight) {
    final scales = _scales(context);
    final selected = _selected;
    return Directionality(
      // RTL axis: page 1 sits on the right and the next page comes from the
      // left, as in a printed Mushaf.
      textDirection: TextDirection.rtl,
      child: PageView.builder(
        controller: _controllerFor(mushaf),
        itemCount: MushafMeta.pageCount,
        // Lays out the neighbouring pages off screen, so their page fonts
        // are loaded before they slide in.
        allowImplicitScrolling: true,
        physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final page = index + 1;
          return MushafPage(
            key: ValueKey(page),
            page: page,
            theme: theme,
            currentPage: _page,
            sp: scales.sp,
            h: scales.h,
            highlightColor: highlight,
            selected: page == _page.value ? selected : null,
            onTap: () => setState(() => _overlayVisible = !_overlayVisible),
            onZoomChanged: (zoomed) => setState(() => _zoomed = zoomed),
            onAyahLongPress: _onAyahLongPress,
          );
        },
      ),
    );
  }
}

/// Arabic-Indic and Persian digits → ASCII, for the go-to-page field.
String _westernDigits(String input) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  final out = StringBuffer();
  for (final ch in input.split('')) {
    final a = arabic.indexOf(ch);
    final p = persian.indexOf(ch);
    out.write(a >= 0 ? '$a' : (p >= 0 ? '$p' : ch));
  }
  return out.toString();
}
