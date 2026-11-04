import 'package:flutter/cupertino.dart';

/// Lahuma design tokens — colour.
///
/// Mosque green and gold on warm ivory, after the Home prayer-times hero
/// (the Djamaa El Djazair mock): green is the one interactive colour, gold
/// is gilding only — frames, rings, ornaments, bookmarks — and never
/// carries text on a light surface. Dark mode is the same scene at night:
/// green-black surfaces, a lighter green accent, the same gold. The theme
/// follows the user's setting (see `main.dart`). This is the only file in
/// the app that may contain hex values: screens use the semantic tokens
/// below, resolved through `context.palette` (see [AppPalette]).
class AppColors {
  AppColors._();

  // ─── Accent ──────────────────────────────────────────────────────────────
  /// The one interactive colour: buttons, links, selection, active tab.
  static const CupertinoDynamicColor accent =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0F5A4A),
    darkColor: Color(0xFF3DAE8A),
  );

  /// Accent wash behind tinted buttons, selected rows and icon tiles.
  static const CupertinoDynamicColor accentTint =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x1F0F5A4A),
    darkColor: Color(0x333DAE8A),
  );

  /// Text / icons drawn on top of [accent].
  static const Color onAccent = Color(0xFFFFFFFF);

  /// Gilding: frames, the selected tab's ring, ornaments, bookmarks.
  /// Decorative only; too light on ivory to carry text.
  static const CupertinoDynamicColor gold =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC49A3C),
    darkColor: Color(0xFFD9B565),
  );

  // ─── Backgrounds ─────────────────────────────────────────────────────────
  static const CupertinoDynamicColor background =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF0E1714),
  );
  static const CupertinoDynamicColor secondaryBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF6F3EA),
    darkColor: Color(0xFF131E1A),
  );
  static const CupertinoDynamicColor tertiaryBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF1C2A25),
  );

  /// Page behind inset-grouped lists and cards: warm ivory.
  static const CupertinoDynamicColor groupedBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF6F3EA),
    darkColor: Color(0xFF0E1714),
  );

  /// Cells and cards sitting on [groupedBackground].
  static const CupertinoDynamicColor secondaryGroupedBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF16221E),
  );

  /// Controls inside a grouped cell (e.g. a field inside a card).
  static const CupertinoDynamicColor tertiaryGroupedBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF3EFE4),
    darkColor: Color(0xFF1F2E28),
  );

  /// Translucent nav / tab bar material (blurred by the bars themselves).
  static const CupertinoDynamicColor barBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xF0F8F5EE),
    darkColor: Color(0xF0111B18),
  );

  // ─── Floating tab bar ────────────────────────────────────────────────────
  /// Bar body and the raised circle behind the selected tab: mosque green
  /// in light mode, a raised green-black surface in dark mode.
  static const CupertinoDynamicColor tabBarBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0F5A4A),
    darkColor: Color(0xFF1C2A25),
  );

  /// Selected tab's icon and label.
  static const CupertinoDynamicColor tabBarActive =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFFD9B565),
  );

  /// Unselected tabs' icons and labels.
  static const CupertinoDynamicColor tabBarInactive =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xB3FFFFFF),
    darkColor: Color(0xFF7F9089),
  );

  // ─── Labels ──────────────────────────────────────────────────────────────
  // A green near-black rather than pure black, in the hero's ink.
  static const CupertinoDynamicColor label =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF15302A),
    darkColor: Color(0xFFF3F1EA),
  );
  static const CupertinoDynamicColor secondaryLabel =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x9E2A3F38),
    darkColor: Color(0x99F3F1EA),
  );
  static const CupertinoDynamicColor tertiaryLabel =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x5C2A3F38),
    darkColor: Color(0x61F3F1EA),
  );
  static const CupertinoDynamicColor quaternaryLabel =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x332A3F38),
    darkColor: Color(0x33F3F1EA),
  );
  static const CupertinoDynamicColor placeholder =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x5C2A3F38),
    darkColor: Color(0x61F3F1EA),
  );

  // ─── Lines and fills ─────────────────────────────────────────────────────
  static const CupertinoDynamicColor separator =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x40564A2E),
    darkColor: Color(0x1FF3F1EA),
  );
  static const CupertinoDynamicColor opaqueSeparator =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE2DCCB),
    darkColor: Color(0xFF26362F),
  );
  static const CupertinoDynamicColor fill =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x2E6E6450),
    darkColor: Color(0xFF26362F),
  );
  static const CupertinoDynamicColor secondaryFill =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x246E6450),
    darkColor: Color(0xFF22322B),
  );

  /// Inset wells: text fields, search, segmented-control track.
  static const CupertinoDynamicColor tertiaryFill =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x1C6E6450),
    darkColor: Color(0xFF0B1311),
  );

  // ─── Status ──────────────────────────────────────────────────────────────
  static const CupertinoDynamicColor destructive = CupertinoColors.systemRed;
  static const CupertinoDynamicColor success = CupertinoColors.systemGreen;
  static const CupertinoDynamicColor warning = CupertinoColors.systemOrange;

  // ─── Toast / HUD (inverted capsule over content) ─────────────────────────
  static const CupertinoDynamicColor toastBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xF0173A31),
    darkColor: Color(0xF0263A32),
  );
  static const Color toastLabel = Color(0xFFFFFFFF);

  /// Accent readable on [toastBackground] (the toast's action button).
  static const Color toastAction = Color(0xFFE6C77E);

  // ─── Icon tiles (Settings-style coloured squares, white glyph) ───────────
  // Zellige jewel tones instead of the iOS rainbow, so a row of tiles reads
  // as one glazed wall next to the green and gold.
  static const CupertinoDynamicColor tileBlue =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF2F6E8E),
    darkColor: Color(0xFF4A8FB0),
  );
  static const CupertinoDynamicColor tilePurple =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF6E4C7E),
    darkColor: Color(0xFF9070A0),
  );
  static const CupertinoDynamicColor tilePink =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFA9506A),
    darkColor: Color(0xFFC86F88),
  );
  static const CupertinoDynamicColor tileOrange =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFBF7A2A),
    darkColor: Color(0xFFD9954A),
  );
  static const CupertinoDynamicColor tileYellow =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFB48A2F),
    darkColor: Color(0xFFD9B565),
  );
  static const CupertinoDynamicColor tileRed =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFAE4A3C),
    darkColor: Color(0xFFCC6A5B),
  );
  static const CupertinoDynamicColor tileGreen =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF1F7A5F),
    darkColor: Color(0xFF3DAE8A),
  );
  static const CupertinoDynamicColor tileIndigo =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF3B4A80),
    darkColor: Color(0xFF6474AA),
  );
  static const CupertinoDynamicColor tileTeal =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF237E78),
    darkColor: Color(0xFF3FA39C),
  );

  // ─── Tasbih beads ────────────────────────────────────────────────────────
  // Lit from the top left: highlight → body → shade, plus the light the
  // material lets through (amber glows from inside, wood barely does) and
  // the cord they are strung on. Same in both themes: they are objects.
  static const BeadColors beadAmber = BeadColors(
    highlight: Color(0xFFFFE3A3),
    body: Color(0xFFE39B2D),
    shade: Color(0xFF8A4B0F),
    glow: Color(0xFFFFC15A),
    glowStrength: 0.55,
    specular: 0.9,
    cord: Color(0xFF5B3A1E),
  );
  static const BeadColors beadWood = BeadColors(
    highlight: Color(0xFFD9A577),
    body: Color(0xFF9C6238),
    shade: Color(0xFF4A2914),
    glow: Color(0xFFC88A5A),
    glowStrength: 0.2,
    specular: 0.35,
    cord: Color(0xFF3B2A20),
    grain: Color(0xFF6E3F1F),
  );
  static const BeadColors beadPearl = BeadColors(
    highlight: Color(0xFFFFFFFF),
    body: Color(0xFFECE6DA),
    shade: Color(0xFFA9A196),
    glow: Color(0xFFF6D9E3),
    glowStrength: 0.5,
    specular: 1,
    cord: Color(0xFF9AA0A6),
  );

  /// The imam bead, separators and tassel: the brand's green as malachite.
  static const BeadColors beadImam = BeadColors(
    highlight: Color(0xFFA3E6C8),
    body: Color(0xFF1F8A6A),
    shade: Color(0xFF0B3A32),
    glow: Color(0xFF4CC29C),
    glowStrength: 0.45,
    specular: 0.95,
    cord: Color(0xFF0B3A32),
  );

  // ─── Qibla compass ───────────────────────────────────────────────────────
  // The Kaaba on the dial: the black kiswa lit from the top left, and its
  // gold band. Same in both themes: it is an object.
  static const Color kaabaFront = Color(0xFF1C1C1F);
  static const Color kaabaSide = Color(0xFF0B0B0D);
  static const Color kaabaTop = Color(0xFF45454B);
  static const Color kaabaGold = Color(0xFFD9B45A);

  // ─── Prayer times hero (Home) ────────────────────────────────────────────
  // Where the palette comes from: the ring, the next-prayer tile and the
  // dates in green; the frame, the ring's knob and the ornaments gilded.

  /// Strokes and text in the prayer-times hero: ring, prayer name, dates.
  static const CupertinoDynamicColor prayerGreen =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0F5A4A),
    darkColor: Color(0xFF4CC29C),
  );

  /// Fill behind white text: the next-prayer tile and the time pill.
  static const CupertinoDynamicColor prayerGreenFill =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0F5A4A),
    darkColor: Color(0xFF17705A),
  );

  /// Figures in the prayer-times hero (countdown, the six times).
  static const CupertinoDynamicColor prayerInk = label;

  /// The countdown ring's track.
  static const CupertinoDynamicColor prayerTrack =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE6ECE8),
    darkColor: Color(0xFF26362F),
  );

  /// Gilding in the hero; the same as [gold].
  static const CupertinoDynamicColor prayerGold = gold;

  /// Inside the gold frame, below the sky.
  static const CupertinoDynamicColor prayerFrame =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFAF6EC),
    darkColor: Color(0xFF131E1A),
  );

  /// The mosque, minaret and rooftops against the hero sky. Same in both
  /// themes: it is a picture.
  static const Color prayerSilhouette = Color(0xFF0B3A32);

  /// Hero skies by time of day, zenith → horizon.
  static const List<Color> skyDawn = [
    Color(0xFF1E2A4A),
    Color(0xFF5E5486),
    Color(0xFFE29F7C),
  ];
  static const List<Color> skyDay = [
    Color(0xFF1A5560),
    Color(0xFF4F8F8A),
    Color(0xFFE6D3A0),
  ];
  static const List<Color> skyDusk = [
    Color(0xFF26294F),
    Color(0xFF8E4A63),
    Color(0xFFEE9F58),
  ];
  static const List<Color> skyNight = [
    Color(0xFF06121B),
    Color(0xFF0F2C36),
    Color(0xFF2C5A57),
  ];

  /// Stars and the crescent in the night sky.
  static const Color skyStar = Color(0xFFF3E7C4);

  /// Candlelight in the Ramadan lanterns on the prayer card: the warm core
  /// and the amber of the coloured glass. Same in both themes: it is light.
  static const Color lanternFlame = Color(0xFFFFE6A8);
  static const Color lanternGlass = Color(0xFFE79B32);

  // ─── Brand gradients ─────────────────────────────────────────────────────
  /// Primary buttons and selected controls: mosque green, lit from the top
  /// left.
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF16735E), Color(0xFF0B4A3D)],
  );

  /// Raised cards and sheets in dark mode: a lighter green-black at the
  /// top-left falling off. Light mode uses [cardGradientLight]; pick via
  /// [AppPalette.cardGradient].
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1C2A25), Color(0xFF131E1A)],
    stops: [0, 0.6],
  );

  /// Raised cards in light mode: white, warming slightly to ivory.
  static const LinearGradient cardGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFFDFBF6)],
  );

  /// Faint "glass" edge on raised surfaces: lit along the top, fading out.
  static const LinearGradient edgeHighlight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x26FFFFFF), Color(0x00FFFFFF)],
    stops: [0, 0.45],
  );

  /// Drop shadow under raised surfaces (dark mode; scale its alpha down in
  /// light mode via [AppPalette.shadow]).
  static const Color shadow = Color(0xFF07120F);

  /// Hero surfaces (Continue reading, the surah header, the mini player):
  /// the hero's green, deepening downwards. Paired with gold crescents.
  static const List<Color> heroGradient = [
    Color(0xFF14695A),
    Color(0xFF0B3F34),
  ];

  // ─── Splash ──────────────────────────────────────────────────────────────
  // The Mushaf's opening medallion: the gold wordmark inside a gold star on
  // the mosque green; at night the same on green-black. The splash follows
  // the phone's appearance, not the app's setting, because the native launch
  // screen before it can only follow the phone. [splashBackground] is that
  // launch screen's colour too, repeated in pubspec.yaml under
  // flutter_native_splash (which can't read Dart): change both together.

  /// The launch screen's flat colour; the Flutter splash's first frame.
  static const CupertinoDynamicColor splashBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0D4F42),
    darkColor: Color(0xFF07120F),
  );

  /// Light gathered behind the wordmark, fading in over [splashBackground].
  static const CupertinoDynamicColor splashGlow =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF1C7A64),
    darkColor: Color(0xFF15392F),
  );

  /// The wordmark, its star and the lattice: the app icon's gold, which
  /// reads on both splash greens.
  static const Color splashGold = Color(0xFFDDB86A);

  // ─── LEGACY (pre-redesign constants) ─────────────────────────────────────
  // Kept only so screens that are not converted yet keep compiling. New code
  // must not use these. Their values follow the green-and-gold palette so the
  // unconverted screens match. [primary] is not theme-aware, so it is a mid
  // malachite that reads on both ivory and the dark green-black.
  static const Color primary = Color(0xFF1F8A6A);
  static const Color primaryDark = Color(0xFF0B3F34);
  static const Color primaryLight = Color(0xFF3DAE8A);
  static const Color primaryContainer = Color(0xFFE3EEE8);

  static const Color inkDark = Color(0xFF15302A);
  static const Color inkMedium = Color(0xFF4A645C);
  static const Color inkLight = Color(0xFF8FA39C);

  static const Color cardTeal = Color(0xFFE4F0EA);
  static const Color cardBlue = Color(0xFFE5EEF2);
  static const Color cardPurple = Color(0xFFEFE9F1);
  static const Color cardPink = Color(0xFFF6E9EC);
  static const Color cardMint = Color(0xFFE9F3EC);

  static const Color backgroundLight = Color(0xFFF6F3EA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFF1ECDF);
  static const Color textLight = Color(0xFF15302A);
  static const Color subtextLight = Color(0xFF566B64);
  static const Color mutedLight = Color(0xFF94A39D);
  static const Color dividerLight = Color(0xFFE6E0D0);

  static const Color backgroundDark = Color(0xFF0E1714);
  static const Color surfaceDark = Color(0xFF16221E);
  static const Color surfaceElevatedDark = Color(0xFF1F2E28);
  static const Color textDark = Color(0xFFF3F1EA);
  static const Color subtextDark = Color(0xFFA6B2AD);
  static const Color mutedDark = Color(0xFF6F807A);
  static const Color dividerDark = Color(0xFF26362F);

  static const Color ayahNumberBg = Color(0xFF0F5A4A);
  static const Color ayahNumberText = Color(0xFFFFFFFF);
  static const Color translationText = Color(0xFF7F8C86);

  static const Color bookmarkActive = Color(0xFFC49A3C);
  static const Color bookmarkInactive = Color(0xFF6F807A);
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
  Color get gold => _r(AppColors.gold);
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

/// One tasbih bead material. See [AppColors.beadAmber].
class BeadColors {
  const BeadColors({
    required this.highlight,
    required this.body,
    required this.shade,
    required this.glow,
    required this.glowStrength,
    required this.specular,
    required this.cord,
    this.grain,
  });

  final Color highlight;
  final Color body;
  final Color shade;

  /// Light passing through the bead, gathered at its lower far side.
  final Color glow;
  final double glowStrength;

  /// Opacity of the white glint (gloss).
  final double specular;
  final Color cord;

  /// Wood grain lines; null for materials without grain.
  final Color? grain;
}
