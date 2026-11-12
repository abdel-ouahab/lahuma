import '../../../core/design/design.dart';
import '../../../core/localization/tr.dart';
import '../data/wird_repository.dart';

/// Today's wird on Home: the count against the goal, the last seven days as
/// Mushaf verse-end rosettes that fill with each day's reading (gold once
/// the goal was met, today ringed), and a way back into the reading.
///
/// Calm, not competitive: the streak shows only once it has been earned.
class WirdCard extends StatelessWidget {
  const WirdCard({
    super.key,
    required this.wird,
    required this.today,
    required this.onRead,
    required this.onChangeGoal,
  });

  final WirdState wird;

  /// The day the strip ends on (injected so tests can pin the week).
  final DateTime today;
  final VoidCallback onRead;
  final VoidCallback onChangeGoal;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final days = [
      for (var i = 6; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    final metDays = days.where((d) => wird.countOn(d) >= wird.goal).length;

    final status = wird.goalReached
        ? context.tr('تمّ وردك اليوم، تقبّل الله منك',
            'Today\'s wird is done. May Allah accept it.')
        : wird.ayahsToday == 0
            ? context.tr('لم تبدأ بعد اليوم', 'Not started today')
            : context.tr('بقيت ${wird.remaining} آية',
                '${wird.remaining} ayahs to go');

    return AppCard(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.ms),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Count and goal ────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  label: context.tr(
                    '${wird.ayahsToday} من ${wird.goal} آية اليوم. $status',
                    '${wird.ayahsToday} of ${wird.goal} ayahs today. $status',
                  ),
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${wird.ayahsToday}',
                            style: AppTypography.tabular(AppTypography.title1)
                                .copyWith(color: c.label, height: 1.1),
                          ),
                          const SizedBox(width: AppSpacing.xs + 2),
                          Flexible(
                            child: Text(
                              context.tr('من ${wird.goal} آية',
                                  'of ${wird.goal} ayahs'),
                              style: AppTypography.tabular(
                                      AppTypography.subheadline)
                                  .copyWith(color: c.secondaryLabel),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        style: AppTypography.footnote.copyWith(
                          color: wird.goalReached ? c.accent : c.secondaryLabel,
                          fontWeight: wird.goalReached ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton.plain(
                label: context.tr('تغيير الهدف', 'Change goal'),
                small: true,
                onPressed: onChangeGoal,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── The week ──────────────────────────────────────────────────
          Semantics(
            label: context.tr(
              'هذا الأسبوع: أتممت الورد في $metDays من 7 أيام',
              'This week: wird done on $metDays of 7 days',
            ),
            excludeSemantics: true,
            child: Row(
              children: [
                for (final d in days)
                  Expanded(
                    child: _Day(
                      day: d,
                      fraction: wird.goal <= 0
                          ? 0
                          : (wird.countOn(d) / wird.goal).clamp(0.0, 1.0),
                      isToday: d == days.last,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.ms),
          Container(height: AppSpacing.hairline, color: c.separator),
          const SizedBox(height: AppSpacing.xs),

          // ── Streak and action ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: wird.streak >= 2
                    ? Row(
                        children: [
                          Icon(CupertinoIcons.flame_fill,
                              size: 15, color: c.gold),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              context.tr('${wird.streak} أيام متتالية',
                                  '${wird.streak} days in a row'),
                              style: AppTypography.footnote
                                  .weight(FontWeight.w600)
                                  .copyWith(color: c.secondaryLabel),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              AppButton.plain(
                label: wird.goalReached
                    ? context.tr('اقرأ المزيد', 'Read more')
                    : wird.ayahsToday == 0
                        ? context.tr('ابدأ القراءة', 'Start reading')
                        : context.tr('تابع القراءة', 'Continue reading'),
                icon: CupertinoIcons.book,
                small: true,
                onPressed: onRead,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One day of the strip: a rosette carrying the day of the month, filled
/// from the bottom by that day's share of the goal, the weekday under it.
class _Day extends StatelessWidget {
  const _Day({required this.day, required this.fraction, required this.isToday});

  final DateTime day;
  final double fraction;
  final bool isToday;

  static const _ar = ['إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'];
  static const _en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final met = fraction >= 1;
    final weekday =
        (context.isArabic ? _ar : _en)[day.weekday - DateTime.monday];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 38,
          child: CustomPaint(
            painter: _RosettePainter(
              fraction: fraction,
              ring: isToday ? c.accent : null,
              outline: met ? c.gold : c.opaqueSeparator,
              partial: c.accent.withValues(alpha: c.isDark ? 0.42 : 0.24),
              full: c.gold,
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: AppTypography.tabular(AppTypography.caption1).copyWith(
                  // Gold is light in both themes, so the number on it is ink.
                  color: met ? AppColors.inkDark : c.label,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          weekday,
          maxLines: 1,
          overflow: TextOverflow.visible,
          softWrap: false,
          style: AppTypography.caption2.copyWith(
            color: isToday ? c.accent : c.tertiaryLabel,
            fontWeight: isToday ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }
}

class _RosettePainter extends CustomPainter {
  const _RosettePainter({
    required this.fraction,
    required this.outline,
    required this.partial,
    required this.full,
    this.ring,
  });

  final double fraction;
  final Color outline;
  final Color partial;
  final Color full;
  final Color? ring;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;
    final marker = ayahMarker(center, r);

    if (fraction > 0) {
      final top = center.dy + r - 2 * r * fraction;
      canvas
        ..save()
        ..clipPath(marker)
        ..drawRect(
          Rect.fromLTRB(0, top, size.width, size.height),
          Paint()..color = fraction >= 1 ? full : partial,
        )
        ..restore();
    }

    canvas.drawPath(
      marker,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = outline,
    );

    if (ring != null) {
      canvas.drawCircle(
        center,
        r + 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = ring!,
      );
    }
  }

  @override
  bool shouldRepaint(_RosettePainter old) =>
      old.fraction != fraction ||
      old.outline != outline ||
      old.partial != partial ||
      old.full != full ||
      old.ring != ring;
}
