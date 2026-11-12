import 'package:qcf_quran/qcf_quran.dart';
import '../../../../../core/design/design.dart';
import '../../../../../core/localization/tr.dart';
import '../../domain/mushaf_meta.dart';

/// Header (surah, juz', actions) and footer (page number) over the Mushaf.
/// Coloured from the page theme so it reads as part of the paper.
class MushafOverlay extends StatelessWidget {
  const MushafOverlay({
    super.key,
    required this.visible,
    required this.page,
    required this.theme,
    required this.bookmarked,
    required this.onBack,
    required this.onIndex,
    required this.onGoToPage,
    required this.onToggleBookmark,
    required this.onChooseTheme,
  });

  final bool visible;
  final int page;
  final QcfThemeData theme;
  final bool bookmarked;
  final VoidCallback onBack;
  final VoidCallback onIndex;
  final VoidCallback onGoToPage;
  final VoidCallback onToggleBookmark;
  final VoidCallback onChooseTheme;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final surah = MushafMeta.surahOf(page);
    final juz = MushafMeta.juzOf(page);
    final bar = theme.pageBackgroundColor.withValues(alpha: 0.96);
    final ink = theme.verseTextColor;
    final edge = BorderSide(
        color: theme.verseNumberColor.withValues(alpha: 0.25),
        width: AppSpacing.hairline);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppMotion.of(context, AppMotion.fast),
        child: Column(
          children: [
            DecoratedBox(
              decoration:
                  BoxDecoration(color: bar, border: Border(bottom: edge)),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.xs, media.padding.top, AppSpacing.xs, 0),
                // 52 tall, taller when large text needs the room for the
                // surah and juz' lines.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Row(
                    children: [
                      AppIconButton(
                        icon: CupertinoIcons.back,
                        label: context.tr('رجوع', 'Back'),
                        color: ink,
                        onPressed: onBack,
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('سورة ${MushafMeta.surahName(surah)}',
                                  MushafMeta.surahNameLatin(surah)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  AppTypography.headline.copyWith(color: ink),
                            ),
                            Text(
                              context.tr('الجزء $juz', 'Juz\' $juz'),
                              style: AppTypography.caption1
                                  .copyWith(color: ink.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      ),
                      AppIconButton(
                        icon: CupertinoIcons.list_bullet,
                        label: context.tr('الفهرس', 'Index'),
                        color: ink,
                        onPressed: onIndex,
                      ),
                      AppIconButton(
                        icon: CupertinoIcons.number,
                        label: context.tr('الانتقال إلى صفحة', 'Go to page'),
                        color: ink,
                        onPressed: onGoToPage,
                      ),
                      AppIconButton(
                        icon: CupertinoIcons.circle_lefthalf_fill,
                        label: context.tr('مظهر المصحف', 'Mushaf appearance'),
                        color: ink,
                        onPressed: onChooseTheme,
                      ),
                      AppIconButton(
                        icon: bookmarked
                            ? CupertinoIcons.bookmark_fill
                            : CupertinoIcons.bookmark,
                        label: bookmarked
                            ? context.tr('إزالة العلامة', 'Remove bookmark')
                            : context.tr('إضافة علامة', 'Bookmark page'),
                        color: bookmarked ? theme.verseNumberColor : ink,
                        onPressed: onToggleBookmark,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            DecoratedBox(
              decoration: BoxDecoration(color: bar, border: Border(top: edge)),
              child: Padding(
                padding: EdgeInsets.only(
                    top: AppSpacing.sm,
                    bottom: media.padding.bottom + AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Rhombus(color: theme.verseNumberColor),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      context.tr('صفحة $page من ${MushafMeta.pageCount}',
                          'Page $page of ${MushafMeta.pageCount}'),
                      textAlign: TextAlign.center,
                      style: AppTypography.tabular(AppTypography.footnote)
                          .copyWith(color: ink),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _Rhombus(color: theme.verseNumberColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small gilded rhombus either side of the page number, as printed
/// Mushafs mark their folios.
class _Rhombus extends StatelessWidget {
  const _Rhombus({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: 0.785398, // 45°
        child: Container(
          width: 5,
          height: 5,
          color: color,
        ),
      ),
    );
  }
}
