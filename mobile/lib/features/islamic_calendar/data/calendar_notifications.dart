import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/notifications/local_notifications.dart';
import '../domain/calendar_reminders.dart';

/// Replaces the pending occasion reminders with the planned ones.
class CalendarNotifications {
  CalendarNotifications(this._notifications);

  final LocalNotifications _notifications;

  static const channel = NotificationChannelSpec(
    id: 'islamic_calendar',
    name: 'المناسبات الإسلامية · Islamic occasions',
    description: 'تذكير بالأعياد ورمضان وأيام الصيام · '
        'Eid, Ramadan and fasting-day reminders',
  );

  static const String route = '/calendar';

  Future<void> sync(List<CalendarReminder> reminders,
      {required bool arabic}) async {
    for (final p in await _notifications.pending()) {
      if (CalendarReminderPlanner.isCalendarId(p.id)) {
        await _notifications.cancel(p.id);
      }
    }
    if (reminders.isEmpty) return;
    await _notifications.ensureChannel(channel);
    for (final r in reminders) {
      await _notifications.scheduleAt(
        id: r.id,
        at: tz.TZDateTime(
            tz.local, r.at.year, r.at.month, r.at.day, r.at.hour, r.at.minute),
        channel: channel,
        route: route,
        title: r.occurrence.event.label(arabic: arabic),
        body: body(r, arabic: arabic),
        category: arabic ? 'التقويم الهجري' : 'Hijri calendar',
      );
    }
    debugPrint('Calendar: ${reminders.length} reminders, next ${reminders.first}');
  }

  /// "غدًا إن شاء الله. صيامه يكفّر سنتين…", with a word on the moon
  /// sighting where the day depends on it.
  static String body(CalendarReminder r, {required bool arabic}) {
    final e = r.occurrence.event;
    final multi = e.days > 1;
    final String when;
    if (r.eveningBefore && e.startsAtNight) {
      when = arabic
          ? (multi ? 'تبدأ الليلة إن شاء الله.' : 'الليلة إن شاء الله.')
          : (multi ? 'Begins tonight, in sha Allah.' : 'Tonight, in sha Allah.');
    } else if (r.eveningBefore) {
      when = arabic
          ? (multi ? 'تبدأ غدًا إن شاء الله.' : 'غدًا إن شاء الله.')
          : (multi
              ? 'Begins tomorrow, in sha Allah.'
              : 'Tomorrow, in sha Allah.');
    } else {
      when = arabic
          ? (multi ? 'تبدأ اليوم.' : 'اليوم.')
          : (multi ? 'Begins today.' : 'Today.');
    }
    final sighting = e.bySighting
        ? (arabic
            ? ' بحسب التقويم؛ تأكّد من إعلان رؤية الهلال في بلدك.'
            : ' By the calendar: check the moon-sighting announcement where you live.')
        : '';
    return '$when ${e.tip(arabic: arabic)}$sighting';
  }
}
