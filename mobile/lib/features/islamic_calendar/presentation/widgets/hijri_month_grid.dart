import 'package:flutter/material.dart' show MaterialLocalizations;
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../fajr_call/presentation/widgets/fajr_call_labels.dart';
import '../../domain/hijri_date.dart';
import '../../domain/islamic_events.dart';
import 'calendar_labels.dart';

/// One Hijri month as a week grid: the Hijri day large, the Gregorian day
/// under it, and a dot per occasion. Today is filled in the accent, the
/// selected day ringed in gold. Weeks start on the locale's first day
/// (Saturday in Arabic, Sunday in English).
class HijriMonthGrid extends StatelessWidget {
  const HijriMonthGrid({
    super.key,
    required this.month,
    required this.converter,
    required this.events,
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  final HijriMonth month;
  final HijriConverter converter;
  final IslamicEventCalendar events;
  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final first = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final start = converter.toGregorian(HijriDay(month.year, month.month, 1));
    final length = converter.monthLength(month.year, month.month);
    // Sunday is 0 here, as in MaterialLocalizations.
    final lead = (start.weekday % 7 - first + 7) % 7;
    final cells = lead + length;
    final rows = (cells / 7).ceil();

    int weekdayAt(int column) {
      final i = (first + column) % 7;
      return i == 0 ? DateTime.sunday : i;
    }

    return Column(
      children: [
        Row(
          children: [
            for (var col = 0; col < 7; col++)
              Expanded(
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      weekdayShort(context, weekdayAt(col)),
                      maxLines: 1,
                      style: AppTypography.caption2.copyWith(
                        color: weekdayAt(col) == DateTime.friday
                            ? c.accent
                            : c.secondaryLabel,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var row = 0; row < rows; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: () {
                      final day = row * 7 + col - lead + 1;
                      if (day < 1 || day > length) {
                        return const SizedBox.shrink();
                      }
                      final h = HijriDay(month.year, month.month, day);
                      final date = start.add(Duration(days: day - 1));
                      return _DayCell(
                        hijri: h,
                        date: date,
                        events: events.on(h),
                        isToday: calendarDaysBetween(today, date) == 0,
                        isSelected: calendarDaysBetween(selected, date) == 0,
                        onTap: () => onSelect(date),
                      );
                    }(),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.hijri,
    required this.date,
    required this.events,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final HijriDay hijri;
  final DateTime date;
  final List<IslamicEvent> events;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final marked = events.isNotEmpty;
    final ink = isToday ? AppColors.onAccent : c.label;
    final sub = isToday
        ? AppColors.onAccent.withValues(alpha: 0.85)
        : c.secondaryLabel;
    final fill = isToday
        ? c.accent
        : marked
            ? c.resolve(eventColor(events.first.kind)).withValues(
                alpha: c.isDark ? 0.18 : 0.1)
            : CupertinoColors.transparent;

    final label = [
      weekdayName(context, date.weekday),
      formatHijri(context, hijri),
      formatDate(context, date),
      if (isToday) context.tr('اليوم', 'Today'),
      for (final e in events) e.label(arabic: context.isArabic),
    ].join(context.tr('، ', ', '));

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: AnimatedContainer(
            duration: AppMotion.of(context, AppMotion.fast),
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(
                color: isSelected && !isToday
                    ? c.gold
                    : CupertinoColors.transparent,
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${hijri.day}',
                    textDirection: TextDirection.ltr,
                    style: AppTypography.tabular(AppTypography.callout)
                        .copyWith(
                      color: ink,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${date.day}',
                    textDirection: TextDirection.ltr,
                    style: AppTypography.tabular(AppTypography.caption2)
                        .copyWith(color: sub, height: 1.2),
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final e in events.take(3))
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: isToday
                                ? AppColors.onAccent
                                : c.resolve(eventColor(e.kind)),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
