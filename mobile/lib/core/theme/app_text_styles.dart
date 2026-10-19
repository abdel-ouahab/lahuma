import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Lahuma Design System — Typography
/// Quran text: Scheherazade New (proper Quran-grade Arabic shaping)
/// UI text: Cairo (modern Arabic/Latin, excellent RTL support)
class AppTextStyles {
  AppTextStyles._();

  // ─── Quran Text ──────────────────────────────────────────────────────────
  static TextStyle quranText({
    double fontSize = 24,
    Color? color,
    bool isDark = false,
  }) =>
      GoogleFonts.scheherazadeNew(
        fontSize: fontSize,
        height: 2.0,
        color: color ?? (isDark ? AppColors.textDark : AppColors.textLight),
        fontWeight: FontWeight.w400,
      );

  static TextStyle quranTextLarge({Color? color, bool isDark = false}) =>
      quranText(fontSize: 26, color: color, isDark: isDark);

  // ─── UI Text (Cairo) ─────────────────────────────────────────────────────
  static TextStyle displayLarge({Color? color, bool isDark = false}) =>
      GoogleFonts.cairo(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: color ?? (isDark ? AppColors.textDark : AppColors.textLight),
      );

  static TextStyle displayMedium({Color? color, bool isDark = false}) =>
      GoogleFonts.cairo(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: color ?? (isDark ? AppColors.textDark : AppColors.textLight),
      );

  static TextStyle headlineLarge({Color? color, bool isDark = false}) =>
      GoogleFonts.cairo(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: color ?? (isDark ? AppColors.textDark : AppColors.textLight),
      );

  static TextStyle headlineMedium({Color? color, bool isDark = false}) =>
      GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: color ?? (isDark ? AppColors.textDark : AppColors.textLight),
      );

  static TextStyle titleLarge({Color? color, bool isDark = false}) =>
      GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: color ?? (isDark ? AppColors.textDark : AppColors.textLight),
      );

  static TextStyle titleMedium({Color? color, bool isDark = false}) =>
      GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: color ?? (isDark ? AppColors.textDark : AppColors.textLight),
      );

  static TextStyle bodyLarge({Color? color, bool isDark = false}) =>
      GoogleFonts.cairo(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: color ?? (isDark ? AppColors.subtextDark : AppColors.subtextLight),
      );

  static TextStyle bodyMedium({Color? color, bool isDark = false}) =>
      GoogleFonts.cairo(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color ?? (isDark ? AppColors.subtextDark : AppColors.subtextLight),
      );

  static TextStyle caption({Color? color, bool isDark = false}) =>
      GoogleFonts.cairo(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color ?? (isDark ? AppColors.mutedDark : AppColors.mutedLight),
      );

  static TextStyle labelSmall({Color? color, bool isDark = false}) =>
      GoogleFonts.cairo(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: color ?? (isDark ? AppColors.mutedDark : AppColors.mutedLight),
      );
}
