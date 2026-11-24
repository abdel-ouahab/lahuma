import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../fajr_call/presentation/widgets/fajr_call_labels.dart';
import '../../domain/hijri_date.dart';
import '../../domain/islamic_events.dart';
import '../calendar_providers.dart';
import '../widgets/calendar_labels.dart';
import '../widgets/event_sheet.dart';
import '../widgets/hijri_month_grid.dart';
import 'calendar_settings_screen.dart';

/// The Hijri calendar: today's date, the month as a grid with its
/// occasions, the chosen day's occasions, and what is coming. Each occasion
/// opens its details and reminder; the toolbar opens the reminders and the
/// date adjustment.
class IslamicCalendarScreen extends ConsumerStatefulWidget {
  const IslamicCalendarScreen({super.key});

  static const String path = '/calendar';

  @override
  ConsumerState<IslamicCalendarScreen> createState() =>
      _IslamicCalendarScreenState();
}

class _IslamicCalendarScreenState extends ConsumerState<IslamicCalendarScreen> {
  HijriMonth? _month;
  DateTime? _selected;

  void _show(HijriMonth m) {
    if (!ref.read(hijriConverterProvider).inRange(m)) return;
    HapticFeedback.selectionClick();
    setState(() => _month = m);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final converter = ref.watch(hijriConverterProvider);
    final events = ref.watch(islamicEventCalendarProvider);
    final now = ref.watch(calendarClockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final todayHijri = converter.fromGregorian(today);
    final month = _month ?? HijriMonth(todayHijri.year, todayHijri.month);
    final selected = _selected ?? today;
    final selectedHijri = converter.fromGregorian(selected);
    final settings = ref.watch(calendarProvider.select((s) => s.settings));

    // The next dozen occasions; the monthly white days only once.
    final upcoming = <EventOccurrence>[];
    var whiteDaysListed = false;
    for (final o in ref.watch(upcomingOccasionsProvider)) {
      if (o.event == IslamicEvent.whiteDays) {
        if (whiteDaysListed) continue;
        whiteDaysListed = true;
      }
      upcoming.add(o);
      if (upcoming.length == 12) break;
    }

    // The selected day's occasions, each dated from its first day.
    final dayOccasions = [
      for (final e in events.on(selectedHijri))
        () {
          final first = HijriDay(selectedHijri.year, selectedHijri.month, e.day);
          return EventOccurrence(
              event: e, hijri: first, date: converter.toGregorian(first));
        }(),
    ];

    final start = converter.toGregorian(HijriDay(month.year, month.month, 1));
    final end = start.add(
        Duration(days: converter.monthLength(month.year, month.month) - 1));
    final isCurrentMonth =
        month == HijriMonth(todayHijri.year, todayHijri.month);
    final rtl = Directionality.of(context) == TextDirection.rtl;

    Widget box(Widget child, {double top = AppSpacing.md}) => SliverPadding(
          padding: EdgeInsetsDirectional.fromSTEB(
              AppSpacing.screenMargin, top, AppSpacing.screenMargin, 0),
          sliver: SliverToBoxAdapter(child: child),
        );

    Widget occasionRow(EventOccurrence o, {bool showDays = true}) {
      final e = o.event;
      final days = calendarDaysBetween(today, o.date);
      return AppListTile(
        leading: AppIconTile(icon: eventIcon(e.kind), color: eventColor(e.kind)),
        title: e.label(arabic: context.isArabic),
        subtitle: e.monthly
            ? context.tr(
                '${formatHijriShort(context, o.hijri)} واليومان بعده · ${formatDate(context, o.date)}',
                '${formatHijriShort(context, o.hijri)} and the two days after · ${formatDate(context, o.date)}')
            : '${formatHijriShort(context, o.hijri)} · ${weekdayName(context, o.date.weekday)} ${formatDate(context, o.date)}',
        value: showDays
            ? (days < 0 ? context.tr('جارية', 'Under way') : daysUntil(context, days))
            : null,
        trailing: settings.reminds(e)
            ? Icon(CupertinoIcons.bell_fill, size: 14, color: c.accent)
            : null,
        chevron: true,
        onTap: () => EventSheet.show(context, o),
      );
    }

    return AppScaffold.largeTitle(
      title: context.tr('التقويم الهجري', 'Hijri calendar'),
      trailing: AppIconButton(
        icon: CupertinoIcons.bell,
        label: context.tr('التذكير وضبط التاريخ', 'Reminders and date'),
        onPressed: () => context.push(CalendarSettingsScreen.path),
      ),
      slivers: [
        // ── Today ─────────────────────────────────────────────────────────
        box(
          _TodayCard(
            today: today,
            hijri: todayHijri,
            next: upcoming.firstOrNull,
          ),
          top: AppSpacing.xs,
        ),

        // ── The month ─────────────────────────────────────────────────────
        box(
          AppCard(
            borderColor: c.gold.withValues(alpha: 0.35),
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.ms),
            child: Column(
              children: [
                Row(
                  children: [
                    // Back points to the start edge: right in RTL.
                    AppIconButton(
                      icon: rtl
                          ? CupertinoIcons.chevron_forward
                          : CupertinoIcons.chevron_back,
                      label: context.tr('الشهر السابق', 'Previous month'),
                      onPressed: () => _show(month.previous),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            formatHijriMonth(context, month),
                            textAlign: TextAlign.center,
                            style: AppTypography.headline
                                .weight(FontWeight.w700)
                                .copyWith(color: c.label),
                          ),
                          Text(
                            gregorianSpan(context, start, end),
                            textAlign: TextAlign.center,
                            style: AppTypography.footnote
                                .copyWith(color: c.secondaryLabel),
                          ),
                        ],
                      ),
                    ),
                    AppIconButton(
                      icon: rtl
                          ? CupertinoIcons.chevron_back
                          : CupertinoIcons.chevron_forward,
                      label: context.tr('الشهر التالي', 'Next month'),
                      onPressed: () => _show(month.next),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  // A swipe pages like the arrows: towards the end edge
                  // brings the next month in.
                  onHorizontalDragEnd: (d) {
                    final v = d.primaryVelocity ?? 0;
                    if (v.abs() < 200) return;
                    final forward = rtl ? v > 0 : v < 0;
                    _show(forward ? month.next : month.previous);
                  },
                  child: AnimatedSwitcher(
                    duration: AppMotion.of(context, AppMotion.fast),
                    child: HijriMonthGrid(
                      key: ValueKey(month),
                      month: month,
                      converter: converter,
                      events: events,
                      today: today,
                      selected: selected,
                      onSelect: (d) {
                        HapticFeedback.selectionClick();
                        setState(() => _selected = d);
                      },
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: AppMotion.of(context),
                  curve: AppMotion.curve,
                  child: isCurrentMonth && _selected == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: AppButton.plain(
                            label: context.tr('العودة إلى اليوم', 'Back to today'),
                            small: true,
                            onPressed: () => setState(() {
                              _month = null;
                              _selected = null;
                            }),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),

        // ── The chosen day ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: AppListSection(
            hasLeading: dayOccasions.isNotEmpty,
            margin: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screenMargin,
                AppSpacing.lg,
                AppSpacing.screenMargin,
                AppSpacing.sm),
            header:
                '${weekdayName(context, selected.weekday)} ${formatHijri(context, selectedHijri)} · ${formatDate(context, selected)}',
            children: [
              if (dayOccasions.isEmpty)
                AppListTile(
                  title: context.tr(
                      'لا مناسبة في هذا اليوم', 'No occasion on this day'),
                  titleStyle:
                      AppTypography.body.copyWith(color: c.secondaryLabel),
                )
              else
                for (final o in dayOccasions) occasionRow(o, showDays: false),
            ],
          ),
        ),

        // ── Coming up ─────────────────────────────────────────────────────
        if (upcoming.isNotEmpty)
          SliverToBoxAdapter(
            child: AppListSection(
              hasLeading: true,
              margin: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.screenMargin,
                  AppSpacing.md,
                  AppSpacing.screenMargin,
                  AppSpacing.sm),
              header: context.tr('المناسبات القادمة', 'Coming up'),
              footer: context.tr(
                  'التواريخ بتقويم أم القرى، وقد تختلف يومًا أو يومين حسب رؤية الهلال في بلدك. يمكنك ضبطها من زر الجرس في الأعلى.',
                  'Dates follow the Umm al-Qura calendar and may differ by a day or two with the moon sighting where you live. Adjust them with the bell button above.'),
              children: [for (final o in upcoming) occasionRow(o)],
            ),
          ),
      ],
    );
  }
}

/// Today in both calendars, and the next occasion.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.today, required this.hijri, this.next});

  final DateTime today;
  final HijriDay hijri;
  final EventOccurrence? next;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final green = c.resolve(AppColors.prayerGreen);
    final next = this.next;
    final days = next == null ? 0 : calendarDaysBetween(today, next.date);

    return AppCard(
      onTap: next == null ? null : () => EventSheet.show(context, next),
      borderColor: c.gold.withValues(alpha: 0.35),
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.ml, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${weekdayName(context, today.weekday)} · ${formatDate(context, today)}',
                  style:
                      AppTypography.footnote.copyWith(color: c.secondaryLabel),
                ),
                const SizedBox(height: 2),
                Text(
                  formatHijri(context, hijri),
                  style: AppTypography.title2
                      .weight(FontWeight.w700)
                      .copyWith(color: green, height: 1.25),
                ),
                if (next != null) ...[
                  const SizedBox(height: AppSpacing.ms),
                  Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.ms, vertical: AppSpacing.xs + 1),
                    decoration: ShapeDecoration(
                      color: c.accentTint,
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(eventIcon(next.event.kind), size: 15, color: green),
                        const SizedBox(width: AppSpacing.xs + 2),
                        Flexible(
                          child: Text(
                            '${next.event.label(arabic: context.isArabic)} · ${days < 0 ? context.tr('جارية', 'under way') : daysUntil(context, days)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.footnote
                                .weight(FontWeight.w600)
                                .copyWith(color: green),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          ExcludeSemantics(
            child: CustomPaint(
              size: const Size.square(64),
              painter: _MoonPainter(day: hijri.day, color: c.gold),
            ),
          ),
        ],
      ),
    );
  }
}

/// The moon on Hijri day [day]: a thin crescent on the 1st, full near the
/// 14th, waning after. The lit part is the disc less a shadow disc that
/// slides off to the left while waxing and back in from the right while
/// waning (as seen from the northern hemisphere).
class _MoonPainter extends CustomPainter {
  const _MoonPainter({required this.day, required this.color});

  final int day;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 - 2;
    final center = size.center(Offset.zero);
    canvas.drawCircle(
        center, r, Paint()..color = color.withValues(alpha: 0.16));
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.45),
    );

    // 0 → new, 0.5 → full, 1 → new again; never quite dark, so the 1st
    // still shows its crescent.
    final phase = ((day - 0.5) / 29.5).clamp(0.03, 0.97);
    // How far the shadow has slid: 0 (covers the disc) … 2r (clear of it).
    final shift = 2 * r * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
    final shadowAt = center + Offset(phase < 0.5 ? -shift : shift, 0);
    final lit = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: center, radius: r)),
      Path()..addOval(Rect.fromCircle(center: shadowAt, radius: r)),
    );
    canvas.drawPath(lit, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MoonPainter old) => old.day != day || old.color != color;
}
