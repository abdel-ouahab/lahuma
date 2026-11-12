import '../../prayer_times/domain/prayer_times.dart';

/// How often the adhkar and surah reminders come.
enum ReminderFrequency {
  off,

  /// Morning and evening adhkar, Al-Kahf on Friday.
  rare,

  /// Also Al-Mulk every night and the salawat on Friday.
  moderate,

  /// Also "Subhan Allah wa bihamdih" at midday and the sleep adhkar.
  frequent;

  static ReminderFrequency fromName(String? name) =>
      values.firstWhere((f) => f.name == name, orElse: () => defaultValue);

  /// What a new install gets.
  static const ReminderFrequency defaultValue = moderate;
}

/// Where a reminder takes the user when tapped.
enum ReminderTarget { adhkar, mushaf, tasbih }

/// One kind of reminder, in the order of the day.
enum ReminderKind {
  morningAdhkar(ReminderFrequency.rare, ReminderTarget.adhkar),
  kahf(ReminderFrequency.rare, ReminderTarget.mushaf, friday: true),
  midday(ReminderFrequency.frequent, ReminderTarget.tasbih),
  salawat(ReminderFrequency.moderate, ReminderTarget.tasbih, friday: true),
  eveningAdhkar(ReminderFrequency.rare, ReminderTarget.adhkar),
  mulk(ReminderFrequency.moderate, ReminderTarget.mushaf),
  sleepAdhkar(ReminderFrequency.frequent, ReminderTarget.adhkar);

  const ReminderKind(this.from, this.target, {this.friday = false});

  /// The lowest frequency that sends it.
  final ReminderFrequency from;
  final ReminderTarget target;

  /// Only on Fridays.
  final bool friday;

  bool sentAt(ReminderFrequency f) =>
      f != ReminderFrequency.off && f.index >= from.index;

  /// The route a tap opens.
  String get route => switch (this) {
        morningAdhkar => '/adhkar/morning',
        eveningAdhkar => '/adhkar/evening',
        sleepAdhkar => '/adhkar/sleep',
        kahf => '/mushaf?page=$kahfPage',
        mulk => '/mushaf?page=$mulkPage',
        midday || salawat => '/tasbih',
      };

  /// First pages in the Madani Mushaf (pinned by a test against MushafMeta).
  static const int kahfPage = 293;
  static const int mulkPage = 562;

  /// When it comes on [day], from that day's prayer times.
  DateTime timeOn(DayPrayerTimes day) {
    final fajr = day[PrayerKind.fajr];
    final sunrise = day[PrayerKind.sunrise];
    final dhuhr = day[PrayerKind.dhuhr];
    final asr = day[PrayerKind.asr];
    final maghrib = day[PrayerKind.maghrib];
    final isha = day[PrayerKind.isha];
    DateTime before(DateTime a, DateTime limit) => a.isBefore(limit) ? a : limit;
    DateTime after(DateTime a, DateTime limit) => a.isAfter(limit) ? a : limit;
    final d = day.date;
    // Sleep adhkar: an hour and a half after Isha, not before 21:45, and
    // before midnight.
    final sleep = before(
      after(isha.add(const Duration(minutes: 90)),
          DateTime(d.year, d.month, d.day, 21, 45)),
      DateTime(d.year, d.month, d.day, 23, 30),
    );
    return switch (this) {
      // Between Fajr and sunrise, the time of the morning adhkar.
      morningAdhkar => after(
          before(fajr.add(const Duration(minutes: 30)),
              sunrise.subtract(const Duration(minutes: 15))),
          fajr.add(const Duration(minutes: 5))),
      kahf => sunrise.add(const Duration(hours: 2)),
      midday => dhuhr.add(const Duration(minutes: 40)),
      salawat => dhuhr.add(const Duration(minutes: 75)),
      // Between Asr and Maghrib.
      eveningAdhkar => before(asr.add(const Duration(minutes: 30)),
          maghrib.subtract(const Duration(minutes: 25))),
      mulk => after(sleep.subtract(const Duration(minutes: 45)),
          isha.add(const Duration(minutes: 20))),
      sleepAdhkar => sleep,
    };
  }
}

