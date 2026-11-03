import 'package:flutter/services.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/quran_pages.dart';
import 'khatma_labels.dart';

/// Picks a Mushaf page from [min] to 604: a slider for big moves, steps of
/// one and ten for the last few. Returns null when dismissed.
Future<int?> showPagePickerSheet(
  BuildContext context, {
  required String title,
  required int initial,
  int min = 1,
  String? confirmLabel,
}) {
  return showAppBottomSheet<int>(
    context,
    title: title,
    builder: (_) => _PagePicker(
      initial: initial.clamp(min, QuranPages.total),
      min: min,
      confirmLabel: confirmLabel,
    ),
  );
}

class _PagePicker extends StatefulWidget {
  const _PagePicker({
    required this.initial,
    required this.min,
    this.confirmLabel,
  });

  final int initial;
  final int min;
  final String? confirmLabel;

  @override
  State<_PagePicker> createState() => _PagePickerState();
}

class _PagePickerState extends State<_PagePicker> {
  late int _page = widget.initial;

  void _set(int page) {
    final p = page.clamp(widget.min, QuranPages.total);
    if (p == _page) return;
    HapticFeedback.selectionClick();
    setState(() => _page = p);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final place = _page == 0
        ? context.tr('لم تبدأ بعد', 'Not started yet')
        : pagePlace(context, _page);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text(
            ltr('$_page'),
            textAlign: TextAlign.center,
            style: AppTypography.tabular(AppTypography.largeTitle)
                .copyWith(color: c.label),
          ),
          Text(
            place,
            textAlign: TextAlign.center,
            style: AppTypography.subheadline.copyWith(color: c.secondaryLabel),
          ),
          const SizedBox(height: AppSpacing.sm),
          CupertinoSlider(
            value: _page.toDouble(),
            min: widget.min.toDouble(),
            max: QuranPages.total.toDouble(),
            divisions: QuranPages.total - widget.min,
            activeColor: c.accent,
            onChanged: (v) => _set(v.round()),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              for (final step in const [-10, -1, 1, 10])
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: AppButton.tinted(
                      label: ltr(step > 0 ? '+$step' : '−${-step}'),
                      small: true,
                      onPressed: () => _set(_page + step),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton.filled(
            label: widget.confirmLabel ?? context.tr('حفظ', 'Save'),
            expand: true,
            onPressed: () => Navigator.of(context).pop(_page),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
