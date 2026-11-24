import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';
import '../domain/calendar_reminders.dart';
import '../domain/islamic_events.dart';

/// The calendar's settings, in prefs.
class CalendarRepository {
  Future<CalendarSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList(StorageKeys.calendarReminderEvents);
    return CalendarSettings(
      remindersOn: prefs.getBool(StorageKeys.calendarRemindersOn) ?? false,
      timing: CalendarReminderTiming.fromName(
          prefs.getString(StorageKeys.calendarReminderTiming)),
      events: names == null
          ? IslamicEvent.defaultReminders
          : names.map(IslamicEvent.byName).nonNulls.toSet(),
      adjustment: (prefs.getInt(StorageKeys.calendarHijriAdjustment) ?? 0)
          .clamp(-CalendarSettings.maxAdjustment, CalendarSettings.maxAdjustment),
    );
  }

  Future<void> save(CalendarSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.calendarRemindersOn, s.remindersOn);
    await prefs.setString(StorageKeys.calendarReminderTiming, s.timing.name);
    await prefs.setStringList(StorageKeys.calendarReminderEvents,
        [for (final e in s.events) e.name]);
    await prefs.setInt(StorageKeys.calendarHijriAdjustment, s.adjustment);
  }
}
