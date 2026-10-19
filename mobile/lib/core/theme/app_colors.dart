import 'package:flutter/material.dart';

/// Lahuma Design System — restrained, Apple-style palette.
///
/// One accent (teal) on neutral, layered surfaces. Hierarchy comes from
/// grouped backgrounds, hairlines and label weight — not from tinted cards or
/// coloured shadows. Do NOT use raw hex values in screens — reference tokens.
class AppColors {
  AppColors._();

  // ─── Accent ──────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF14958B);
  static const Color primaryDark = Color(0xFF0E746C); // pressed / dark variant
  static const Color primaryLight = Color(0xFF3DBDB1);
  static const Color primaryContainer = Color(0xFFE3F4F2);

  // ─── Ink (labels) ────────────────────────────────────────────────────────
  static const Color inkDark = Color(0xFF0F2F30);
  static const Color inkMedium = Color(0xFF4A6B6D);
  static const Color inkLight = Color(0xFF8FA6A8);

  // ─── Tinted surfaces (kept for compatibility; now barely-there) ──────────
  static const Color cardTeal = Color(0xFFE3F4F2);
  static const Color cardBlue = Color(0xFFE6F0FA);
  static const Color cardPurple = Color(0xFFEEEAF8);
  static const Color cardPink = Color(0xFFF9E9F0);
  static const Color cardMint = Color(0xFFEAF6F2);

  // ─── Gradient Stops ──────────────────────────────────────────────────────
  /// Hero "Continue Reading" card gradient — a single hue, slow falloff.
  static const List<Color> heroGradient = [
    Color(0xFF1AA195),
    Color(0xFF0B6B64),
  ];

  /// Splash screen gradient
  static const List<Color> splashGradient = [
    Color(0xFF14958B),
    Color(0xFF094F4A),
  ];

  // ─── Light Theme Surfaces (grouped: white cards on a quiet gray) ─────────
  static const Color backgroundLight = Color(0xFFF2F4F5);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFEBEEEF);
  static const Color textLight = Color(0xFF0F2F30);
  static const Color subtextLight = Color(0xFF5B7274);
  static const Color mutedLight = Color(0xFF93A5A7);
  static const Color dividerLight = Color(0xFFE1E6E7);

  // ─── Dark Theme Surfaces (true-black base, lifted cards) ─────────────────
  static const Color backgroundDark = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF151A1B);
  static const Color surfaceElevatedDark = Color(0xFF1F2627);
  static const Color textDark = Color(0xFFF2F7F7);
  static const Color subtextDark = Color(0xFF9DB1B3);
  static const Color mutedDark = Color(0xFF6A7E80);
  static const Color dividerDark = Color(0xFF273031);

  // ─── Quran Reader ────────────────────────────────────────────────────────
  static const Color ayahNumberBg = Color(0xFF14958B);
  static const Color ayahNumberText = Color(0xFFFFFFFF);
  static const Color translationText = Color(0xFF6F8A8C);

  // ─── Semantic ────────────────────────────────────────────────────────────
  static const Color bookmarkActive = Color(0xFF14958B);
  static const Color bookmarkInactive = Color(0xFFB8C7C9);
  static const Color error = Color(0xFFE5484D);
  static const Color success = Color(0xFF30A46C);
}
