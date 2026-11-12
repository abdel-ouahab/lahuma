import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import '../app_colors.dart';
import '../app_layout.dart';
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

/// Sweeps a highlight across [child]'s shapes while content loads. Build the
/// placeholder from [AppSkeleton] bones; under reduce motion they stay still.
class AppShimmer extends StatelessWidget {
  const AppShimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final content = Semantics(
      label: Localizations.localeOf(context).languageCode == 'ar'
          ? 'جارٍ التحميل'
          : 'Loading',
      excludeSemantics: true,
      child: child,
    );
    if (MediaQuery.disableAnimationsOf(context)) return content;
    return Shimmer.fromColors(
      baseColor: c.fill,
      highlightColor: c.quaternaryLabel,
      period: const Duration(seconds: 1),
      child: content,
    );
  }
}

/// One placeholder bone. Width defaults to the available width.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = AppRadius.small,
  });

  /// A circle (avatars, reciter photos).
  const AppSkeleton.circle({super.key, required double size})
      : width = size,
        height = size,
        radius = AppRadius.full;

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          // Visible on its own (reduce motion); Shimmer repaints it otherwise.
          color: context.palette.fill,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// Lines of placeholder text; the last one is shorter, like a paragraph end.
class AppSkeletonText extends StatelessWidget {
  const AppSkeletonText({super.key, this.lines = 3, this.lineHeight = 12});

  final int lines;
  final double lineHeight;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < lines; i++) ...[
            if (i > 0) SizedBox(height: lineHeight * 0.75),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: i == lines - 1 && lines > 1 ? 0.6 : 1,
              child: AppSkeleton(height: lineHeight, radius: lineHeight / 2),
            ),
          ],
        ],
      );
}

/// Shimmering stand-in for a list of rows: optional leading tile, a title and
/// [lines] - 1 subtitle lines each. Fills the height it is given without
/// scrolling, so it can sit where the real list will appear.
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({
    super.key,
    this.itemCount = 8,
    this.lines = 2,
    this.leadingSize = 44,
    this.circleLeading = false,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.spacing = AppSpacing.ms,
  });

  final int itemCount;
  final int lines;

  /// Null drops the leading tile (text-only rows such as adhkar).
  final double? leadingSize;
  final bool circleLeading;
  final EdgeInsetsGeometry padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final leading = leadingSize;
    return AppShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: Column(
          children: [
            for (var i = 0; i < itemCount; i++) ...[
              if (i > 0) SizedBox(height: spacing),
              Row(
                children: [
                  if (leading != null) ...[
                    circleLeading
                        ? AppSkeleton.circle(size: leading)
                        : AppSkeleton(width: leading, height: leading),
                    const SizedBox(width: AppSpacing.ms),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Staggered widths so the rows don't read as a grid.
                        FractionallySizedBox(
                          alignment: AlignmentDirectional.centerStart,
                          widthFactor: const [0.55, 0.7, 0.45, 0.62][i % 4],
                          child: const AppSkeleton(height: 14, radius: 7),
                        ),
                        if (lines > 1) ...[
                          const SizedBox(height: AppSpacing.sm),
                          AppSkeletonText(lines: lines - 1, lineHeight: 10),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
    // Scrolls when it can't fit: a phone in landscape, large text.
    return AppScrollableCenter(
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

/// iOS notification-style count capsule: white digits on red; caps at 99+.
/// Zero is hidden unless [showZero], which draws it in neutral grey.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.count,
    this.semanticLabel,
    this.showZero = false,
  });

  final int count;
  final String? semanticLabel;
  final bool showZero;

  @override
  Widget build(BuildContext context) {
    if (count <= 0 && !showZero) return const SizedBox.shrink();
    final c = context.palette;
    final active = count > 0;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Container(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.destructive : c.fill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          count > 99 ? '99+' : '${count < 0 ? 0 : count}',
          textDirection: TextDirection.ltr,
          style: AppTypography.tabular(AppTypography.caption1).copyWith(
            color: active ? CupertinoColors.white : c.secondaryLabel,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}
