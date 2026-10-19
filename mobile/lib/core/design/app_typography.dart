import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Lahuma design tokens — typography (HIG text styles).
///
/// | Style       | Size | Weight   |
/// |-------------|------|----------|
/// | largeTitle  | 34   | bold     |
/// | title1      | 28   | bold     |
/// | title2      | 22   | bold     |
/// | title3      | 20   | semibold |
/// | headline    | 17   | semibold |
/// | body        | 17   | regular  |
/// | callout     | 16   | regular  |
/// | subheadline | 15   | regular  |
/// | footnote    | 13   | regular  |
/// | caption1    | 12   | regular  |
/// | caption2    | 11   | regular  |
///
/// Fonts: titles (largeTitle…title3) use the brand Arabic font, Cairo.
/// Everything from headline down uses the system font on Apple platforms
/// (SF Pro, with SF Arabic for Arabic glyphs) and Cairo elsewhere, where the
/// platform font has no iOS feel. Quran text always uses Scheherazade New.
///
/// Styles carry no colour (they inherit `label` from the theme); apply a
/// palette colour with `copyWith(color: context.palette.secondaryLabel)`.
/// Sizes are in logical points and scale with the system text size
/// (Dynamic Type) — never put them in fixed-height boxes.
///
/// Letter-spacing stays 0: tracking breaks the joins of Arabic script.
class AppTypography {
  AppTypography._();

  static bool get _systemFont =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static TextStyle _brand(double size, FontWeight weight, double height) =>
      GoogleFonts.cairo(fontSize: size, fontWeight: weight, height: height);

  static TextStyle _text(double size, FontWeight weight, double cairoHeight) =>
      _systemFont
          ? TextStyle(
              fontFamily:
                  size >= 20 ? 'CupertinoSystemDisplay' : 'CupertinoSystemText',
              fontSize: size,
              fontWeight: weight,
            )
          : _brand(size, weight, cairoHeight);

  // ─── HIG scale ───────────────────────────────────────────────────────────
  static TextStyle get largeTitle => _brand(34, FontWeight.w700, 1.2);
  static TextStyle get title1 => _brand(28, FontWeight.w700, 1.25);
  static TextStyle get title2 => _brand(22, FontWeight.w700, 1.3);
  static TextStyle get title3 => _brand(20, FontWeight.w600, 1.3);
  static TextStyle get headline => _text(17, FontWeight.w600, 1.4);
  static TextStyle get body => _text(17, FontWeight.w400, 1.45);
  static TextStyle get callout => _text(16, FontWeight.w400, 1.45);
  static TextStyle get subheadline => _text(15, FontWeight.w400, 1.4);
  static TextStyle get footnote => _text(13, FontWeight.w400, 1.4);
  static TextStyle get caption1 => _text(12, FontWeight.w400, 1.35);
  static TextStyle get caption2 => _text(11, FontWeight.w400, 1.3);

  // ─── Quran ───────────────────────────────────────────────────────────────
  /// Quranic Arabic. [size] is usually the reader-size setting.
  static TextStyle quran({
    double size = 26,
    FontWeight weight = FontWeight.w400,
    double height = 2.0,
  }) =>
      GoogleFonts.scheherazadeNew(
        fontSize: size,
        fontWeight: weight,
        height: height,
      );

  // ─── Helpers ─────────────────────────────────────────────────────────────
  /// Monospaced digits for counters, timers and percentages.
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Text theme for [CupertinoThemeData]. Colours are dynamic tokens; the
  /// theme resolves them for the current brightness.
  static CupertinoTextThemeData get cupertinoTextTheme {
    final picker =
        _text(21, FontWeight.w400, 1.3).copyWith(color: AppColors.label);
    return CupertinoTextThemeData(
      primaryColor: AppColors.accent,
      textStyle: body.copyWith(
        color: AppColors.label,
        decoration: TextDecoration.none,
      ),
      actionTextStyle: body.copyWith(color: AppColors.accent),
      actionSmallTextStyle: subheadline.copyWith(color: AppColors.accent),
      navActionTextStyle: body.copyWith(color: AppColors.accent),
      navTitleTextStyle: headline.copyWith(color: AppColors.label),
      navLargeTitleTextStyle: largeTitle.copyWith(color: AppColors.label),
      tabLabelTextStyle: caption2
          .weight(FontWeight.w500)
          .copyWith(color: CupertinoColors.inactiveGray),
      pickerTextStyle: picker,
      dateTimePickerTextStyle: picker,
    );
  }
}

extension AppTextStyleWeight on TextStyle {
  /// Returns this style at [weight].
  ///
  /// Use this instead of `copyWith(fontWeight: …)`: google_fonts registers one
  /// font family per weight (`Cairo_regular`, `Cairo_700`, …), so changing
  /// only `fontWeight` would synthesise a fake bold from the regular file.
  TextStyle weight(FontWeight weight) {
    final family = fontFamily ?? '';
    if (family.startsWith('Cairo')) {
      return GoogleFonts.cairo(textStyle: this, fontWeight: weight);
    }
    if (family.startsWith('ScheherazadeNew')) {
      return GoogleFonts.scheherazadeNew(textStyle: this, fontWeight: weight);
    }
    return copyWith(fontWeight: weight);
  }
}
