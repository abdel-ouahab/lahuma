import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Lahuma design tokens — responsive layout.
///
/// Screens adapt to small phones, landscape, the keyboard and large text
/// with these rather than each testing raw sizes. The responsive suite
/// (test/responsive) checks every screen at 320–768 pt wide, both
/// orientations and text at 1.0 / 1.3 / 2.0.
abstract final class AppBreakpoints {
  /// Narrower than this is a small phone (320–359 pt).
  static const double compact = 360;

  /// From this width there is room to put things side by side: tablets,
  /// and phones turned sideways.
  static const double wide = 600;

  /// Full-screen layouts are designed for at least this much height. Below
  /// it (a phone in landscape, or with the keyboard up) they scroll as a
  /// whole instead of squeezing their content.
  static const double minLayoutHeight = 440;
}

extension AppLayoutContext on BuildContext {
  /// A small phone: compact rows, wrapped labels.
  bool get isCompactWidth =>
      MediaQuery.sizeOf(this).width < AppBreakpoints.compact;

  /// Room for side-by-side layouts.
  bool get isWideLayout => MediaQuery.sizeOf(this).width >= AppBreakpoints.wide;
}

/// A column that fills the space it is given when its content fits (its
/// [Spacer]s and [Expanded] children spread it out as designed) and scrolls
/// when it doesn't: a phone in landscape, large text, the keyboard up.
///
/// The child is laid out at its intrinsic height, so keep it to a short
/// column (a centred message, a player, a form), not a long list, and
/// without a [LayoutBuilder] inside (it can't report an intrinsic height).
class AppFillScroll extends StatelessWidget {
  const AppFillScroll({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.physics,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Clears whatever still covers the bottom (the tab bar and mini
        // player inside the shell; nothing under a SafeArea).
        final insets = padding.resolve(Directionality.of(context)) +
            EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom);
        return SingleChildScrollView(
          physics: physics,
          padding: insets,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - insets.vertical),
            ),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }
}

/// Centres [child] in the space it is given, and scrolls it when it is
/// taller than that space (empty and error states, short messages).
class AppScrollableCenter extends StatelessWidget {
  const AppScrollableCenter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Centred in, and scrolled clear of, what still covers the bottom (the
    // tab bar and mini player inside the shell).
    final bottom = MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - bottom)),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Lays [child] (typically a column of fixed headers above an [Expanded]
/// list) out with at least [minHeight] of it visible above what covers the
/// bottom (the tab bar and mini player inside the shell). On a taller
/// viewport nothing changes; on a shorter one the whole layout scrolls as
/// one, so the headers can move out of the way instead of crushing the list
/// or overflowing. The widget tree is the same either way, so opening the
/// keyboard (which shortens the viewport) keeps focus and scroll positions.
class AppMinHeight extends StatelessWidget {
  const AppMinHeight({
    super.key,
    required this.child,
    this.minHeight = AppBreakpoints.minLayoutHeight,
  });

  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final needed = minHeight + MediaQuery.paddingOf(context).bottom;
        final fits = constraints.maxHeight >= needed;
        return SingleChildScrollView(
          physics: fits ? const NeverScrollableScrollPhysics() : null,
          child: SizedBox(
            height: fits ? constraints.maxHeight : needed,
            child: child,
          ),
        );
      },
    );
  }
}
