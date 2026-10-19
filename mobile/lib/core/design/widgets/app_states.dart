import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';
import '../app_motion.dart';
import '../app_spacing.dart';
import '../app_typography.dart';

/// Centred activity indicator, optionally with a caption.
class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.label, this.radius = 12});

  final String? label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoActivityIndicator(radius: radius),
          if (label != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(label!,
                style:
                    AppTypography.footnote.copyWith(color: c.secondaryLabel)),
          ],
        ],
      ),
    );
  }
}

/// Pull-to-refresh for a `CustomScrollView`; place right after the nav bar
/// sliver. Needs bouncing physics (the app's scroll behaviour provides it).
class AppRefreshSliver extends StatelessWidget {
  const AppRefreshSliver({super.key, required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => CupertinoSliverRefreshControl(
        onRefresh: () {
          HapticFeedback.lightImpact();
          return onRefresh();
        },
      );
}

/// Empty / error / offline placeholder: symbol, title, message, action.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// Usually an `AppButton.tinted`.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: c.tertiaryLabel),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.title3.copyWith(color: c.label),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                message!,
                textAlign: TextAlign.center,
                style:
                    AppTypography.subheadline.copyWith(color: c.secondaryLabel),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Thin rounded progress track that fills from the leading edge (mirrors in
/// RTL) and animates to new values.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 4,
    this.color,
    this.trackColor,
  });

  /// 0…1; clamped.
  final double value;
  final double height;
  final Color? color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        // Full width: the track is the whole bar, the fill a fraction of it.
        width: double.infinity,
        height: height,
        child: ColoredBox(
          color: trackColor ?? c.fill,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value.clamp(0.0, 1.0)),
            duration: AppMotion.of(context, AppMotion.slow),
            curve: AppMotion.curve,
            builder: (context, v, _) => FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: v,
              child: ColoredBox(color: color ?? c.accent),
            ),
          ),
        ),
      ),
    );
  }
}
