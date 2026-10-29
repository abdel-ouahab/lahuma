import 'package:timezone/timezone.dart' as tz;
import '../domain/fajr_call_list.dart';
import '../domain/prayer_settings.dart';
import 'prayer_times_service.dart';

/// Works out when a list fires next.
///
/// Flutter is the only place that knows prayer times, so it precomputes a
/// run of upcoming fire times and hands them to the native scheduler
/// (Android) or to the notification layer (iOS / manual mode).
class FajrSchedule {
  const FajrSchedule({this.prayerTimes = const PrayerTimesService()});

  final PrayerTimesService prayerTimes;

  /// How many fire times are precomputed for the native side.
  static const int precomputeCount = 14;

  /// The next [count] times [list] fires strictly after [from], in
  /// [location] (the device timezone by default).
  ///
  /// Returns an empty list when the list starts at Fajr but no location is
  /// set, or when it runs on no day at all. A one-off list
  /// (`repeatDaily == false`) yields at most one time.
  List<tz.TZDateTime> nextFireTimes(
    FajrCallList list,
    PrayerSettings settings, {
    required DateTime from,
    int count = precomputeCount,
    tz.Location? location,
  }) {
    final loc = location ?? tz.local;
    if (count <= 0) return const [];
    if (list.startMode == FajrStartMode.fajr && !settings.hasLocation) {
      return const [];
    }
    // A one-off list keeps its single occurrence (the first after it was
    // armed) and has none left once that has passed.
    final armedAt = list.armedAt;
    if (!list.repeatDaily && armedAt != null && armedAt.isBefore(from)) {
      // Recurses once: `from == armedAt` takes the normal path below.
      final only =
          nextFireTimes(list, settings, from: armedAt, count: 1, location: loc);
      return only.where((t) => t.isAfter(from)).toList();
    }
    final want = list.repeatDaily ? count : 1;
    final start = tz.TZDateTime.from(from, loc);
    final result = <tz.TZDateTime>[];

    // Start a day early: Fajr minus a negative offset can land before
    // midnight, and stop after a few weeks so an impossible weekday set
    // can never loop forever.
    for (var i = -1; result.length < want && i <= want * 7 + 7; i++) {
      final day = tz.TZDateTime(loc, start.year, start.month, start.day + i);
      final at = _fireOn(list, settings, day, loc);
      if (at == null || !at.isAfter(start)) continue;
      // Weekdays refer to the day the call happens, not the Fajr day.
      if (!list.runsOn(at.weekday)) continue;
      if (result.isNotEmpty && !at.isAfter(result.last)) continue;
      result.add(at);
    }
    return result;
  }

  tz.TZDateTime? next(
    FajrCallList list,
    PrayerSettings settings, {
    required DateTime from,
    tz.Location? location,
  }) {
    final times =
        nextFireTimes(list, settings, from: from, count: 1, location: location);
    return times.isEmpty ? null : times.first;
  }

  tz.TZDateTime? _fireOn(
    FajrCallList list,
    PrayerSettings settings,
    tz.TZDateTime day,
    tz.Location loc,
  ) {
    switch (list.startMode) {
      case FajrStartMode.fixed:
        // TZDateTime rolls a time inside a DST gap forward, which is what
        // an alarm should do.
        return tz.TZDateTime(loc, day.year, day.month, day.day,
            list.fixedTime.hour, list.fixedTime.minute);
      case FajrStartMode.fajr:
        final fajr = prayerTimes.fajrOn(settings, day, location: loc);
        return fajr?.add(Duration(minutes: list.fajrOffsetMinutes));
    }
  }
}
