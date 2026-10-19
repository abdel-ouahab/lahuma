import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../theme/app_colors.dart';
import 'app_card.dart' show kLahumaSpring;

/// Circular header button shared by every screen. Fills instantly on
/// touch-down, springs back on release. Labelled for screen readers.
class LahumaIconButton extends StatefulWidget {
  const LahumaIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  State<LahumaIconButton> createState() => _LahumaIconButtonState();
}

class _LahumaIconButtonState extends State<LahumaIconButton>
    with SingleTickerProviderStateMixin {
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
    _controller.animateWith(SpringSimulation(
        kLahumaSpring, _controller.value, target, _controller.velocity));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => _springTo(0.92),
          onTapUp: (_) => _springTo(1.0),
          onTapCancel: () => _springTo(1.0),
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, child) =>
                Transform.scale(scale: _controller.value, child: child),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.05),
                ),
                child: Icon(
                  widget.icon,
                  size: 19,
                  color: isDark ? AppColors.textDark : AppColors.inkDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
