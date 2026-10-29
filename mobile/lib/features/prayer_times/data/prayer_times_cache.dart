import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';
import '../domain/prayer_times.dart';
import 'prayer_times_config.dart';

/// Last location plus the timings fetched for it, keyed by day. Entries are
/// only valid for the stored location and calculation method.
class PrayerTimesSnapshot {
  const PrayerTimesSnapshot({this.location, this.days = const {}});

  final PrayerLocation? location;
  final Map<String, DayPrayerTimes> days;
}

class PrayerTimesCache {
  /// Days older than yesterday are dropped on save.
  Future<PrayerTimesSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.prayerTimesCache);
    if (raw == null) return const PrayerTimesSnapshot();
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final location = json['location'] == null
          ? null
          : PrayerLocation.fromJson(
              Map<String, dynamic>.from(json['location'] as Map));
      // A different method means different times: keep the place only.
      if (json['method'] != PrayerTimesConfig.method) {
        return PrayerTimesSnapshot(location: location);
      }
      final days = <String, DayPrayerTimes>{};
      for (final e in Map<String, dynamic>.from(json['days'] as Map).entries) {
        days[e.key] =
            DayPrayerTimes.fromJson(Map<String, dynamic>.from(e.value as Map));
      }
      return PrayerTimesSnapshot(location: location, days: days);
    } catch (_) {
      // Corrupt data: behave as a first launch.
      return const PrayerTimesSnapshot();
    }
  }

  Future<void> save(PrayerTimesSnapshot snapshot,
      {required DateTime now}) async {
    final oldest =
        DayPrayerTimes.dayKey(DateTime(now.year, now.month, now.day - 1));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.prayerTimesCache,
      jsonEncode({
        'method': PrayerTimesConfig.method,
        'location': snapshot.location?.toJson(),
        'days': {
          for (final e in snapshot.days.entries)
            if (e.key.compareTo(oldest) >= 0) e.key: e.value.toJson(),
        },
      }),
    );
  }
}
