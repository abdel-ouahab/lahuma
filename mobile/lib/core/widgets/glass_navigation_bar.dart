import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../localization/tr.dart';
import '../theme/app_colors.dart';

/// Apple-inspired floating glass navigation bar for Lahuma.
///
/// Uses [BackdropFilter] + [ImageFilter.blur] for a genuine frosted-glass
/// effect. Floats above the content with rounded corners and horizontal margins.
///
/// Navigation logic is completely decoupled from the visual layer.
class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// The approximate total height of the bar (including bottom safe area
  /// padding). Consumers can use this to add scroll padding to list content.
  static double totalHeight(BuildContext context) =>
      _barHeight + _bottomMargin + MediaQuery.of(context).padding.bottom;

  static const double _barHeight = 64;
  static const double _horizontalMargin = 20;
  static const double _bottomMargin = 10;
  static const double _borderRadius = 32;
  static const double _blurSigma = 30;

  static List<_NavDestination> _destinations(BuildContext context) => [
        _NavDestination(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: context.tr('الرئيسية', 'Home'),
        ),
        _NavDestination(
          icon: Icons.menu_book_outlined,
          activeIcon: Icons.menu_book_rounded,
          label: context.tr('القرآن', 'Quran'),
        ),
        _NavDestination(
          icon: Icons.bookmark_outline_rounded,
          activeIcon: Icons.bookmark_rounded,
          label: context.tr('العلامات', 'Bookmarks'),
        ),
        _NavDestination(
          icon: Icons.more_horiz_rounded,
          activeIcon: Icons.more_horiz_rounded,
          label: context.tr('المزيد', 'More'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final destinations = _destinations(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _horizontalMargin,
        0,
        _horizontalMargin,
        _bottomMargin + bottomPadding,
      ),
      child: _GlassBarSurface(
        isDark: isDark,
        child: SizedBox(
          height: _barHeight,
          child: Stack(
            children: [
              // Selection capsule slides between items (spring-like ease-out),
              // and always animates from where it currently is.
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: AnimatedAlign(
                    duration: MediaQuery.of(context).disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 380),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.lerp(
                      AlignmentDirectional.centerStart.resolve(Directionality.of(context)),
                      AlignmentDirectional.centerEnd.resolve(Directionality.of(context)),
                      currentIndex / (destinations.length - 1),
                    )!,
                    child: FractionallySizedBox(
                      widthFactor: 1 / destinations.length,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(_borderRadius - 6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: List.generate(
                  destinations.length,
                  (i) => Expanded(
                    child: _GlassNavItem(
                      destination: destinations[i],
                      isActive: currentIndex == i,
                      isDark: isDark,
                      onTap: () {
                        if (i != currentIndex) HapticFeedback.selectionClick();
                        onTap(i);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Glass surface (blur + frosted container) ─────────────────────────────────

class _GlassBarSurface extends StatelessWidget {
  const _GlassBarSurface({required this.child, required this.isDark});

  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(
      Radius.circular(GlassNavigationBar._borderRadius),
    );

    // Glass colours — subtle teal tint, mostly transparent
    final reduceTransparency =
        MediaQuery.maybeOf(context)?.highContrast ?? false;
    final glassColor = reduceTransparency
        ? (isDark ? AppColors.surfaceDark : Colors.white)
        : isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.70)
            : Colors.white.withValues(alpha: 0.72);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.80);

    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.10);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 30,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GlassNavigationBar._blurSigma,
            sigmaY: GlassNavigationBar._blurSigma,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: radius,
              border: Border.all(
                color: borderColor,
                width: 0.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ── Individual navigation item ────────────────────────────────────────────────

class _GlassNavItem extends StatelessWidget {
  const _GlassNavItem({
    required this.destination,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.primary;
    final inactiveColor = isDark
        ? AppColors.mutedDark.withValues(alpha: 0.75)
        : AppColors.inkLight.withValues(alpha: 0.65);

    final itemColor = isActive ? activeColor : inactiveColor;

    return Semantics(
      button: true,
      selected: isActive,
      label: destination.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? destination.activeIcon : destination.icon,
              color: itemColor,
              size: 24,
            ),
            const SizedBox(height: 2),
            // Constant weight: switching tabs must never reflow the label.
            Text(
              destination.label,
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: itemColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _NavDestination {
  const _NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}
