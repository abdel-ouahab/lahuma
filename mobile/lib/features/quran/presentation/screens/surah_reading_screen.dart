import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../../../core/widgets/lahuma_icon_button.dart';
import '../../../bookmarks/domain/bookmark.dart';
import '../../../bookmarks/presentation/bookmarks_providers.dart';
import '../../../dedication/presentation/dedication_labels.dart';
import '../../../dedication/presentation/dedication_providers.dart';
import '../../../notes/presentation/notes_providers.dart';
import '../../../reading_progress/presentation/reading_progress_providers.dart';
import '../../../settings/data/settings_repository.dart';
import '../../../settings/presentation/settings_providers.dart';
import '../../domain/ayah.dart';
import '../../domain/surah_detail.dart';
import '../providers/ayah_audio_provider.dart';
import '../providers/quran_providers.dart';
import '../widgets/ayah_action_sheet.dart';
import '../widgets/ayah_note_dialog.dart';
import '../widgets/ayah_text_sheet.dart';
import '../widgets/ayah_widget.dart';
import '../widgets/reader_options_sheet.dart';
import '../widgets/surah_header.dart';

class SurahReadingScreen extends ConsumerWidget {
  const SurahReadingScreen({
    super.key,
    required this.surahNumber,
    this.initialAyah = 1,
  });

  final int surahNumber;

