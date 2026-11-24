import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/widgets/shortcut_tile.dart';
import '../../domain/islamic_events.dart';
import '../calendar_providers.dart';
import '../screens/islamic_calendar_screen.dart';
import 'calendar_labels.dart';

/// Home's shortcut to the Hijri calendar: today's Hijri date and the next
/// occasion, over the night scene (the calendar follows the moon).
class CalendarHomeTile extends ConsumerWidget {
  const CalendarHomeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(calendarClockProvider)();
    final today = ref.watch(hijriConverterProvider).fromGregorian(now);
    final next = ref
        .watch(upcomingOccasionsProvider)
        .where((o) =>
            o.event != IslamicEvent.whiteDays &&
            calendarDaysBetween(now, o.date) > 0)
        .firstOrNull;
    final date = formatHijri(context, today);

    return ShortcutTile(
      title: context.tr('التقويم الهجري', 'Hijri calendar'),
      icon: CupertinoIcons.calendar,
      color: AppColors.tilePurple,
      caption: next == null
          ? date
          : '$date · ${next.event.label(arabic: context.isArabic)} ${daysUntil(context, calendarDaysBetween(now, next.date))}',
      wide: true,
      scene: TileScene.night,
      onTap: () => context.push(IslamicCalendarScreen.path),
    );
  }
}
