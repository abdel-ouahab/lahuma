import '../../prayer_times/domain/prayer_times.dart';
import 'adhan_settings.dart';

/// One notification to schedule: an adhan, or the reminder before one.
class AdhanSlot {
  const AdhanSlot({
    required this.id,
    required this.at,
    required this.prayer,
    this.leadMinutes = 0,
  });

  final int id;
  final DateTime at;
  final PrayerKind prayer;

  /// Minutes before the prayer; 0 for the adhan itself.
  final int leadMinutes;

  bool get reminder => leadMinutes > 0;

  @override
  String toString() =>
      'AdhanSlot($id, ${prayer.name}${reminder ? ' reminder' : ''} @ $at)';
}

/// Works out which adhan notifications should be pending, from the known
/// prayer times. Pure, so the budget and ids are easy to test.
class AdhanPlanner {
  const AdhanPlanner._();

  /// iOS keeps 64 pending notifications per app. The adhan takes 45: a week
  /// of five adhans (35) plus reminders for the next [iosReminderDays] days
  /// (10). Fajr Call has the other 19 (`FajrNotifications.maxPending`).
  static const int iosBudget = 45;
  static const int iosReminderDays = 2;

  /// Stable ids: `yyyymmdd·10 + prayer` for the adhan, `+5` for its
  /// reminder. 2000-01-01 … 2199-12-31 stays inside [minId, maxId), clear
  /// of Fajr Call's ids (< 16 000 000) and within 31 bits.
  static const int minId = 200000000;
  static const int maxId = 220000000;

  static int idFor(DateTime day, PrayerKind prayer, {bool reminder = false}) {
    final ymd = day.year * 10000 + day.month * 100 + day.day;
    return ymd * 10 + adhanPrayers.indexOf(prayer) + (reminder ? 5 : 0);
  }

  static bool isAdhanId(int id) => id >= minId && id < maxId;

  /// Every slot after [now] in [days], earliest first. Empty when the
  /// adhan is off. On [ios] reminders stop after [iosReminderDays] and the
  /// total is capped at [iosBudget].
  static List<AdhanSlot> plan({
    required List<DayPrayerTimes> days,
    required AdhanSettings settings,
    required DateTime now,
    required bool ios,
  }) {
    if (!settings.enabled) return const [];
    // Calendar days in UTC, so a 23- or 25-hour DST day still counts as one.
    final today = DateTime.utc(now.year, now.month, now.day);
    final slots = <AdhanSlot>[];
    for (final day in days) {
      final d = day.date;
      final offset =
          DateTime.utc(d.year, d.month, d.day).difference(today).inDays;
      if (offset < 0) continue;
      for (final prayer in adhanPrayers) {
        if (!settings.prayers.contains(prayer)) continue;
        final at = day[prayer];
        if (at.isAfter(now)) {
          slots.add(
              AdhanSlot(id: idFor(day.date, prayer), at: at, prayer: prayer));
        }
        final lead = settings.reminderMinutes;
        if (lead <= 0 || (ios && offset >= iosReminderDays)) continue;
        final remindAt = at.subtract(Duration(minutes: lead));
        if (remindAt.isAfter(now)) {
          slots.add(AdhanSlot(
            id: idFor(day.date, prayer, reminder: true),
            at: remindAt,
            prayer: prayer,
            leadMinutes: lead,
          ));
        }
      }
    }
    slots.sort((a, b) => a.at.compareTo(b.at));
    return ios && slots.length > iosBudget
        ? slots.sublist(0, iosBudget)
        : slots;
  }
}
