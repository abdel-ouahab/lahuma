import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../../fajr_call/presentation/widgets/fajr_call_labels.dart';
import '../../domain/calendar_reminders.dart';
import '../../domain/islamic_events.dart';
import '../calendar_providers.dart';
import 'calendar_labels.dart';

/// Turns [event]'s reminder on or off, asking for notification permission
/// (in context, never at launch) when it is turned on.
Future<void> setEventReminder(
    WidgetRef ref, IslamicEvent event, bool on) async {
  await ref.read(calendarProvider.notifier).setReminded(event, on);
  if (!on) return;
  final n = ref.read(localNotificationsProvider);
  if (!await n.areEnabled()) await n.requestPermission();
}

/// An occasion's details: when, what the Sunnah says of it, and its
/// reminder.
class EventSheet extends ConsumerWidget {
  const EventSheet({super.key, required this.occurrence});

  final EventOccurrence occurrence;

  static Future<void> show(BuildContext context, EventOccurrence occurrence) =>
      showAppBottomSheet<void>(
        context,
        title: occurrence.event.label(arabic: context.isArabic),
        builder: (_) => EventSheet(occurrence: occurrence),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.palette;
    final e = occurrence.event;
    final arabic = context.isArabic;
    final reminded =
        ref.watch(calendarProvider.select((s) => s.settings.reminds(e)));
    final now = ref.watch(calendarClockProvider)();
    final days = calendarDaysBetween(now, occurrence.date);
    final tone = c.resolve(eventColor(e.kind));
    final evening = e.eveningOnly ||
        ref.watch(calendarProvider.select((s) => s.settings.timing)) ==
            CalendarReminderTiming.eveningBefore;

    final when = e.days > 1
        ? context.tr(
            'من ${formatDate(context, occurrence.date)} إلى ${formatDate(context, occurrence.lastDate)}',
            '${formatDate(context, occurrence.date)} to ${formatDate(context, occurrence.lastDate)}')
        : '${weekdayName(context, occurrence.date.weekday)} ${formatDate(context, occurrence.date)}';

    final details = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screenMargin, AppSpacing.sm, AppSpacing.screenMargin, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconTile(icon: eventIcon(e.kind), color: eventColor(e.kind)),
              const SizedBox(width: AppSpacing.ms),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatHijri(context, occurrence.hijri),
                      style: AppTypography.headline.copyWith(color: c.label),
                    ),
                    Text(
                      when,
                      style: AppTypography.footnote
                          .copyWith(color: c.secondaryLabel),
                    ),
                  ],
                ),
              ),
              if (days >= 0)
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: ShapeDecoration(
                    color: tone.withValues(alpha: c.isDark ? 0.22 : 0.12),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    daysUntil(context, days),
                    style: AppTypography.caption1
                        .weight(FontWeight.w600)
                        .copyWith(color: tone),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            eventKindLabel(context, e.kind),
            style: AppTypography.caption1
                .weight(FontWeight.w600)
                .copyWith(color: tone),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            e.description(arabic: arabic),
            style: AppTypography.body.copyWith(color: c.label, height: 1.6),
          ),
          if (e.bySighting) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr(
                  'يثبت هذا الموعد برؤية الهلال، فقد يتقدّم أو يتأخر يومًا عن التقويم.',
                  'This date is set by the moon sighting, so it may come a day earlier or later than the calendar.'),
              style: AppTypography.footnote.copyWith(color: c.secondaryLabel),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        details,
        AppListSection(
          hasLeading: true,
          margin: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screenMargin,
              0, AppSpacing.screenMargin, AppSpacing.md),
          footer: !reminded
              ? null
              : evening
                  ? context.tr('يصلك التذكير مساء اليوم السابق، الساعة 8.',
                      'You get it the evening before, at 8 pm.')
                  : context.tr('يصلك التذكير صباح اليوم نفسه، الساعة 8.',
                      'You get it on the morning of the day, at 8 am.'),
          children: [
            AppListTile(
              leading: const AppIconTile(
                  icon: CupertinoIcons.bell_fill, color: AppColors.tileRed),
              title: context.tr('ذكّرني بها', 'Remind me'),
              trailing: AppSwitch(
                value: reminded,
                onChanged: (v) => setEventReminder(ref, e, v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
