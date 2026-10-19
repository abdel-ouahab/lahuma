import 'package:flutter/cupertino.dart';

/// Lahuma design tokens — colour.
///
/// Surfaces and labels are iOS semantic system colours, so light / dark and
/// increased-contrast variants come for free. The brand lives in a single
/// accent (teal) and the hero gradient. This is the only file in the app that
/// may contain hex values: screens use the semantic tokens below, resolved
/// through `context.palette` (see [AppPalette]).
class AppColors {
  AppColors._();

  // ─── Accent ──────────────────────────────────────────────────────────────
  /// The one interactive colour: buttons, links, selection, active tab.
  static const CupertinoDynamicColor accent =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF14958B),
    darkColor: Color(0xFF1DA699),
  );

  /// Accent wash behind tinted buttons, selected rows and icon tiles.
  static const CupertinoDynamicColor accentTint =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x2614958B),
    darkColor: Color(0x381DA699),
  );

  /// Text / icons drawn on top of [accent].
  static const Color onAccent = Color(0xFFFFFFFF);

  // ─── Backgrounds ─────────────────────────────────────────────────────────
  static const CupertinoDynamicColor background =
      CupertinoColors.systemBackground;
  static const CupertinoDynamicColor secondaryBackground =
      CupertinoColors.secondarySystemBackground;
  static const CupertinoDynamicColor tertiaryBackground =
      CupertinoColors.tertiarySystemBackground;

  /// Page behind inset-grouped lists and cards.
  static const CupertinoDynamicColor groupedBackground =
      CupertinoColors.systemGroupedBackground;

  /// Cells and cards sitting on [groupedBackground].
  static const CupertinoDynamicColor secondaryGroupedBackground =
      CupertinoColors.secondarySystemGroupedBackground;

  /// Controls inside a grouped cell (e.g. a field inside a card).
  static const CupertinoDynamicColor tertiaryGroupedBackground =
      CupertinoColors.tertiarySystemGroupedBackground;

  /// Translucent nav / tab bar material (blurred by the bars themselves).
  static const CupertinoDynamicColor barBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xF0F9F9F9),
    darkColor: Color(0xF01D1D1D),
  );

  // ─── Labels ──────────────────────────────────────────────────────────────
  static const CupertinoDynamicColor label = CupertinoColors.label;
  static const CupertinoDynamicColor secondaryLabel =
      CupertinoColors.secondaryLabel;
  static const CupertinoDynamicColor tertiaryLabel =
      CupertinoColors.tertiaryLabel;
  static const CupertinoDynamicColor quaternaryLabel =
      CupertinoColors.quaternaryLabel;
  static const CupertinoDynamicColor placeholder =
      CupertinoColors.placeholderText;

  // ─── Lines and fills ─────────────────────────────────────────────────────
  static const CupertinoDynamicColor separator = CupertinoColors.separator;
  static const CupertinoDynamicColor opaqueSeparator =
      CupertinoColors.opaqueSeparator;
  static const CupertinoDynamicColor fill = CupertinoColors.systemFill;
  static const CupertinoDynamicColor secondaryFill =
      CupertinoColors.secondarySystemFill;
  static const CupertinoDynamicColor tertiaryFill =
      CupertinoColors.tertiarySystemFill;

  // ─── Status ──────────────────────────────────────────────────────────────
  static const CupertinoDynamicColor destructive = CupertinoColors.systemRed;
  static const CupertinoDynamicColor success = CupertinoColors.systemGreen;
  static const CupertinoDynamicColor warning = CupertinoColors.systemOrange;

  // ─── Toast / HUD (inverted capsule over content) ─────────────────────────
  static const CupertinoDynamicColor toastBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xF02C2C2E),
    darkColor: Color(0xF048484A),
  );
  static const Color toastLabel = Color(0xFFFFFFFF);

  /// Accent readable on [toastBackground] (the toast's action button).
  static const Color toastAction = Color(0xFF5CD6CB);

  // ─── Icon tiles (Settings-style coloured squares, white glyph) ───────────
  static const CupertinoDynamicColor tileBlue = CupertinoColors.systemBlue;
  static const CupertinoDynamicColor tilePurple = CupertinoColors.systemPurple;
  static const CupertinoDynamicColor tilePink = CupertinoColors.systemPink;
  static const CupertinoDynamicColor tileOrange = CupertinoColors.systemOrange;
  static const CupertinoDynamicColor tileYellow = CupertinoColors.systemYellow;
  static const CupertinoDynamicColor tileRed = CupertinoColors.systemRed;
  static const CupertinoDynamicColor tileGreen = CupertinoColors.systemGreen;

  // ─── Brand gradients ─────────────────────────────────────────────────────
  /// Hero "Continue reading" card — a single hue, slow falloff.
  static const List<Color> heroGradient = [
    Color(0xFF1AA195),
    Color(0xFF0B6B64),
  ];

  /// Splash screen.
  static const List<Color> splashGradient = [
    Color(0xFF14958B),
    Color(0xFF094F4A),
  ];

  // ─── LEGACY (pre-redesign constants) ─────────────────────────────────────
  // Kept only so screens that are not converted yet keep compiling. New code
  // must not use these; each converted screen drops them, and Phase 6 removes
  // whatever is left.
  static const Color primary = Color(0xFF14958B);
  static const Color primaryDark = Color(0xFF0E746C);
  static const Color primaryLight = Color(0xFF3DBDB1);
  static const Color primaryContainer = Color(0xFFE3F4F2);

  static const Color inkDark = Color(0xFF0F2F30);
  static const Color inkMedium = Color(0xFF4A6B6D);
  static const Color inkLight = Color(0xFF8FA6A8);

  static const Color cardTeal = Color(0xFFE3F4F2);
  static const Color cardBlue = Color(0xFFE6F0FA);
  static const Color cardPurple = Color(0xFFEEEAF8);
  static const Color cardPink = Color(0xFFF9E9F0);
  static const Color cardMint = Color(0xFFEAF6F2);

  static const Color backgroundLight = Color(0xFFF2F4F5);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFEBEEEF);
  static const Color textLight = Color(0xFF0F2F30);
  static const Color subtextLight = Color(0xFF5B7274);
  static const Color mutedLight = Color(0xFF93A5A7);
  static const Color dividerLight = Color(0xFFE1E6E7);

  static const Color backgroundDark = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF151A1B);
  static const Color surfaceElevatedDark = Color(0xFF1F2627);
  static const Color textDark = Color(0xFFF2F7F7);
  static const Color subtextDark = Color(0xFF9DB1B3);
  static const Color mutedDark = Color(0xFF6A7E80);
  static const Color dividerDark = Color(0xFF273031);

  static const Color ayahNumberBg = Color(0xFF14958B);
  static const Color ayahNumberText = Color(0xFFFFFFFF);
  static const Color translationText = Color(0xFF6F8A8C);

  static const Color bookmarkActive = Color(0xFF14958B);
  static const Color bookmarkInactive = Color(0xFFB8C7C9);
  static const Color error = Color(0xFFE5484D);
}