  /// Ayah to open at (from "continue reading", a bookmark, or a juz).
  final int initialAyah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(surahDetailProvider(surahNumber));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: detailAsync.when(
          data: (detail) => _SurahBody(
            key: ValueKey(detail.number),
            detail: detail,
            initialAyah: initialAyah,
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ),
          error: (e, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: LahumaIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    tooltip: context.tr('رجوع', 'Back'),
                    onTap: () => _leave(context),
                  ),
                ),
              ),
              Expanded(
                child: ErrorRetry(
                  error: e,
                  onRetry: () =>
                      ref.invalidate(surahDetailProvider(surahNumber)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _leave(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/quran');
  }
}

class _SurahBody extends ConsumerStatefulWidget {
  const _SurahBody(
      {super.key, required this.detail, required this.initialAyah});

  final SurahDetail detail;
  final int initialAyah;

  @override
  ConsumerState<_SurahBody> createState() => _SurahBodyState();
}

class _SurahBodyState extends ConsumerState<_SurahBody> {
  final _scroll = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  final _offset = ScrollOffsetController();
  late final ReadingTracker _tracker;
  Timer? _debounce;
  int? _pendingAyah;

  /// Auto-scroll: [_autoScroll] shows the controls, [_autoPaused] holds the
  /// motion (user dragged, or reached the end). [_autoRun] cancels old loops.
  bool _autoScroll = false;
  bool _autoPaused = false;
  int _autoRun = 0;
  double _extentAfter = double.infinity;

  SurahDetail get _detail => widget.detail;
  int get _count => _detail.ayahs.length;

  /// Index of the closing dua at the end of the list.
  int get _footerIndex => _count + 1;

  @override
  void initState() {
    super.initState();
    _tracker = ref.read(readingTrackerProvider);
    _tracker.begin(_detail.number, _startAyah);
    _positions.itemPositions.addListener(_onPositions);
    // Opening a surah counts as "last read" even before the first scroll.
    WidgetsBinding.instance.addPostFrameCallback((_) => _report(_startAyah));
  }

  int get _startAyah => widget.initialAyah.clamp(1, _count);

  @override
  void dispose() {
    _autoRun++;
    _positions.itemPositions.removeListener(_onPositions);
    _debounce?.cancel();
    final pending = _pendingAyah;
    if (pending != null) _report(pending);
    super.dispose();
  }

  void _report(int ayah) {
    _tracker.onAyahVisible(
      surah: _detail.number,
      surahName: _detail.arabicName,
      ayah: ayah,
      totalAyahs: _count,
    );
  }

  void _onPositions() {
    final visible = _positions.itemPositions.value;
    if (visible.isEmpty) return;

    int ayah;
    if (visible
        .any((p) => p.index == _footerIndex && p.itemLeadingEdge < 0.9)) {
      // The closing dua is on screen: every ayah has been read.
      ayah = _count + 1;
    } else {
      final top = visible
          .where((p) => p.itemTrailingEdge > 0.12)
          .map((p) => p.index)
          .fold<int?>(null, (m, i) => m == null || i < m ? i : m);
      ayah = ((top ?? 1).clamp(1, _count)).toInt();
    }

    _pendingAyah = ayah;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      final p = _pendingAyah;
      _pendingAyah = null;
      if (p != null) _report(p);
    });
  }

  void _scrollToAyah(int ayah, {bool animate = true}) {
    if (!_scroll.isAttached) return;
    final index = ayah <= 1 ? 0 : ayah;
    if (animate) {
      _scroll.scrollTo(
        index: index,
        alignment: 0.02,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _scroll.jumpTo(index: index, alignment: 0.02);
    }
  }

  // ── Auto-scroll ───────────────────────────────────────────────────────────

  static const _autoStep = Duration(milliseconds: 400);

  /// Speed level 1–10 → pixels per second.
  static double _pixelsPerSecond(int level) => level * 12.0;

  void _startAutoScroll() {
    setState(() {
      _autoScroll = true;
      _autoPaused = false;
    });
    _runAutoScroll();
  }

  void _pauseAutoScroll() {
    _autoRun++;
    if (mounted) setState(() => _autoPaused = true);
  }

  void _resumeAutoScroll() {
    if (_extentAfter < 1) return;
    setState(() => _autoPaused = false);
    _runAutoScroll();
  }

  void _stopAutoScroll() {
    _autoRun++;
    setState(() {
      _autoScroll = false;
      _autoPaused = false;
    });
  }

  /// Chains short linear animations so the text glides at a steady pace.
  Future<void> _runAutoScroll() async {
    final run = ++_autoRun;
    while (mounted && run == _autoRun && _scroll.isAttached) {
      final step = _pixelsPerSecond(ref.read(autoScrollSpeedProvider)) *
          _autoStep.inMilliseconds /
          1000;
      final offset = step < _extentAfter ? step : _extentAfter;
      if (offset < 1) {
        _pauseAutoScroll();
        return;
      }
      try {
        await _offset.animateScroll(
          offset: offset,
          duration: _autoStep,
          curve: Curves.linear,
        );
      } catch (_) {
        return;
      }
    }
  }

  bool _onScrollNotification(ScrollNotification n) {
    _extentAfter = n.metrics.extentAfter;
    // A finger on the page takes over from auto-scroll.
    if (_autoScroll &&
        !_autoPaused &&
        n is ScrollStartNotification &&
        n.dragDetails != null) {
      _pauseAutoScroll();
    }
    return false;
  }

  void _changeSpeed(int delta) {
    final current = ref.read(autoScrollSpeedProvider);
    ref.read(autoScrollSpeedProvider.notifier).update(current + delta);
  }

  // ── Ayah actions ──────────────────────────────────────────────────────────

  void _toggleBookmark(Ayah ayah, bool isBookmarked) {
    final notifier = ref.read(bookmarksProvider.notifier);
    if (isBookmarked) {
      notifier.remove(_detail.number, ayah.numberInSurah);
    } else {
      notifier.add(Bookmark(
        surahId: _detail.number,
        ayahNumber: ayah.numberInSurah,
        surahName: _detail.arabicName,
        createdAt: DateTime.now(),
      ));
    }
  }

  Future<void> _togglePlay(Ayah ayah) async {
    final audio = ref.read(ayahAudioProvider.notifier);
    final current = ref.read(ayahAudioProvider);
    if (current != null &&
        current.surah == _detail.number &&
        current.ayah == ayah.numberInSurah) {
      current.playing ? await audio.pause() : await audio.resume();
      return;
    }
    try {
      await audio.playFrom(_detail, ayah.numberInSurah);
    } catch (_) {
      if (mounted) {
        _snack(context.tr('تعذّر تشغيل التلاوة. تحقق من الاتصال بالإنترنت.',
            'Could not play the recitation. Check your internet connection.'));
      }
    }
  }

  String _shareText(Ayah ayah) =>
      '﴿${ayah.text}﴾\n[${_detail.arabicName}: ${ayah.numberInSurah}]';

  Future<void> _share(Ayah ayah) async {
    await SharePlus.instance.share(ShareParams(text: _shareText(ayah)));
  }

  Future<void> _copy(Ayah ayah) async {
    await Clipboard.setData(ClipboardData(text: _shareText(ayah)));
    if (mounted) _snack(context.tr('تم نسخ الآية', 'Ayah copied'));
  }

  Future<void> _editNote(Ayah ayah) async {
    final notes = ref.read(notesProvider.notifier);
    final text = await showAyahNoteDialog(
      context,
      surahName: _detail.arabicName,
      ayahNumber: ayah.numberInSurah,
      initial: notes.noteFor(_detail.number, ayah.numberInSurah),
    );
    if (text != null) {
      await notes.setNote(_detail.number, ayah.numberInSurah, text);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _openActions(Ayah ayah, bool isBookmarked, bool hasNote) {
    final number = ayah.numberInSurah;
    AyahActionSheet.show(
      context,
      surahName: _detail.arabicName,
      ayahNumber: number,
      isBookmarked: isBookmarked,
      hasNote: hasNote,
      onPlay: () => _togglePlay(ayah),
      onBookmark: () => _toggleBookmark(ayah, isBookmarked),
      onShare: () => _share(ayah),
      onCopy: () => _copy(ayah),
      onNote: () => _editNote(ayah),
      onTafseer: () => AyahTextSheet.show(
        context,
        title:
            '${context.tr('التفسير الميسّر', 'Tafsir al-Muyassar')} · ${_detail.arabicName}',
        ayahNumber: number,
        provider: tafsirProvider(_detail.number),
        rtl: true,
      ),
      onTranslation: () => AyahTextSheet.show(
        context,
        title:
            '${context.tr('الترجمة الإنجليزية', 'English translation')} · ${_detail.arabicName}',
        ayahNumber: number,
        provider: translationProvider(_detail.number),
        rtl: false,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fontSize = ref.watch(readerFontSizeProvider);
    final showTranslation = ref.watch(showTranslationProvider);
    final translationAsync =
        showTranslation ? ref.watch(translationProvider(_detail.number)) : null;
    final notes = ref.watch(notesProvider);
    final bookmarks = ref.watch(bookmarksProvider);
    final playback = ref.watch(ayahAudioProvider);

    ref.listen(ayahAudioProvider, (prev, next) {
      if (next != null &&
          next.surah == _detail.number &&
          prev?.ayah != next.ayah) {
        _scrollToAyah(next.ayah);
      }
    });

    return Column(
      children: [
        // ── Top bar (stays put while reading) ────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
          child: Row(
            children: [
              LahumaIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: context.tr('رجوع', 'Back'),
                onTap: () => _leave(context),
              ),
              const Spacer(),
              Text(
                _detail.arabicName,
                style: GoogleFonts.scheherazadeNew(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textDark : AppColors.textLight,
                ),
              ),
              const Spacer(),
              LahumaIconButton(
                icon: Icons.keyboard_double_arrow_down_rounded,
                tooltip: context.tr('التمرير التلقائي', 'Auto-scroll'),
                onTap: _autoScroll ? _stopAutoScroll : _startAutoScroll,
              ),
              LahumaIconButton(
                icon: Icons.text_fields_rounded,
                tooltip: context.tr('خيارات القراءة', 'Reading options'),
                onTap: () => ReaderOptionsSheet.show(
                  context,
                  ayahCount: _count,
                  onJump: _scrollToAyah,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: ScrollablePositionedList.builder(
                  itemScrollController: _scroll,
                  itemPositionsListener: _positions,
                  scrollOffsetController: _offset,
                  initialScrollIndex: _startAyah <= 1 ? 0 : _startAyah,
                  initialAlignment: _startAyah <= 1 ? 0 : 0.02,
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: _count + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _Header(
                        detail: _detail,
                        translationFailed: translationAsync?.hasError ?? false,
                      );
                    }
                    if (index == _footerIndex) {
                      return _Footer(detail: _detail);
                    }

                    final ayah = _detail.ayahs[index - 1];
                    final isBookmarked = bookmarks.any((b) =>
                        b.surahId == _detail.number &&
                        b.ayahNumber == ayah.numberInSurah);
                    final note =
                        notes['${_detail.number}:${ayah.numberInSurah}'];
                    final isPlaying = playback != null &&
                        playback.surah == _detail.number &&
                        playback.ayah == ayah.numberInSurah &&
                        playback.playing;

                    return AyahWidget(
                      ayah: ayah,
                      surahNumber: _detail.number,
                      fontSize: fontSize,
                      translation:
                          translationAsync?.valueOrNull?[ayah.numberInSurah],
                      note: note,
                      isBookmarked: isBookmarked,
                      isPlaying: isPlaying,
                      onPlayToggle: () => _togglePlay(ayah),
                      onBookmarkToggle: () =>
                          _toggleBookmark(ayah, isBookmarked),
                      onShare: () => _share(ayah),
                      onTap: () =>
                          _openActions(ayah, isBookmarked, note != null),
                    );
                  },
                ),
              ),
              PositionedDirectional(
                start: AppSpacing.lg,
                end: AppSpacing.lg,
                bottom: AppSpacing.md,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _autoScroll
                      ? _AutoScrollBar(
                          speed: ref.watch(autoScrollSpeedProvider),
                          paused: _autoPaused,
                          onPlayPause: _autoPaused
                              ? _resumeAutoScroll
                              : _pauseAutoScroll,
                          onSlower: () => _changeSpeed(-1),
                          onFaster: () => _changeSpeed(1),
                          onClose: _stopAutoScroll,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Floating controls while auto-scrolling: pause/resume, speed −/+, close.
class _AutoScrollBar extends StatelessWidget {
  const _AutoScrollBar({
    required this.speed,
    required this.paused,
    required this.onPlayPause,
    required this.onSlower,
    required this.onFaster,
    required this.onClose,
  });

  final int speed;
  final bool paused;
  final VoidCallback onPlayPause;
  final VoidCallback onSlower;
  final VoidCallback onFaster;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? AppColors.textDark : AppColors.textLight;
    final muted = isDark ? AppColors.mutedDark : AppColors.mutedLight;

    Widget button(IconData icon, String tooltip, VoidCallback? onTap,
        {Color? color}) {
      return IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        icon: Icon(icon, size: 22),
        color: color ?? text,
        disabledColor: muted,
      );
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color:
              isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(
              paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              paused
                  ? context.tr('متابعة', 'Resume')
                  : context.tr('إيقاف مؤقت', 'Pause'),
              onPlayPause,
              color: AppColors.primary,
            ),
            button(
              Icons.remove_rounded,
              context.tr('أبطأ', 'Slower'),
              speed > SettingsRepository.minAutoScrollSpeed ? onSlower : null,
            ),
            Semantics(
              label: context.tr('السرعة $speed', 'Speed $speed'),
              child: SizedBox(
                width: 48,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$speed',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: text,
                      ),
                    ),
                    Text(
                      context.tr('السرعة', 'Speed'),
                      style: GoogleFonts.cairo(
                          fontSize: 10, height: 1.1, color: muted),
                    ),
                  ],
                ),
              ),
            ),
            button(
              Icons.add_rounded,
              context.tr('أسرع', 'Faster'),
              speed < SettingsRepository.maxAutoScrollSpeed ? onFaster : null,
            ),
            button(Icons.close_rounded, context.tr('إغلاق', 'Close'), onClose,
                color: muted),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail, required this.translationFailed});

  final SurahDetail detail;
  final bool translationFailed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meccan = detail.revelationType.toLowerCase() == 'meccan';
    final meta =
        '${meccan ? context.tr('مكية', 'Meccan') : context.tr('مدنية', 'Medinan')}'
        ' • ${context.tr('${detail.numberOfAyahs} آية', '${detail.numberOfAyahs} ayahs')}';

    return Column(
      children: [
        const SizedBox(height: AppSpacing.sm),
        SurahHeader(
          surahNumber: detail.number,
          arabicName: detail.arabicName,
          englishName: detail.englishName,
          meta: meta,
        ),
        if (detail.number != 9)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                textAlign: TextAlign.center,
                style: GoogleFonts.scheherazadeNew(
                  fontSize: 24,
                  height: 2.0,
                  color: isDark ? AppColors.textDark : AppColors.inkDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (translationFailed)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              context.tr('الترجمة غير متاحة الآن. تحقق من الاتصال بالإنترنت.',
                  'The translation is unavailable right now. Check your connection.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: isDark ? AppColors.mutedDark : AppColors.mutedLight,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// End of the surah: the reader's dedication dua, then a way onward.
class _Footer extends ConsumerWidget {
  const _Footer({required this.detail});

  final SurahDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dedication = ref.watch(dedicationProvider);
    final hasNext = detail.number < 114;

    return Padding(
      padding:
          const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xxl),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color:
                  isDark ? AppColors.surfaceElevatedDark : AppColors.cardMint,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              children: [
                const Icon(Icons.favorite_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  dedication.target.dua(context),
                  textAlign: TextAlign.center,
                  style: context.isArabic
                      ? GoogleFonts.scheherazadeNew(
                          fontSize: 20,
                          height: 1.8,
                          color:
                              isDark ? AppColors.textDark : AppColors.inkDark)
                      : GoogleFonts.cairo(
                          fontSize: 14,
                          height: 1.6,
                          color:
                              isDark ? AppColors.textDark : AppColors.inkDark),
                ),
                if (dedication.names.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    dedication.names.trim(),
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasNext) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    context.pushReplacement('/quran/${detail.number + 1}'),
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: Text(context.tr('السورة التالية', 'Next surah')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
