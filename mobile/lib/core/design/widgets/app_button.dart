import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_typography.dart';

enum AppButtonVariant {
  /// Solid accent — the one primary action on a screen.
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
    this.loading = false,
    this.expand = false,
    this.small = false,
  });

  const AppButton.filled({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.small = false,
  }) : variant = AppButtonVariant.filled;

  const AppButton.tinted({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.small = false,
  }) : variant = AppButtonVariant.tinted;

  const AppButton.plain({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.small = false,
  }) : variant = AppButtonVariant.plain;

  const AppButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.small = false,
  }) : variant = AppButtonVariant.destructive;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

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
    final Color? background = switch (variant) {
      AppButtonVariant.filled => c.accent,
      AppButtonVariant.destructive => c.destructive,
      AppButtonVariant.tinted => c.accentTint,
      AppButtonVariant.plain => null,
    };
    final style = (small ? AppTypography.subheadline : AppTypography.headline)
        .weight(FontWeight.w600)
        .copyWith(color: enabled ? foreground : c.tertiaryLabel);

    final content = loading
        ? CupertinoActivityIndicator(
            color: background == null ? c.secondaryLabel : AppColors.onAccent,
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
            ],
          );

    final button = CupertinoButton(
      onPressed: enabled
          ? () {
              if (variant != AppButtonVariant.plain) {
                HapticFeedback.lightImpact();
              }
              onPressed!();
            }
          : null,
      color: background,
      disabledColor: background == null ? CupertinoColors.transparent : c.fill,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: small ? AppSpacing.ms : AppSpacing.ml,
        vertical: small ? AppSpacing.xs + 2 : AppSpacing.ms + 2,
      ),
      minimumSize: Size(
        AppSpacing.minTouchTarget,
        small ? 32 : (background == null ? AppSpacing.minTouchTarget : 50),
      ),
      borderRadius:
          BorderRadius.circular(small ? AppRadius.full : AppRadius.medium),
      child: content,
    );

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

  /// Draws a subtle circular fill behind the glyph (floating over content).
  final bool filled;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final glyph = Icon(icon, size: size, color: color ?? c.accent);
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
                    color: c.tertiaryFill, shape: BoxShape.circle),
                child: glyph,
              )
            : glyph,
      ),
    );
  }
}
