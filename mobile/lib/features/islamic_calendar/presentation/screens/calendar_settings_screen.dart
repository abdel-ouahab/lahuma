import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../domain/calendar_reminders.dart';
import '../../domain/hijri_date.dart';
import '../../domain/islamic_events.dart';
import '../calendar_providers.dart';
import '../widgets/calendar_labels.dart';
import '../widgets/event_sheet.dart';

/// The calendar's settings: whether and when the occasions are reminded,
/// which ones, and the Hijri date's adjustment for the local sighting.
class CalendarSettingsScreen extends ConsumerWidget {
  const CalendarSettingsScreen({super.key});

  static const String path = '/calendar/settings';

  /// "متقدّم بيوم" / "1 day ahead".
  static String adjustmentLabel(BuildContext context, int days) {
    if (days == 0) return context.tr('بدون تعديل', 'No adjustment');
    final n = days.abs();
    if (context.isArabic) {
      final amount = n == 1 ? 'بيوم' : 'بيومين';
      return days > 0 ? 'متقدّم $amount' : 'متأخر $amount';
    }
    final amount = n == 1 ? '1 day' : '$n days';
    return days > 0 ? '$amount ahead' : '$amount behind';
  }

  /// "10 ذو الحجة", "من 21 رمضان" or "13–15 من كل شهر".
  static String whenLabel(BuildContext context, IslamicEvent e) {
    if (e.monthly) {
      return context.tr(
          '${ltr('${e.day}–${e.day + e.days - 1}')} من كل شهر',
          '${e.day}–${e.day + e.days - 1} of every month');
    }
    final day = formatHijriShort(context, HijriDay(0, e.month, e.day));
    return e.days > 1 ? context.tr('من $day', 'From $day') : day;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.palette;
    final state = ref.watch(calendarProvider);
    final s = state.settings;
    final notifier = ref.read(calendarProvider.notifier);
    final now = ref.watch(calendarClockProvider)();
    final preview = HijriConverter(adjustment: s.adjustment).fromGregorian(now);

    Future<void> turnOn(bool on) async {
      await notifier.setRemindersOn(on);
      if (!on) return;
      final n = ref.read(localNotificationsProvider);
      // Asked here, in context, never at launch.
      if (!await n.areEnabled()) await n.requestPermission();
    }

    void step(int delta) {
      final next = s.adjustment + delta;
      if (next.abs() > CalendarSettings.maxAdjustment) return;
      HapticFeedback.selectionClick();
      notifier.setAdjustment(next);
    }

    return AppScaffold.largeTitle(
      title: context.tr('التذكير وضبط التاريخ', 'Reminders & date'),
      slivers: [
        if (!state.loaded)
          const SliverFillRemaining(child: AppLoader())
        else ...[
          // ── Reminders ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: AppListSection(
              hasLeading: true,
              margin: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.screenMargin,
                  AppSpacing.sm,
                  AppSpacing.screenMargin,
                  AppSpacing.sm),
              footer: s.remindersOn
                  ? null
                  : context.tr(
                      'لن يصلك تذكير بالمناسبات. فعّله ليصلك تذكير قبل رمضان والعيدين وأيام الصيام.',
                      "You won't get occasion reminders. Turn them on for Ramadan, the two Eids and the fasting days."),
              children: [
                AppListTile(
                  leading: const AppIconTile(
                      icon: CupertinoIcons.bell_fill, color: AppColors.tileRed),
                  title: context.tr('التذكير بالمناسبات', 'Occasion reminders'),
                  trailing: AppSwitch(value: s.remindersOn, onChanged: turnOn),
                ),
              ],
            ),
          ),
          if (s.remindersOn)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin,
                    AppSpacing.sm, AppSpacing.screenMargin, AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSegmentedControl<CalendarReminderTiming>(
                      segments: {
                        CalendarReminderTiming.eveningBefore:
                            context.tr('مساء اليوم السابق', 'The evening before'),
                        CalendarReminderTiming.morningOf:
                            context.tr('صباح اليوم نفسه', 'That morning'),
                      },
                      value: s.timing,
                      onChanged: notifier.setTiming,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                          start: AppSpacing.xs),
                      child: Text(
                        s.timing == CalendarReminderTiming.eveningBefore
                            ? context.tr(
                                'الساعة 8 مساءً، لتنوي الصيام وتستعد.',
                                'At 8 pm, to intend the fast and get ready.')
                            : context.tr(
                                'الساعة 8 صباحًا. الليالي ورمضان يُذكَّر بها مساء اليوم السابق دائمًا.',
                                'At 8 am. Nights and Ramadan are always reminded the evening before.'),
                        style: AppTypography.footnote
                            .copyWith(color: c.secondaryLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Which occasions ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: AnimatedOpacity(
              opacity: s.remindersOn ? 1 : 0.5,
              duration: AppMotion.standard,
              child: AppListSection(
                hasLeading: true,
                margin: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.screenMargin,
                    AppSpacing.md,
                    AppSpacing.screenMargin,
                    AppSpacing.sm),
                header: context.tr('المناسبات', 'Occasions'),
                children: [
                  for (final e in IslamicEvent.values)
                    AppListTile(
                      leading: AppIconTile(
                          icon: eventIcon(e.kind), color: eventColor(e.kind)),
                      title: e.label(arabic: context.isArabic),
                      subtitle: whenLabel(context, e),
                      trailing: AppSwitch(
                        value: s.events.contains(e),
                        onChanged: (v) => setEventReminder(ref, e, v),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── The Hijri date ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: AppListSection(
              hasLeading: true,
              margin: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.screenMargin,
                  AppSpacing.lg,
                  AppSpacing.screenMargin,
                  AppSpacing.sm),
              header: context.tr('ضبط التاريخ الهجري', 'Hijri date adjustment'),
              footer: context.tr(
                  'يُحسب التقويم بتقويم أم القرى. إن بدأ الشهر في بلدك قبله أو بعده برؤية الهلال، عدّله هنا بيوم أو يومين. اليوم بعد الضبط: ${formatHijri(context, preview)}.',
                  'The calendar follows Umm al-Qura. If the month starts a day or two earlier or later where you live, adjust it here. Today with this setting: ${formatHijri(context, preview)}.'),
              children: [
                AppListTile(
                  leading: const AppIconTile(
                      icon: CupertinoIcons.moon_fill, color: AppColors.tileTeal),
                  title: adjustmentLabel(context, s.adjustment),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIconButton(
                        icon: CupertinoIcons.minus_circle,
                        label: context.tr('يوم أقل', 'One day less'),
                        onPressed: s.adjustment > -CalendarSettings.maxAdjustment
                            ? () => step(-1)
                            : null,
                      ),
                      AppIconButton(
                        icon: CupertinoIcons.plus_circle,
                        label: context.tr('يوم أكثر', 'One day more'),
                        onPressed: s.adjustment < CalendarSettings.maxAdjustment
                            ? () => step(1)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
