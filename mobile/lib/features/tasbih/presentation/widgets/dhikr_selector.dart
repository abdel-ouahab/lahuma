import 'package:flutter/services.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/tasbih.dart';
import 'tasbih_labels.dart';

/// Horizontal row of adhkar to count, ending with "add". The selected chip
/// is filled with the accent and kept in view; a check marks adhkar whose
/// target is reached. Long-press a chip for its options.
class DhikrSelector extends StatefulWidget {
  const DhikrSelector({
    super.key,
    required this.adhkar,
    required this.selectedId,
    required this.isReached,
    required this.onSelected,
    required this.onOptions,
    required this.onAdd,
  });

  final List<TasbihDhikr> adhkar;
  final String selectedId;
  final bool Function(TasbihDhikr dhikr) isReached;
  final ValueChanged<TasbihDhikr> onSelected;
  final ValueChanged<TasbihDhikr> onOptions;
  final VoidCallback onAdd;

  @override
  State<DhikrSelector> createState() => _DhikrSelectorState();
}

class _DhikrSelectorState extends State<DhikrSelector> {
  final Map<String, GlobalKey> _keys = {};

  GlobalKey _keyOf(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _revealSelected(animate: false);
  }

  @override
  void didUpdateWidget(DhikrSelector old) {
    super.didUpdateWidget(old);
    if (old.selectedId != widget.selectedId) _revealSelected(animate: true);
  }

  /// Scrolls the selected chip to the middle once it has been laid out.
  void _revealSelected({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[widget.selectedId]?.currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: animate ? AppMotion.of(context) : Duration.zero,
        curve: AppMotion.curve,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.screenMargin,
          vertical: AppSpacing.xs,
        ),
        itemCount: widget.adhkar.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          if (i == widget.adhkar.length) return _AddChip(onTap: widget.onAdd);
          final dhikr = widget.adhkar[i];
          return _DhikrChip(
            key: _keyOf(dhikr.id),
            dhikr: dhikr,
            selected: dhikr.id == widget.selectedId,
            reached: widget.isReached(dhikr),
            onTap: () => widget.onSelected(dhikr),
            onLongPress: () => widget.onOptions(dhikr),
          );
        },
      ),
    );
  }
}

class _DhikrChip extends StatelessWidget {
  const _DhikrChip({
    super.key,
    required this.dhikr,
    required this.selected,
    required this.reached,
    required this.onTap,
    required this.onLongPress,
  });

  final TasbihDhikr dhikr;
  final bool selected;
  final bool reached;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final foreground = selected ? c.onAccent : c.label;
    final secondary =
        selected ? c.onAccent.withValues(alpha: 0.75) : c.secondaryLabel;
    final target = dhikr.target;

    return Semantics(
      button: true,
      selected: selected,
      label: dhikr.text,
      value: targetLabel(context, target),
      hint: context.tr('اضغط مطولاً للخيارات', 'Long-press for options'),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          if (!selected) HapticFeedback.selectionClick();
          onTap();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onLongPress();
        },
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.fast),
          curve: AppMotion.curve,
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.ms + 2),
          decoration: ShapeDecoration(
            color: selected ? c.accent : c.tertiaryFill,
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (reached) ...[
                Icon(CupertinoIcons.checkmark_seal_fill,
                    size: 16, color: selected ? foreground : c.success),
                const SizedBox(width: AppSpacing.xs + 2),
              ],
              Flexible(
                child: Text(
                  dhikr.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: AppTypography.subheadline
                      .weight(FontWeight.w600)
                      .copyWith(color: foreground),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              target == null
                  ? Icon(CupertinoIcons.infinite, size: 16, color: secondary)
                  : LtrText(
                      formatCount(target),
                      style: AppTypography.tabular(AppTypography.footnote)
                          .copyWith(color: secondary),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Semantics(
      button: true,
      label: context.tr('إضافة ذكر', 'Add a dhikr'),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: StadiumBorder(
              side: BorderSide(color: c.separator, width: 1),
            ),
          ),
          child: Icon(CupertinoIcons.plus, size: 18, color: c.accent),
        ),
      ),
    );
  }
}
