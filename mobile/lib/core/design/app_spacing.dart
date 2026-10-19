import 'package:flutter/widgets.dart';

/// Lahuma design tokens — spacing (HIG 4-pt rhythm).
///
/// Scale: 4 · 8 · 12 · 16 · 20 · 24 · 32.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double ms = 12;
  static const double md = 16;
  static const double ml = 20;
  static const double lg = 24;
  static const double xl = 32;

  /// Legacy: outside the HIG scale; kept for screens not converted yet.
  static const double xxl = 48;

  /// Leading / trailing page margin (HIG: 16 pt on phones).
  static const double screenMargin = 16;

  /// Minimum hit area for anything tappable (HIG: 44 × 44 pt).
  static const double minTouchTarget = 44;

  /// Hairline separators and borders.
  static const double hairline = 0.5;

  /// Horizontal page margin as directional insets.
  static const EdgeInsetsDirectional screenInsets =
      EdgeInsetsDirectional.symmetric(horizontal: screenMargin);
}

/// Lahuma design tokens — corner radius.
class AppRadius {
  AppRadius._();

  /// Small controls: chips, icon tiles, text fields.
  static const double small = 8;

  /// Inset-grouped sections, list cards, buttons.
  static const double medium = 12;

  /// Feature / hero cards, sheets content.
  static const double large = 16;

  /// Capsule / circle.
  static const double full = 999;

  /// Continuous ("squircle") corners, as iOS draws them.
  static OutlinedBorder continuous(double radius,
          {BorderSide side = BorderSide.none}) =>
      RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        side: side,
      );

  // ─── LEGACY (pre-redesign names) ─────────────────────────────────────────
  // Kept for screens not converted yet; removed in Phase 6.
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 28;
}
