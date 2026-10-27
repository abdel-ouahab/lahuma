import 'package:flutter/cupertino.dart';

/// Lahuma design tokens — colour.
///
/// Dark mode is navy surfaces with a blue accent and blue gradients, after the
/// "Online Bike Shopping App" Figma kit; light mode keeps the iOS system
/// surfaces with the same accent. The theme follows the user's setting (see
/// `main.dart`). This is the only file
/// in the app that may contain hex values: screens use the semantic tokens
/// below, resolved through `context.palette` (see [AppPalette]).
class AppColors {
  AppColors._();

  // ─── Accent ──────────────────────────────────────────────────────────────
  /// The one interactive colour: buttons, links, selection, active tab.
  static const CupertinoDynamicColor accent =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF3D9CEA),
    darkColor: Color(0xFF3D9CEA),
  );

  /// Accent wash behind tinted buttons, selected rows and icon tiles.
  static const CupertinoDynamicColor accentTint =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x263D9CEA),
    darkColor: Color(0x383D9CEA),
  );

  /// Text / icons drawn on top of [accent].
  static const Color onAccent = Color(0xFFFFFFFF);

  // ─── Backgrounds ─────────────────────────────────────────────────────────
  static const CupertinoDynamicColor background =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF242C3B),
  );
  static const CupertinoDynamicColor secondaryBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF2F2F7),
    darkColor: Color(0xFF28303F),
  );
  static const CupertinoDynamicColor tertiaryBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF323B4F),
  );

  /// Page behind inset-grouped lists and cards.
  static const CupertinoDynamicColor groupedBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF2F2F7),
    darkColor: Color(0xFF242C3B),
  );

  /// Cells and cards sitting on [groupedBackground].
  static const CupertinoDynamicColor secondaryGroupedBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF2E3647),
  );

  /// Controls inside a grouped cell (e.g. a field inside a card).
  static const CupertinoDynamicColor tertiaryGroupedBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF2F2F7),
    darkColor: Color(0xFF353F54),
  );

  /// Translucent nav / tab bar material (blurred by the bars themselves).
  static const CupertinoDynamicColor barBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xF0F9F9F9),
    darkColor: Color(0xF0262E3D),
  );

  // ─── Floating tab bar ("Modern Floating Navbar" Figma kit) ──────────────
  /// Bar body and the raised circle behind the selected tab: the accent blue
  /// in light mode, a raised navy surface in dark mode.
  static const CupertinoDynamicColor tabBarBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF3D9CEA),
    darkColor: Color(0xFF323B4F),
  );

  /// Selected tab's icon and label.
  static const CupertinoDynamicColor tabBarActive =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF3D9CEA),
  );

  /// Unselected tabs' icons and labels.
  static const CupertinoDynamicColor tabBarInactive =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xB3FFFFFF),
    darkColor: Color(0xFF8A93A6),
  );

  // ─── Labels ──────────────────────────────────────────────────────────────
  static const CupertinoDynamicColor label =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF000000),
    darkColor: Color(0xFFFFFFFF),
  );
  static const CupertinoDynamicColor secondaryLabel =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x993C3C43),
    darkColor: Color(0x99FFFFFF),
  );
  static const CupertinoDynamicColor tertiaryLabel =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x4C3C3C43),
    darkColor: Color(0x61FFFFFF),
  );
  static const CupertinoDynamicColor quaternaryLabel =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x2D3C3C43),
    darkColor: Color(0x33FFFFFF),
  );
  static const CupertinoDynamicColor placeholder =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x4C3C3C43),
    darkColor: Color(0x61FFFFFF),
  );

  // ─── Lines and fills ─────────────────────────────────────────────────────
  static const CupertinoDynamicColor separator =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x4A3C3C43),
    darkColor: Color(0x1FFFFFFF),
  );
  static const CupertinoDynamicColor opaqueSeparator =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC6C6C8),
    darkColor: Color(0xFF353F54),
  );
  static const CupertinoDynamicColor fill =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x33787880),
    darkColor: Color(0xFF353F54),
  );
  static const CupertinoDynamicColor secondaryFill =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x29787880),
    darkColor: Color(0xFF323B4F),
  );

  /// Inset wells: text fields, search, segmented-control track.
  static const CupertinoDynamicColor tertiaryFill =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x1F767680),
    darkColor: Color(0xFF1E2532),
  );

  // ─── Status ──────────────────────────────────────────────────────────────
  static const CupertinoDynamicColor destructive = CupertinoColors.systemRed;
  static const CupertinoDynamicColor success = CupertinoColors.systemGreen;
  static const CupertinoDynamicColor warning = CupertinoColors.systemOrange;

  // ─── Toast / HUD (inverted capsule over content) ─────────────────────────
  static const CupertinoDynamicColor toastBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xF02C2C2E),
    darkColor: Color(0xF0353F54),
  );
  static const Color toastLabel = Color(0xFFFFFFFF);

  /// Accent readable on [toastBackground] (the toast's action button).
  static const Color toastAction = Color(0xFF34C8E8);

  // ─── Icon tiles (Settings-style coloured squares, white glyph) ───────────
  static const CupertinoDynamicColor tileBlue = CupertinoColors.systemBlue;
  static const CupertinoDynamicColor tilePurple = CupertinoColors.systemPurple;
  static const CupertinoDynamicColor tilePink = CupertinoColors.systemPink;
  static const CupertinoDynamicColor tileOrange = CupertinoColors.systemOrange;
  static const CupertinoDynamicColor tileYellow = CupertinoColors.systemYellow;
  static const CupertinoDynamicColor tileRed = CupertinoColors.systemRed;
  static const CupertinoDynamicColor tileGreen = CupertinoColors.systemGreen;
  static const CupertinoDynamicColor tileIndigo = CupertinoColors.systemIndigo;

  // ─── Brand gradients ─────────────────────────────────────────────────────
  /// Primary buttons and selected controls: cyan → indigo, top-left to
  /// bottom-right.
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34C8E8), Color(0xFF4E4AF2)],
  );

  /// Raised cards and sheets in dark mode: lighter navy at the top-left
  /// falling off. Light mode uses [cardGradientLight]; pick via
  /// [AppPalette.cardGradient].
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF353F54), Color(0xFF222834)],
    stops: [0, 0.6],
  );

  /// Raised cards in light mode: white, barely falling off.
  static const LinearGradient cardGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF9F9FB)],
  );

  /// Faint "glass" edge on raised surfaces: lit along the top, fading out.
  static const LinearGradient edgeHighlight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)],
    stops: [0, 0.45],
  );

  /// Drop shadow under raised surfaces (dark mode; scale its alpha down in
  /// light mode via [AppPalette.shadow]).
  static const Color shadow = Color(0xFF10141C);

  /// Hero "Continue reading" card.
  static const List<Color> heroGradient = [
    Color(0xFF34C8E8),
    Color(0xFF4E4AF2),
  ];

  /// Splash screen — the logo's teal gradient.
  static const List<Color> splashGradient = [
    Color(0xFF5AB6B8),
    Color(0xFF0F5264),
  ];

  // ─── LEGACY (pre-redesign constants) ─────────────────────────────────────
  // Kept only so screens that are not converted yet keep compiling. New code
  // must not use these; each converted screen drops them, and Phase 6 removes
  // whatever is left.
  static const Color primary = Color(0xFF3D9CEA);
  static const Color primaryDark = Color(0xFF2F7FD0);
  static const Color primaryLight = Color(0xFF6DB8F0);
  static const Color primaryContainer = Color(0xFFE3F0FC);

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

  static const Color backgroundDark = Color(0xFF242C3B);
  static const Color surfaceDark = Color(0xFF2E3647);
  static const Color surfaceElevatedDark = Color(0xFF353F54);
  static const Color textDark = Color(0xFFFFFFFF);
  static const Color subtextDark = Color(0xFFA7AAB1);
  static const Color mutedDark = Color(0xFF6E7585);
  static const Color dividerDark = Color(0xFF353F54);

  static const Color ayahNumberBg = Color(0xFF3D9CEA);
  static const Color ayahNumberText = Color(0xFFFFFFFF);
  static const Color translationText = Color(0xFF8A93A6);

  static const Color bookmarkActive = Color(0xFF3D9CEA);
  static const Color bookmarkInactive = Color(0xFF6E7585);
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
  Color get tabBarBackground => _r(AppColors.tabBarBackground);
  Color get tabBarActive => _r(AppColors.tabBarActive);
  Color get tabBarInactive => _r(AppColors.tabBarInactive);

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

  /// Raised-card fill for the current brightness.
  LinearGradient get cardGradient =>
      isDark ? AppColors.cardGradient : AppColors.cardGradientLight;

  /// Drop-shadow colour at [darkAlpha] in dark mode; much softer in light
  /// mode, where a navy shadow at full strength reads as dirt.
  Color shadow(double darkAlpha) =>
      AppColors.shadow.withValues(alpha: isDark ? darkAlpha : darkAlpha * 0.2);

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
