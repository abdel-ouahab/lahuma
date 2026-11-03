import 'package:flutter/foundation.dart';
import '../domain/local_prayer_times.dart';
import '../domain/prayer_times.dart';
import 'prayer_times_cache.dart';
import 'prayer_times_config.dart';
import 'prayer_times_service.dart';

/// The coming days' prayer times without the UI: plain Dart (prefs, HTTP),
/// no BuildContext or Riverpod, so a background isolate can call it.
///
/// Uses the saved location only (no GPS in the background). Days come from
/// the cache, then Aladhan (whole months, saved for later offline runs),
/// then, for a day still missing, [LocalPrayerTimes] (not saved, so
/// Aladhan replaces it once the phone is online).
class PrayerDaysSource {
  PrayerDaysSource({
    PrayerTimesCache? cache,
    PrayerTimesApiService? api,
    this.local = const LocalPrayerTimes(),
  })  : _cache = cache ?? PrayerTimesCache(),
        _api = api ?? PrayerTimesApiService();

  final PrayerTimesCache _cache;
  final PrayerTimesApiService _api;
  final LocalPrayerTimes local;

  /// [count] days from [now]'s day on, in order. Empty when no location
  /// was ever saved.
  Future<List<DayPrayerTimes>> upcoming(
    DateTime now, {
    int count = PrayerTimesConfig.daysAhead,
  }) async {
    final snap = await _cache.load();
    final loc = snap.location;
    if (loc == null) return const [];
    final days = {...snap.days};
    final wanted = [
      for (var i = 0; i < count; i++) DateTime(now.year, now.month, now.day + i)
    ];
    final missing =
        wanted.where((d) => !days.containsKey(DayPrayerTimes.dayKey(d)));
    if (missing.isNotEmpty) {
      try {
        final today = DayPrayerTimes.dayKey(now);
        for (final d in await _api.fetchMonths(
            missing.toList(), loc.latitude, loc.longitude)) {
          if (d.key.compareTo(today) >= 0) days[d.key] = d;
        }
        await _cache.save(PrayerTimesSnapshot(location: loc, days: days),
            now: now);
      } catch (e) {
        debugPrint('Prayer times: background fetch failed: $e');
      }
    }
    return [
      for (final d in wanted)
        days[DayPrayerTimes.dayKey(d)] ?? local.dayAt(d, loc),
    ];
  }
}