/// Semantic colours resolved for the current brightness / contrast.
///
/// ```dart
/// final c = context.palette;
/// Container(color: c.secondaryGroupedBackground, child: Text('…', style: TextStyle(color: c.label)));
/// ```
///
/// Cupertino widgets resolve [CupertinoDynamicColor]s themselves; anything
/// else (Container, BoxDecoration, Icon, TextStyle) must get a resolved colour.
class AppPalette {
  const AppPalette._(this._context);

  final BuildContext _context;

  Color _r(Color c) => CupertinoDynamicColor.resolve(c, _context);

  /// Resolves any (possibly dynamic) colour against this context.
  Color resolve(Color color) => _r(color);

  Color get accent => _r(AppColors.accent);
  Color get accentTint => _r(AppColors.accentTint);
  Color get onAccent => AppColors.onAccent;

  Color get background => _r(AppColors.background);
  Color get secondaryBackground => _r(AppColors.secondaryBackground);
  Color get tertiaryBackground => _r(AppColors.tertiaryBackground);
  Color get groupedBackground => _r(AppColors.groupedBackground);
  Color get secondaryGroupedBackground =>
      _r(AppColors.secondaryGroupedBackground);
  Color get tertiaryGroupedBackground =>
      _r(AppColors.tertiaryGroupedBackground);
  Color get barBackground => _r(AppColors.barBackground);

  Color get label => _r(AppColors.label);
  Color get secondaryLabel => _r(AppColors.secondaryLabel);
  Color get tertiaryLabel => _r(AppColors.tertiaryLabel);
  Color get quaternaryLabel => _r(AppColors.quaternaryLabel);
  Color get placeholder => _r(AppColors.placeholder);

  Color get separator => _r(AppColors.separator);
  Color get opaqueSeparator => _r(AppColors.opaqueSeparator);
  Color get fill => _r(AppColors.fill);
  Color get secondaryFill => _r(AppColors.secondaryFill);
  Color get tertiaryFill => _r(AppColors.tertiaryFill);

  Color get destructive => _r(AppColors.destructive);
  Color get success => _r(AppColors.success);
  Color get warning => _r(AppColors.warning);

  /// True when the resolved theme is dark (for the rare asset / gradient
  /// choice that has no semantic token).
  bool get isDark =>
      (CupertinoTheme.maybeBrightnessOf(_context) ?? Brightness.light) ==
      Brightness.dark;
}

extension AppPaletteContext on BuildContext {
  /// Semantic colours resolved for this context. See [AppPalette].
  AppPalette get palette => AppPalette._(this);
}
