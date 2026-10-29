import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/design/design.dart';
import '../../../../../core/localization/tr.dart';
import '../../domain/mushaf_meta.dart';
import '../mushaf_providers.dart';

enum _IndexTab { surahs, juz, bookmarks }

/// Surah / juz' / bookmark index of the Mushaf. Pops with the chosen page.
class MushafIndexScreen extends ConsumerStatefulWidget {
  const MushafIndexScreen({super.key, this.currentPage});

  /// The page the reader is on; its surah and juz' are marked.
  final int? currentPage;

  @override
  ConsumerState<MushafIndexScreen> createState() => _MushafIndexScreenState();
}

class _MushafIndexScreenState extends ConsumerState<MushafIndexScreen> {
  _IndexTab _tab = _IndexTab.surahs;

  @override
  Widget build(BuildContext context) {
    final current = widget.currentPage;
    return AppScaffold.largeTitle(
      title: context.tr('فهرس المصحف', 'Mushaf index'),
      bottom: AppNavBarBottom(
        child: AppSegmentedControl<_IndexTab>(
          segments: {
            _IndexTab.surahs: context.tr('السور', 'Surahs'),
            _IndexTab.juz: context.tr('الأجزاء', 'Juz\''),
            _IndexTab.bookmarks: context.tr('العلامات', 'Bookmarks'),
          },
          value: _tab,
          onChanged: (tab) => setState(() => _tab = tab),
        ),
      ),
      slivers: [
        ...switch (_tab) {
          _IndexTab.surahs => [
              _section(context, [
                for (var s = 1; s <= MushafMeta.surahCount; s++)
                  _SurahRow(
                    surah: s,
                    current: current != null &&
                        MushafMeta.surahsOn(current).any((p) => p.surah == s),
                  ),
              ]),
            ],
          _IndexTab.juz => [
              _section(context, [
                for (var j = 1; j <= MushafMeta.juzCount; j++)
                  _JuzRow(
                    juz: j,
                    current: current != null && MushafMeta.juzOf(current) == j,
                  ),
              ]),
            ],
          _IndexTab.bookmarks => _bookmarks(context),
        },
        SliverToBoxAdapter(
          child: SizedBox(
              height: MediaQuery.paddingOf(context).bottom + AppSpacing.md),
        ),
      ],
    );
  }

  Widget _section(BuildContext context, List<Widget> rows) =>
      SliverToBoxAdapter(
        // Keyed by tab so switching tabs plays the entrance again.
        child: AppListSection(
            key: ValueKey(_tab),
            hasLeading: true,
            children: rows.listEntrance()),
      );

  List<Widget> _bookmarks(BuildContext context) {
    final bookmarks = ref.watch(mushafProvider).bookmarks;
    if (bookmarks.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
            icon: CupertinoIcons.bookmark,
            title: context.tr('لا توجد علامات بعد', 'No bookmarks yet'),
            message: context.tr(
              'اضغط على أيقونة العلامة أعلى الصفحة لحفظها هنا.',
              'Tap the bookmark icon at the top of a page to save it here.',
            ),
          ),
        ),
      ];
    }
    return [
      _section(context, [
        for (final b in bookmarks)
          AppListTile(
            leading: _NumberBadge(b.page),
            title: context.tr('صفحة ${b.page}', 'Page ${b.page}'),
            subtitle: context.tr(
              'سورة ${MushafMeta.surahName(MushafMeta.surahOf(b.page))} · الجزء ${MushafMeta.juzOf(b.page)}',
              '${MushafMeta.surahNameLatin(MushafMeta.surahOf(b.page))} · Juz\' ${MushafMeta.juzOf(b.page)}',
            ),
            onTap: () => context.pop(b.page),
            trailing: AppIconButton(
              icon: CupertinoIcons.trash,
              label: context.tr('حذف العلامة', 'Delete bookmark'),
              color: context.palette.destructive,
              onPressed: () =>
                  ref.read(mushafProvider.notifier).removeBookmark(b.page),
            ),
          ),
      ]),
    ];
  }
}

class _SurahRow extends StatelessWidget {
  const _SurahRow({required this.surah, required this.current});

  final int surah;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final page = MushafMeta.surahStartPage(surah);
    final ayahs = MushafMeta.ayahCount(surah);
    final makki = MushafMeta.isMakki(surah);
    return AppListTile(
      leading: _NumberBadge(surah, highlighted: current),
      title: MushafMeta.surahName(surah),
      subtitle: context.tr(
        '${makki ? 'مكية' : 'مدنية'} · $ayahs ${ayahs <= 10 ? 'آيات' : 'آية'}',
        '${MushafMeta.surahNameLatin(surah)} · ${makki ? 'Meccan' : 'Medinan'} · $ayahs ayahs',
      ),
      value: context.tr('ص $page', 'p. $page'),
      onTap: () => context.pop(page),
    );
  }
}

class _JuzRow extends StatelessWidget {
  const _JuzRow({required this.juz, required this.current});

  final int juz;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final page = MushafMeta.juzStartPage(juz);
    final surah = MushafMeta.juzStartSurah(juz);
    return AppListTile(
      leading: _NumberBadge(juz, highlighted: current),
      title: context.tr('الجزء $juz', 'Juz\' $juz'),
      subtitle: context.tr('يبدأ في سورة ${MushafMeta.surahName(surah)}',
          'Starts in ${MushafMeta.surahNameLatin(surah)}'),
      value: context.tr('ص $page', 'p. $page'),
      onTap: () => context.pop(page),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge(this.number, {this.highlighted = false});

  final int number;

  /// The reader's current surah / juz'.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return MediaQuery.withNoTextScaling(
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: highlighted ? c.accent : c.accentTint,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$number',
          style: AppTypography.tabular(AppTypography.caption1).copyWith(
            fontWeight: FontWeight.w600,
            color: highlighted ? c.onAccent : c.accent,
          ),
        ),
      ),
    );
  }
}
