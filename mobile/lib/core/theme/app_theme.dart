import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Central design system entrypoint. Screens should never define raw
/// colors/text styles inline — extend this instead.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _base(
        brightness: Brightness.light,
        background: AppColors.backgroundLight,
        surface: AppColors.surfaceLight,
        surfaceElevated: AppColors.surfaceElevatedLight,
        onBackground: AppColors.textLight,
        subtext: AppColors.subtextLight,
        muted: AppColors.mutedLight,
        divider: AppColors.dividerLight,
      );

  static ThemeData get dark => _base(
        brightness: Brightness.dark,
        background: AppColors.backgroundDark,
        surface: AppColors.surfaceDark,
        surfaceElevated: AppColors.surfaceElevatedDark,
        onBackground: AppColors.textDark,
        subtext: AppColors.subtextDark,
        muted: AppColors.mutedDark,
        divider: AppColors.dividerDark,
      );

  static ThemeData _base({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceElevated,
    required Color onBackground,
    required Color subtext,
    required Color muted,
    required Color divider,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.inkDark,
      secondary: AppColors.cardPurple,
      surface: surface,
      onSurface: onBackground,
      outline: divider,
    ).copyWith(
      shadow: Colors.black.withValues(alpha: brightness == Brightness.light ? 0.04 : 0.12),
    );

    // Cairo as the base font for all text
    final cairoTextTheme = GoogleFonts.cairoTextTheme(
      TextTheme(
        displayLarge: TextStyle(color: onBackground, fontWeight: FontWeight.w700),
        displayMedium: TextStyle(color: onBackground, fontWeight: FontWeight.w700),
        displaySmall: TextStyle(color: onBackground, fontWeight: FontWeight.w600),
        headlineLarge: TextStyle(color: onBackground, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(color: onBackground, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: onBackground, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: onBackground, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: onBackground, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: onBackground, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: subtext),
        bodyMedium: TextStyle(color: subtext),
        bodySmall: TextStyle(color: muted),
        labelLarge: TextStyle(color: onBackground, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: muted),
        labelSmall: TextStyle(color: muted),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: cairoTextTheme,
      splashFactory: NoSplash.splashFactory, // feedback is a press-scale, not a ripple
      highlightColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        // Interruptible, edge-swipe-to-go-back transitions everywhere.
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      }),
      // ── AppBar ────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: onBackground,
        ),
        iconTheme: IconThemeData(color: onBackground, size: 22),
      ),
      // ── Cards ─────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        margin: EdgeInsets.zero,
      ),
      // ── Elevated Button ───────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: const StadiumBorder(),
          elevation: 0,
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // ── Text Button ───────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // ── Input / Search Fields ─────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.cairo(
          fontSize: 13,
          color: muted,
        ),
      ),
      // ── Bottom Navigation ─────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: muted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.cairo(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.cairo(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
      // ── Divider ───────────────────────────────────────────────────────
      dividerColor: divider,
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 0,
      ),
      // ── Icon Theme ────────────────────────────────────────────────────
      iconTheme: IconThemeData(color: onBackground, size: 22),
      // ── Bottom Sheet ──────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        elevation: 0,
        modalBarrierColor: Colors.black.withValues(alpha: 0.32),
      ),
      // ── Chip ──────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: surfaceElevated,
        labelStyle: GoogleFonts.cairo(fontSize: 12, color: onBackground),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
    );
  }
}
