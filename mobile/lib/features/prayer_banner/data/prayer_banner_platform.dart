import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';
import '../../adhan/data/adhan_alarm_platform.dart';
import '../../prayer_times/domain/prayer_times.dart';
import '../domain/prayer_banner.dart';

/// The banner's on/off switch (on unless turned off).
class PrayerBannerSettingsRepository {
  Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.prayerBannerEnabled) ?? true;
  }

  Future<void> save(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.prayerBannerEnabled, enabled);
  }
}

/// Shows the prayer-times banner, or takes it away.
///
/// **Android:** an ongoing notification posted natively
/// (`PrayerBanner.kt`). It gets the week of times, so it moves on to each
/// next prayer with the app closed.
///
/// **iOS 16.1+:** a Live Activity (`ios/PrayerBanner/`). iOS doesn't let it
/// change by itself, so it is refreshed whenever the app runs, and iOS ends
/// it after about 8 hours.
class PrayerBannerPlatform {
  const PrayerBannerPlatform({
    AdhanAlarmPlatform android = const AdhanAlarmPlatform(),
    bool? ios,
  })  : _android = android,
        _iosOverride = ios;

  final AdhanAlarmPlatform _android;
  final bool? _iosOverride;

  static const MethodChannel _ios = MethodChannel('lahuma/prayer_banner');

  bool get _isIos =>
      _iosOverride ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  bool get supported => _android.supported || _isIos;

  /// The five times of each day, Fajr to Isha (epoch ms), for Android.
  static List<List<int>> nativeDays(List<DayPrayerTimes> days) => [
        for (final d in days)
          if (bannerPrayers.every(d.times.containsKey))
            [for (final p in bannerPrayers) d[p].millisecondsSinceEpoch],
      ];

  /// What the iOS Live Activity shows, or null to end it.
  static Map<String, Object>? iosState(
      List<DayPrayerTimes> days, DateTime now, {required bool arabic}) {
    final next = nextBannerPrayer(days, now);
    if (next == null) return null;
    return {
      'names': PrayerBannerStrings.of(arabic: arabic).names,
      'times': [
        for (final p in bannerPrayers) next.day[p].millisecondsSinceEpoch,
      ],
      'next': next.index,
      'since': next.since.millisecondsSinceEpoch,
      'countdown': arabic ? 'بعد' : 'in',
      'rtl': arabic,
    };
  }

  Future<void> sync({
    required bool enabled,
    required List<DayPrayerTimes> days,
    required bool arabic,
    required DateTime now,
  }) async {
    if (_android.supported) {
      await _android.bannerSync(
        enabled: enabled,
        days: nativeDays(days),
        strings: PrayerBannerStrings.of(arabic: arabic).toMap(),
      );
      return;
    }
    if (!_isIos) return;
    final state = enabled ? iosState(days, now, arabic: arabic) : null;
    try {
      if (state == null) {
        await _ios.invokeMethod<void>('end');
      } else {
        await _ios.invokeMethod<void>('show', state);
      }
    } on MissingPluginException {
      // Tests.
    } catch (e) {
      debugPrint('Prayer banner: $e');
    }
  }
}
