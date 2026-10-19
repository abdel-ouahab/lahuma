import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Spring tuned like Apple's UI springs: critically damped, response 0.3s.
/// stiffness = (2π / response)², damping = 4π·ζ / response (mass 1).
const SpringDescription kLahumaSpring = SpringDescription(
  mass: 1,
  stiffness: 439,
  damping: 41.9,
);

/// Base Lahuma card: flat surface, hairline edge, no coloured shadow.
/// Responds on touch-down with a spring-driven scale that can be interrupted
/// and reversed at any instant (it always animates from the live value).
class LahumaCard extends StatefulWidget {
  const LahumaCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.gradient,
    this.color,
    this.borderRadius,
    this.shadow,
    this.border,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;
  final Color? color;
  final BorderRadiusGeometry? borderRadius;
  final List<BoxShadow>? shadow;
  final Border? border;

  @override
  State<LahumaCard> createState() => _LahumaCardState();
}

class _LahumaCardState extends State<LahumaCard>
    with SingleTickerProviderStateMixin {
  static const double _pressedScale = 0.97;

  // Unbounded so the spring may overshoot slightly past 1.0 on release.
  late final AnimationController _controller =
      AnimationController.unbounded(vsync: this, value: 1.0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _springTo(double target) {
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = target;
      return;
    }
    _controller.animateWith(
      SpringSimulation(
        kLahumaSpring,
        _controller.value, // presentation value, never the old target
        target,
        _controller.velocity,
      ),
    );
  }

  void _onTapDown(TapDownDetails _) => _springTo(_pressedScale);
  void _onTapUp(TapUpDetails _) => _springTo(1.0);
  void _onTapCancel() => _springTo(1.0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = widget.borderRadius ?? BorderRadius.circular(AppRadius.xl);
    final hairline = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    // Light mode: a whisper of lift. Dark mode: separation comes from the
    // lighter surface, so no shadow at all.
    final shadow = widget.shadow ??
        (isDark
            ? const <BoxShadow>[]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ]);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        scale: _controller.value,
        child: child,
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: widget.onTap != null ? _onTapDown : null,
        onTapUp: widget.onTap != null ? _onTapUp : null,
        onTapCancel: widget.onTap != null ? _onTapCancel : null,
        child: Container(
          decoration: BoxDecoration(
            color: widget.gradient == null
                ? (widget.color ??
                    (isDark ? AppColors.surfaceDark : AppColors.surfaceLight))
                : null,
            gradient: widget.gradient,
            borderRadius: radius,
            boxShadow: shadow,
            border: widget.border ?? Border.all(color: hairline, width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: radius as BorderRadius,
            child: Padding(
              padding: widget.padding ??
                  const EdgeInsets.all(AppSpacing.md),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact version of LahumaCard — no shadow by default.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LahumaCard(
      onTap: onTap,
      padding: padding,
      child: child,
    );
  }
}
