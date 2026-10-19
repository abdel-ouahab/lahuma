import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Central theme entrypoint.
///
/// The app renders with Cupertino widgets on every platform. [cupertino] is
/// the source of truth; the Material [ThemeData] exists only so the Material
/// widgets that remain (and screens not converted yet) pick up the same
/// tokens, iOS platform conventions and no ripples.
class AppTheme {
  AppTheme._();

  static CupertinoThemeData cupertino(Brightness brightness) =>
      CupertinoThemeData(
        brightness: brightness,
        primaryColor: AppColors.accent,
        primaryContrastingColor: AppColors.onAccent,
        scaffoldBackgroundColor: AppColors.groupedBackground,
        barBackgroundColor: AppColors.barBackground,
        textTheme: AppTypography.cupertinoTextTheme,
        applyThemeToAll: true,
      );

  /// Bouncing physics and no Android overscroll glow, on every platform.
  static const ScrollBehavior scrollBehavior = CupertinoScrollBehavior();

  /// Transparent status bar, as on iOS (Android otherwise paints a grey scrim
  /// behind it). Icon brightness is then set per screen by the Cupertino bars.
  static void applySystemChrome() => SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(statusBarColor: Color(0x00000000)),
      );

  static ThemeData get light => _material(Brightness.light);
  static ThemeData get dark => _material(Brightness.dark);

  /// Puts the Cupertino body style under every route, so Cupertino screens
  /// hosted by `MaterialApp` don't inherit Material's debug error text style.
  /// Use as `MaterialApp.router(builder: AppTheme.builder)`.
  static Widget builder(BuildContext context, Widget? child) =>
      DefaultTextStyle(
        style: CupertinoTheme.of(context).textTheme.textStyle,
        child: child ?? const SizedBox.shrink(),
      );

  /// Resolves a dynamic token for a fixed brightness (no BuildContext yet).
  static Color _at(Color color, Brightness brightness) =>
      color is CupertinoDynamicColor
          ? (brightness == Brightness.dark ? color.darkColor : color.color)
          : color;

  static ThemeData _material(Brightness brightness) {
    Color t(Color c) => _at(c, brightness);

    final accent = t(AppColors.accent);
    final background = t(AppColors.groupedBackground);
    final surface = t(AppColors.secondaryGroupedBackground);
    final fieldFill = t(AppColors.tertiaryFill);
    final label = t(AppColors.label);
    final secondaryLabel = t(AppColors.secondaryLabel);
    final tertiaryLabel = t(AppColors.tertiaryLabel);
    final separator = t(AppColors.separator);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      primary: accent,
      onPrimary: AppColors.onAccent,
      primaryContainer: t(AppColors.accentTint),
      onPrimaryContainer: label,
      error: t(AppColors.destructive),
      surface: surface,
      onSurface: label,
      outline: separator,
    ).copyWith(shadow: Colors.transparent);

    final textTheme = GoogleFonts.cairoTextTheme(
      TextTheme(
        displayLarge: TextStyle(color: label, fontWeight: FontWeight.w700),
        displayMedium: TextStyle(color: label, fontWeight: FontWeight.w700),
        displaySmall: TextStyle(color: label, fontWeight: FontWeight.w600),
        headlineLarge: TextStyle(color: label, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(color: label, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: label, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: label, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: label, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: label, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: secondaryLabel),
        bodyMedium: TextStyle(color: secondaryLabel),
        bodySmall: TextStyle(color: tertiaryLabel),
        labelLarge: TextStyle(color: label, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: tertiaryLabel),
        labelSmall: TextStyle(color: tertiaryLabel),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      platform: TargetPlatform.iOS,
      cupertinoOverrideTheme: cupertino(brightness),
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      // iOS feedback is opacity / scale, never an ink ripple.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        // Interruptible, edge-swipe-to-go-back transitions everywhere.
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: label,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.headline.copyWith(color: label),
        iconTheme: IconThemeData(color: accent, size: 22),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: AppRadius.continuous(AppRadius.medium),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: AppRadius.continuous(AppRadius.medium),
          elevation: 0,
          textStyle: AppTypography.headline,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size(0, 50),
          shape: AppRadius.continuous(AppRadius.medium),
          elevation: 0,
          textStyle: AppTypography.headline,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(0, 50),
          side: BorderSide(color: separator),
          shape: AppRadius.continuous(AppRadius.medium),
          textStyle: AppTypography.headline,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          minimumSize:
              const Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
          textStyle: AppTypography.subheadline.weight(FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium - 2),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium - 2),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium - 2),
          borderSide: BorderSide.none,
        ),
        hintStyle: AppTypography.body.copyWith(color: t(AppColors.placeholder)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: t(AppColors.fill),
        thumbColor: Colors.white,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : t(AppColors.fill),
        ),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: t(AppColors.fill),
      ),
      dividerColor: separator,
      dividerTheme: DividerThemeData(
        color: separator,
        thickness: AppSpacing.hairline,
        space: 0,
      ),
      iconTheme: IconThemeData(color: label, size: 22),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedSuperellipseBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
        ),
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
        modalBarrierColor: Colors.black.withValues(alpha: 0.4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: AppRadius.continuous(AppRadius.large),
      ),
      snackBarTheme: SnackBarThemeData(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: AppRadius.continuous(AppRadius.medium),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: fieldFill,
        labelStyle: AppTypography.footnote.copyWith(color: label),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: AppRadius.continuous(AppRadius.small),
        side: BorderSide.none,
      ),
    );
  }
}
