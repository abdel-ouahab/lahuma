import 'package:qcf_quran/qcf_quran.dart';
import '../../../../../core/design/design.dart';

/// The Mushaf's three page styles (white, paper, night) as qcf_quran themes.
///
/// Built once: MushafPage only rebuilds its text when the theme changes.
class MushafThemes {
  MushafThemes._();

  static const QcfThemeData white = QcfThemeData(
    pageBackgroundColor: AppColors.mushafWhitePage,
    verseTextColor: AppColors.mushafWhiteInk,
    basmalaColor: AppColors.mushafWhiteInk,
    headerTextColor: AppColors.mushafWhiteInk,
    verseNumberColor: AppColors.mushafWhiteMarker,
    customHeaderBuilder: _lightHeader,
  );

  static const QcfThemeData paper = QcfThemeData(
    pageBackgroundColor: AppColors.mushafPaperPage,
    verseTextColor: AppColors.mushafPaperInk,
    basmalaColor: AppColors.mushafPaperInk,
    headerTextColor: AppColors.mushafPaperInk,
    verseNumberColor: AppColors.mushafPaperMarker,
    customHeaderBuilder: _paperHeader,
  );

  static const QcfThemeData night = QcfThemeData(
    pageBackgroundColor: AppColors.mushafNightPage,
    verseTextColor: AppColors.mushafNightInk,
    basmalaColor: AppColors.mushafNightInk,
    headerTextColor: AppColors.mushafNightMarker,
    verseNumberColor: AppColors.mushafNightMarker,
    customHeaderBuilder: _nightHeader,
  );

  static Widget _lightHeader(int surah) => MushafSurahHeader(
      surah: surah, nameColor: AppColors.mushafWhiteInk);
  static Widget _paperHeader(int surah) => MushafSurahHeader(
      surah: surah, nameColor: AppColors.mushafPaperInk);
  static Widget _nightHeader(int surah) => MushafSurahHeader(
      surah: surah,
      nameColor: AppColors.mushafNightFrameLine,
      night: true);
}

/// The surah title cartouche at the start of each surah: qcf_quran's
/// illuminated frame with the surah name in the QCF surah-name font.
///
/// The frame is drawn in cream, which swallows light text on a night page,
/// so at night it is recoloured as a duotone: its dark strokes become gold
/// and its cream fill a deep green panel, a gilded frame on the night page.
class MushafSurahHeader extends StatelessWidget {
  const MushafSurahHeader({
    super.key,
    required this.surah,
    required this.nameColor,
    this.night = false,
  });

  final int surah;
  final Color nameColor;
  final bool night;

  // Luminance of the frame's darkest stroke and of its cream fill; the
  // duotone stretches this range from line colour to panel colour.
  static const double _strokeLuminance = 0.40;
  static const double _fillLuminance = 0.86;

  static final ColorFilter _nightFilter = _duotone(
      AppColors.mushafNightFrameLine, AppColors.mushafNightFramePanel);

  static ColorFilter _duotone(Color line, Color panel) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    const span = _fillLuminance - _strokeLuminance;
    List<double> row(double from, double to) {
      final k = (to - from) / span; // per unit of luminance (0–1)
      final offset = from * 255 - k * _strokeLuminance * 255;
      return [k * lr, k * lg, k * lb, 0, offset];
    }

    return ColorFilter.matrix([
      ...row(line.r, panel.r),
      ...row(line.g, panel.g),
      ...row(line.b, panel.b),
      0, 0, 0, 1, 0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // Same sizes as qcf_quran's own header, so pages keep their line breaks.
    const theme = QcfThemeData();
    final media = MediaQuery.of(context);
    final portrait = media.orientation == Orientation.portrait;
    final large = getScreenType(context) == ScreenType.large;
    final width = portrait
        ? (large ? theme.headerWidthLarge : theme.headerWidthSmall)
        : media.size.width * 0.8;
    final fontSize = portrait
        ? (large ? theme.headerFontSizeLarge : theme.headerFontSizeSmall)
        : media.size.width * 0.05;

    Widget frame = Image(
      image: const AssetImage('assets/mainframe.png', package: 'qcf_quran'),
      width: width,
    );
    if (night) frame = ColorFiltered(colorFilter: _nightFilter, child: frame);

    return Semantics(
      header: true,
      label: getSurahNameArabic(surah),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            frame,
            ExcludeSemantics(
              child: Text(
                'surah${surah.toString().padLeft(3, '0')}',
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: SurahFontHelper.fontFamily,
                  package: 'qcf_quran',
                  fontSize: fontSize,
                  color: nameColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
