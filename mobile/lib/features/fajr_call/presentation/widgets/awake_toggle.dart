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
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Semantics(
      container: true,
      button: true,
      toggled: value,
      label: context.tr('$name استيقظ', '$name is awake'),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(AppSpacing.minTouchTarget),
        onPressed: () => onChanged(!value),
        child: Icon(
          value ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
          size: size,
          color: value ? c.success : c.tertiaryLabel,
        ),
      ),
    );
  }
}
