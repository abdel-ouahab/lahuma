import 'package:flutter/services.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import 'fajr_call_labels.dart';

const _rowPadding = EdgeInsetsDirectional.fromSTEB(
    AppSpacing.md, AppSpacing.ms - 1, AppSpacing.md, AppSpacing.ms - 1);

/// List row with a title, a live value ("20 ث") and an iOS slider under it.
class AppSliderRow extends StatelessWidget {
  const AppSliderRow({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
    this.step = 1,
    this.subtitle,
  });

  final String title;

  /// What the setting does, under the title.
  final String? subtitle;
  final int value;
  final int min;
  final int max;
  final int step;
  final String Function(int value) label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Padding(
      padding: _rowPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: AppTypography.body.copyWith(color: c.label)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(label(value),
                  style: AppTypography.tabular(AppTypography.body)
                      .copyWith(color: c.secondaryLabel)),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle!,
                  style:
                      AppTypography.footnote.copyWith(color: c.secondaryLabel)),
            ),
          Semantics(
            label: title,
            hint: subtitle,
            value: label(value),
            child: CupertinoSlider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: (max - min) ~/ step,
              activeColor: c.accent,
              onChanged: (v) {
                final next = v.round();
                if (next != value) {
                  HapticFeedback.selectionClick();
                  onChanged(next);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// List row with a − value + stepper, adjustable by VoiceOver / TalkBack.
class AppStepperRow extends StatelessWidget {
  const AppStepperRow({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
    this.step = 1,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final int value;
  final int min;
  final int max;
  final int step;
  final String Function(int value) label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final canDown = value - step >= min;
    final canUp = value + step <= max;
    void set(int v) {
      HapticFeedback.selectionClick();
      onChanged(v.clamp(min, max));
    }

    return Semantics(
      label: title,
      value: label(value),
      increasedValue: canUp ? label(value + step) : null,
      decreasedValue: canDown ? label(value - step) : null,
      onIncrease: canUp ? () => set(value + step) : null,
      onDecrease: canDown ? () => set(value - step) : null,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.body.copyWith(color: c.label)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: AppTypography.footnote
                              .copyWith(color: c.secondaryLabel)),
                  ],
                ),
              ),
            ),
            ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIconButton(
                    icon: CupertinoIcons.minus_circle,
                    label: context.tr('إنقاص', 'Decrease'),
                    onPressed: canDown ? () => set(value - step) : null,
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 56),
                    child: Text(
                      label(value),
                      textAlign: TextAlign.center,
                      style: AppTypography.tabular(AppTypography.subheadline)
                          .copyWith(color: c.secondaryLabel),
                    ),
                  ),
                  AppIconButton(
                    icon: CupertinoIcons.plus_circle,
                    label: context.tr('زيادة', 'Increase'),
                    onPressed: canUp ? () => set(value + step) : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seven day toggles. An empty selection means every day.
class WeekdayChips extends StatelessWidget {
  const WeekdayChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _rowPadding,
      // Seven equal columns: the labels shrink to fit rather than wrap, so
      // the week always reads as one line.
      child: Row(
        children: [
          for (final d in weekOrder(context))
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _chip(context, d),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, int day) {
    final c = context.palette;
    final every = selected.isEmpty;
    final on = every || selected.contains(day);
    return Semantics(
      button: true,
      selected: on,
      label: weekdayName(context, day),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          final base = every ? {1, 2, 3, 4, 5, 6, 7} : {...selected};
          on ? base.remove(day) : base.add(day);
          // All seven, or none, both mean "every day".
          onChanged(base.length == 7 || base.isEmpty ? {} : base);
        },
        child: Container(
          constraints:
              const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: on ? c.accent : c.tertiaryFill,
            shape: AppRadius.continuous(AppRadius.small),
          ),
          child: ExcludeSemantics(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                weekdayShort(context, day),
                maxLines: 1,
                style: AppTypography.footnote
                    .weight(FontWeight.w600)
                    .copyWith(color: on ? c.onAccent : c.label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a form control so it sits in an [AppListSection] with row padding.
class AppPaddedRow extends StatelessWidget {
  const AppPaddedRow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: _rowPadding, child: child);
}
