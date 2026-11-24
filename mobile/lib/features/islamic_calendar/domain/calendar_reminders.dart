import 'islamic_events.dart';

/// When an occasion's reminder comes.
enum CalendarReminderTiming {
  /// 8 pm the evening before: time to intend a fast, or for the night.
  eveningBefore,

  /// 8 am on the day. Nights are still reminded the evening before.
  morningOf;

  static CalendarReminderTiming fromName(String? name) =>
      values.where((t) => t.name == name).firstOrNull ?? eveningBefore;
}

/// The calendar's settings: reminders and the Hijri date's adjustment.
class CalendarSettings {
  const CalendarSettings({
    this.remindersOn = false,
    this.timing = CalendarReminderTiming.eveningBefore,
    this.events = const {},
    this.adjustment = 0,
  });

  /// The occasions are reminded at all.
  final bool remindersOn;
  final CalendarReminderTiming timing;

  /// Which occasions are reminded, when [remindersOn].
  final Set<IslamicEvent> events;

  /// Days added to the Umm al-Qura date (−2 … +2).
  final int adjustment;

  static const int maxAdjustment = 2;

  CalendarSettings copyWith({
    bool? remindersOn,
    CalendarReminderTiming? timing,
    Set<IslamicEvent>? events,
    int? adjustment,
  }) =>
      CalendarSettings(
        remindersOn: remindersOn ?? this.remindersOn,
        timing: timing ?? this.timing,
        events: events ?? this.events,
        adjustment: adjustment ?? this.adjustment,
      );

  bool reminds(IslamicEvent e) => remindersOn && events.contains(e);
}

/// One scheduled occasion reminder.
class CalendarReminder {
  const CalendarReminder({
    required this.id,
    required this.at,
    required this.occurrence,
    required this.eveningBefore,
  });

  final int id;
  final DateTime at;
  final EventOccurrence occurrence;

  /// Sent the evening before the day (else on the morning of it).
  final bool eveningBefore;

  @override
  String toString() => '${occurrence.event.name} at $at';
}

/// Plans the occasion reminders from the dated occurrences.
class CalendarReminderPlanner {
  const CalendarReminderPlanner._();

  /// Notification ids, clear of Fajr Call (< 16 000 000), the adhan
  /// (200 000 000 …), the khatma (230 000 000 …) and the adhkar and surah
  /// reminders (240 000 000 …).
  static const int minId = 250000000;
  static const int maxId = 251000000;

  static bool isCalendarId(int id) => id >= minId && id < maxId;

  static const int eveningHour = 20;
  static const int morningHour = 8;

  /// How far ahead to schedule: a year and a bit for the yearly occasions,
  /// two months for the monthly white days. Every launch tops it up.
  static const Duration horizon = Duration(days: 400);
  static const Duration monthlyHorizon = Duration(days: 62);

  /// iOS keeps 64 pending notifications for the whole app, shared with the
  /// adhan and the other reminders: only the nearest few there.
  static const int iosLimit = 6;

  /// Days since 2024-01-01, ×16, + the occasion: unique per day and
  /// occasion.
  static int idFor(EventOccurrence o) {
    final day = DateTime.utc(o.date.year, o.date.month, o.date.day)
        .difference(DateTime.utc(2024))
        .inDays;
    return minId + day * 16 + o.event.index;
  }

  static List<CalendarReminder> plan({
    required List<EventOccurrence> occurrences,
    required CalendarSettings settings,
    required DateTime now,
    bool ios = false,
  }) {
    if (!settings.remindersOn) return const [];
    final result = <CalendarReminder>[];
    for (final o in occurrences) {
      final e = o.event;
      if (!settings.events.contains(e)) continue;
      final limit = now.add(e.monthly ? monthlyHorizon : horizon);
      if (o.date.isAfter(limit)) continue;
      final evening =
          settings.timing == CalendarReminderTiming.eveningBefore ||
              e.eveningOnly;
      final day = evening ? o.date.subtract(const Duration(days: 1)) : o.date;
      final at = DateTime(day.year, day.month, day.day,
          evening ? eveningHour : morningHour);
      if (!at.isAfter(now)) continue;
      result.add(CalendarReminder(
        id: idFor(o),
        at: at,
        occurrence: o,
        eveningBefore: evening,
      ));
    }
    result.sort((a, b) => a.at.compareTo(b.at));
    return ios && result.length > iosLimit
        ? result.sublist(0, iosLimit)
        : result;
  }
}
