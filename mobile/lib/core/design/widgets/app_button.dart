import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_typography.dart';
import 'app_direction.dart';
import 'app_surface.dart';

enum AppButtonVariant {
  /// Accent gradient with a lit edge — the one primary action on a screen.
  filled,

  /// Accent wash with accent label — secondary actions.
  tinted,

  /// Label only — tertiary actions, nav-bar actions, links.
  plain,

  /// Solid red — irreversible actions (delete, sign out).
  destructive,
}

/// iOS button: opacity feedback on press (no ripple), 44-pt minimum target,
/// optional loading state and a light haptic on confirmation.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.small = false,
  });

  const AppButton.filled({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.small = false,
  }) : variant = AppButtonVariant.filled;

  const AppButton.tinted({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.small = false,
  }) : variant = AppButtonVariant.tinted;

  const AppButton.plain({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.small = false,
  }) : variant = AppButtonVariant.plain;

  const AppButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.small = false,
  }) : variant = AppButtonVariant.destructive;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

  /// A glyph after the label that points the way the button goes (e.g.
  /// `chevron_forward` on "Next"); mirrored in RTL.
  final IconData? trailingIcon;

  /// Shows a spinner and ignores taps while true.
  final bool loading;

  /// Full-width (bottom-of-screen primary action).
  final bool expand;

  /// Compact capsule (inline / chips row).
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final enabled = onPressed != null && !loading;

    final Color foreground = switch (variant) {
      AppButtonVariant.filled ||
      AppButtonVariant.destructive =>
        AppColors.onAccent,
      AppButtonVariant.tinted || AppButtonVariant.plain => c.accent,
    };
    // The enabled filled button paints its gradient behind the CupertinoButton
    // (which only takes a flat colour); disabled it falls back to `fill`.
    final gradient = variant == AppButtonVariant.filled && enabled;
    final Color? background = switch (variant) {
      AppButtonVariant.filled => gradient ? null : c.accent,
      AppButtonVariant.destructive => c.destructive,
      AppButtonVariant.tinted => c.accentTint,
      AppButtonVariant.plain => null,
    };
    final style = (small ? AppTypography.subheadline : AppTypography.headline)
        .weight(FontWeight.w600)
        .copyWith(color: enabled ? foreground : c.tertiaryLabel);

    final content = loading
        ? CupertinoActivityIndicator(
            color: background == null && !gradient
                ? c.secondaryLabel
                : AppColors.onAccent,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: small ? 16 : 19, color: style.color),
                const SizedBox(width: AppSpacing.xs + 2),
              ],
              Flexible(
                child: Text(
                  label,
                  style: style,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: AppSpacing.xs + 2),
                AppDirectionalIcon(trailingIcon!,
                    size: small ? 14 : 17, color: style.color),
              ],
            ],
          );

    final radius = small ? AppRadius.full : AppRadius.medium;
    final hasSurface = background != null || variant == AppButtonVariant.filled;

    Widget button = CupertinoButton(
      onPressed: enabled
          ? () {
              if (variant != AppButtonVariant.plain) {
                HapticFeedback.lightImpact();
              }
              onPressed!();
            }
          : null,
      color: background,
      disabledColor: hasSurface ? c.fill : CupertinoColors.transparent,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: small ? AppSpacing.ms : AppSpacing.ml,
        vertical: small ? AppSpacing.xs + 2 : AppSpacing.ms + 2,
      ),
      minimumSize: Size(
        AppSpacing.minTouchTarget,
        small ? 32 : (hasSurface ? 50 : AppSpacing.minTouchTarget),
      ),
      borderRadius: BorderRadius.circular(radius),
      child: content,
    );

    if (gradient) {
      final ShapeBorder shape =
          small ? const StadiumBorder() : AppRadius.continuous(radius);
      button = CustomPaint(
        foregroundPainter: AppEdgeHighlight(shape: shape),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: shape,
            gradient: AppColors.accentGradient,
            shadows: [
              BoxShadow(
                color: context.palette.shadow(0.6),
                offset: const Offset(0, 10),
                blurRadius: 24,
              ),
            ],
          ),
          child: button,
        ),
      );
    }

    // A spinner must not change the button's width.
    final semantics = Semantics(
      button: true,
      enabled: enabled,
      label: loading ? label : null,
      child: button,
    );
    return expand
        ? SizedBox(width: double.infinity, child: semantics)
        : semantics;
  }
}

/// Round icon-only button (nav-bar actions, card accessories). 44-pt hit area,
/// opacity press feedback, labelled for VoiceOver.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.label,
    this.filled = false,
    this.color,
    this.size = 22,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Accessibility label (and tooltip-equivalent). Required.
  final String label;

  /// Draws an accent-gradient disc behind a white glyph (floating over
  /// content); [color] is ignored then.
  final bool filled;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final glyph = Icon(
      icon,
      size: filled ? size * 0.8 : size,
      color: filled ? AppColors.onAccent : (color ?? c.accent),
    );
    return Semantics(
      button: true,
      label: label,
      child: CupertinoButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(AppSpacing.minTouchTarget),
        child: filled
            ? Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: c.shadow(0.5),
                      offset: const Offset(0, 6),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: glyph,
              )
            : glyph,
      ),
    );
  }
}
