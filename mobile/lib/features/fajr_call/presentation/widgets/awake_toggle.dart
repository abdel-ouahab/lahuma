import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';

/// "استيقظ ✓" toggle: a check that fills when the person is awake.
class AwakeToggle extends StatelessWidget {
  const AwakeToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.name,
    this.size = 28,
    this.showLabel = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String name;
  final double size;

  /// Shows "استيقظ؟" / "استيقظ" next to the check, so the empty circle
  /// reads as something to tap (the log has no Call button beside it).
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final icon = Icon(
      value ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
      size: showLabel ? 20 : size,
      color: value ? c.success : c.tertiaryLabel,
    );
    return Semantics(
      container: true,
      button: true,
      toggled: value,
      label: context.tr('$name استيقظ', '$name is awake'),
      excludeSemantics: showLabel,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(AppSpacing.minTouchTarget),
        onPressed: () => onChanged(!value),
        child: !showLabel
            ? icon
            : Container(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.sm, AppSpacing.xs, AppSpacing.ms, AppSpacing.xs),
                decoration: ShapeDecoration(
                  color: value
                      ? c.success.withValues(alpha: 0.16)
                      : c.tertiaryGroupedBackground,
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      value
                          ? context.tr('استيقظ', 'Awake')
                          : context.tr('استيقظ؟', 'Awake?'),
                      style: AppTypography.footnote.copyWith(
                          color: value ? c.success : c.secondaryLabel,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