/// One reminder to schedule. On iOS it [repeats], so it takes one of the
/// 64 pending slots for good.
class ReminderSlot {
  const ReminderSlot({
    required this.id,
    required this.kind,
    required this.at,
    this.repeats = false,
  });

  final int id;
  final ReminderKind kind;
  final DateTime at;

  /// iOS: repeats every day (or every Friday) at [at]'s clock time.
  final bool repeats;

  @override
  String toString() =>
      'ReminderSlot($id, ${kind.name} @ $at${repeats ? ' repeating' : ''})';
}

/// Which reminders should be pending. Pure, so ids and times are testable.
class ReminderPlanner {
  const ReminderPlanner._();

  /// Android: a week ahead, rebuilt on launch and by the daily worker.
  static const int horizonDays = 7;

  /// iOS: one repeating notification per kind (taken from the adhan's 64).
  static int get iosBudget => ReminderKind.values.length;

  /// Ids `minId … maxId - 1`, clear of the adhan (200 000 000 …
  /// 220 000 000) and the khatma (230 000 000 …).
  static const int minId = 240000000;
  static const int maxId = 241000000;

  static bool isReminderId(int id) => id >= minId && id < maxId;

  /// Days since 2024-01-01, ×10, + the kind. iOS repeating ones are
  /// `minId + kind`.
  static int idFor(DateTime day, ReminderKind kind) {
    final days = DateTime.utc(day.year, day.month, day.day)
        .difference(DateTime.utc(2024))
        .inDays;
    return minId + 100 + days * 10 + kind.index;
  }

  static List<ReminderSlot> plan({
    required List<DayPrayerTimes> days,
    required ReminderFrequency frequency,
    required DateTime now,
    required bool ios,
  }) {
    if (frequency == ReminderFrequency.off || days.isEmpty) return const [];
    final kinds = [
      for (final k in ReminderKind.values)
        if (k.sentAt(frequency)) k
    ];
    if (ios) return _iosPlan(days, kinds, now);

    final today = DateTime.utc(now.year, now.month, now.day);
    final slots = <ReminderSlot>[];
    for (final day in days) {
      final d = day.date;
      final offset =
          DateTime.utc(d.year, d.month, d.day).difference(today).inDays;
      if (offset < 0 || offset >= horizonDays) continue;
      for (final k in kinds) {
        if (k.friday && d.weekday != DateTime.friday) continue;
        final at = k.timeOn(day);
        if (at.isAfter(now)) {
          slots.add(ReminderSlot(id: idFor(d, k), kind: k, at: at));
        }
      }
    }
    slots.sort((a, b) => a.at.compareTo(b.at));
    return slots;
  }

  /// One repeating notification per kind at today's time (the next
  /// Friday's for the Friday ones). The app moves them as the prayer times
  /// drift, whenever it opens.
  static List<ReminderSlot> _iosPlan(
      List<DayPrayerTimes> days, List<ReminderKind> kinds, DateTime now) {
    final today = DateTime.utc(now.year, now.month, now.day);
    final slots = <ReminderSlot>[];
    for (final k in kinds) {
      DayPrayerTimes? day;
      for (final d in days) {
        final offset = DateTime.utc(d.date.year, d.date.month, d.date.day)
            .difference(today)
            .inDays;
        if (offset < 0) continue;
        if (k.friday && d.date.weekday != DateTime.friday) continue;
        day = d;
        break;
      }
      // No Friday among the known days: use the first day's times on the
      // coming Friday.
      day ??= days.first;
      var at = k.timeOn(day);
      if (k.friday && at.weekday != DateTime.friday) {
        at = at.add(Duration(days: (DateTime.friday - at.weekday) % 7));
      }
      slots.add(ReminderSlot(
          id: minId + k.index, kind: k, at: at, repeats: true));
    }
    slots.sort((a, b) => a.at.compareTo(b.at));
    return slots;
  }
}
