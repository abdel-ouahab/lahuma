import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import '../app_colors.dart';
import '../app_motion.dart';
import '../app_spacing.dart';

/// Content card. No shadow: it separates from the page through background
/// contrast (`secondaryGroupedBackground` on `groupedBackground`), with
/// continuous corners. When tappable it scales down slightly on touch with an
/// interruptible spring (always animating from the live value).
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsetsDirectional.all(AppSpacing.md),
    this.color,
    this.gradient,
    this.radius = AppRadius.large,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Defaults to `secondaryGroupedBackground`. Ignored when [gradient] is set.
  final Color? color;
  final Gradient? gradient;
  final double radius;

  /// Optional hairline outline (e.g. the "selected" state).
  final Color? borderColor;

  /// Read by VoiceOver when the card is tappable.
  final String? semanticLabel;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  static const double _pressedScale = 0.97;

  // Unbounded so the spring may overshoot slightly past 1.0 on release.
  late final AnimationController _scale =
      AnimationController.unbounded(vsync: this, value: 1.0);

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _springTo(double target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _scale.value = target;
      return;
    }
    _scale.animateWith(
      SpringSimulation(AppMotion.spring, _scale.value, target, _scale.velocity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final borderRadius = BorderRadius.circular(widget.radius);
    final shape = RoundedSuperellipseBorder(
      borderRadius: borderRadius,
      side: widget.borderColor == null
          ? BorderSide.none
          : BorderSide(color: widget.borderColor!, width: 1),
    );

    Widget card = DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        color: widget.gradient == null
            ? (widget.color ?? c.secondaryGroupedBackground)
            : null,
        gradient: widget.gradient,
      ),
      child: ClipRSuperellipse(
        borderRadius: borderRadius,
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );

    if (widget.onTap == null) return card;

    card = AnimatedBuilder(
      animation: _scale,
      builder: (context, child) =>
          Transform.scale(scale: _scale.value, child: child),
      child: card,
    );

    // The gesture sits outside the transform so the hit area never shrinks.
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _springTo(_pressedScale),
        onTapUp: (_) => _springTo(1.0),
        onTapCancel: () => _springTo(1.0),
        child: card,
      ),
    );
  }
}

/// Settings-style rounded square with a white glyph on a system colour.
class AppIconTile extends StatelessWidget {
  const AppIconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 30,
  });

  final IconData icon;

  /// A token such as [AppColors.tileBlue]; resolved here.
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: context.palette.resolve(color),
          shape: AppRadius.continuous(size * 0.23),
        ),
        child: Icon(icon, size: size * 0.62, color: AppColors.onAccent),
      );
}
