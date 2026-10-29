import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// 4-item persistent bottom navigation bar for Lahuma.
/// Items: الرئيسية / القرآن / العلامات / المزيد
class LahumaBottomNavigation extends StatelessWidget {
  const LahumaBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_NavItem> _items = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'الرئيسية',
    ),
    _NavItem(
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
      label: 'القرآن',
    ),
    _NavItem(
      icon: Icons.bookmark_outline_rounded,
      activeIcon: Icons.bookmark_rounded,
      label: 'العلامات',
    ),
    _NavItem(
      icon: Icons.more_horiz_rounded,
      activeIcon: Icons.more_horiz_rounded,
      label: 'المزيد',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              _items.length,
              (index) => _NavItemWidget(
                item: _items[index],
                isActive: currentIndex == index,
                onTap: () => onTap(index),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavItemWidget extends StatelessWidget {
  const _NavItemWidget({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark ? AppColors.mutedDark : AppColors.mutedLight;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? item.activeIcon : item.icon,
                key: ValueKey(isActive),
                color: isActive ? AppColors.primary : inactiveColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: GoogleFonts.cairo(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? AppColors.primary : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
