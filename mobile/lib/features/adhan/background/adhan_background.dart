import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../../core/constants/app_settings_enum.dart';
import '../../../core/notifications/local_notifications.dart';
import '../../prayer_times/data/prayer_days_source.dart';
import '../../prayer_banner/data/prayer_banner_platform.dart';
import '../../prayer_times/domain/prayer_times.dart';
import '../../reminders/data/reminder_notifications.dart';
import '../../reminders/domain/reminder_plan.dart';
import '../../settings/data/settings_repository.dart';
import '../data/adhan_alarm_platform.dart';
import '../data/adhan_audio_store.dart';
import '../data/adhan_scheduler.dart';
import '../data/adhan_settings_repository.dart';
import '../data/muezzin_repository.dart';
import '../domain/adhan_plan.dart';
import '../domain/muezzin.dart';

/// Rebuilds the week of adhans with no UI: what the Android worker runs
/// after a reboot, an app update, a clock or timezone change, and once a
/// day. Uses the saved settings, muezzin and location (no GPS here).
class AdhanBackgroundReschedule {
  AdhanBackgroundReschedule({
    required this.scheduler,
    AdhanSettingsRepository? settings,
    MuezzinRepository? muezzins,
    AdhanAudioStore? store,
    PrayerDaysSource? days,
    Future<bool> Function()? arabic,
    bool? ios,
  })  : _settings = settings ?? AdhanSettingsRepository(),
        _muezzins = muezzins ?? MuezzinRepository(),
        _store = store ?? AdhanAudioStore(),
        _days = days ?? PrayerDaysSource(),
        _arabic = arabic ??
            (() async =>
                await SettingsRepository().getLocaleOption() ==
                AppLocaleOption.arabic),
        _ios = ios ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  final AdhanScheduler scheduler;
  final AdhanSettingsRepository _settings;
  final MuezzinRepository _muezzins;
  final AdhanAudioStore _store;
  final PrayerDaysSource _days;
  final Future<bool> Function() _arabic;
  final bool _ios;

  /// Returns the slots scheduled, or null when nothing changed (no times:
  /// what is pending stays).
  Future<List<AdhanSlot>?> run(DateTime now) async {
    final settings = await _settings.loadSettings();
    var download = await _settings.loadDownload();
    if (download != null &&
        (download.muezzinId != settings.muezzinId ||
            !_store.isComplete(download))) {
      download = null;
    }
    final List<DayPrayerTimes> days =
        settings.enabled ? await _days.upcoming(now) : const [];
    if (settings.enabled && days.isEmpty) return null;
    final slots =
        AdhanPlanner.plan(days: days, settings: settings, now: now, ios: _ios);
    final arabic = await _arabic();
    String? name;
    for (final Muezzin m in await _muezzins.cached()) {
      if (m.id == settings.muezzinId) name = m.name(arabic);
    }
    await scheduler.sync(slots,
        muezzinName: name, arabic: arabic, download: download);
    return slots;
  }
}

/// The background engine's entry point (see `AdhanWorker.kt`).
Future<void> runAdhanBackground() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  const native = AdhanAlarmPlatform();
  try {
    final notifications = LocalNotifications();
    await notifications.init();
    final slots = await AdhanBackgroundReschedule(
      scheduler: AdhanScheduler(notifications, native: native),
    ).run(DateTime.now());
    debugPrint('Adhan: background reschedule, ${slots?.length} slots');
  } catch (e, st) {
    debugPrint('Adhan: background reschedule failed: $e\n$st');
  }
  // The prayer-times banner gets the days ahead, so it keeps moving on.
  try {
    final now = DateTime.now();
    final enabled = await PrayerBannerSettingsRepository().load();
    final days = enabled
        ? await PrayerDaysSource().upcoming(now)
        : const <DayPrayerTimes>[];
    if (!enabled || days.isNotEmpty) {
      await const PrayerBannerPlatform(android: native).sync(
        enabled: enabled,
        days: days,
        arabic: await SettingsRepository().getLocaleOption() ==
            AppLocaleOption.arabic,
        now: now,
      );
    }
  } catch (e, st) {
    debugPrint('Prayer banner: background sync failed: $e\n$st');
  }
  // The adhkar and surah reminders ride on the same daily worker.
  try {
    final notifications = LocalNotifications();
    await notifications.init();
    final now = DateTime.now();
    final frequency = await ReminderSettingsRepository().load();
    final days = frequency == ReminderFrequency.off
        ? const <DayPrayerTimes>[]
        : await PrayerDaysSource().upcoming(now);
    if (frequency == ReminderFrequency.off || days.isNotEmpty) {
      await ReminderNotifications(notifications).sync(
        ReminderPlanner.plan(
            days: days, frequency: frequency, now: now, ios: false),
        arabic: await SettingsRepository().getLocaleOption() ==
            AppLocaleOption.arabic,
      );
    }
  } catch (e, st) {
    debugPrint('Reminders: background reschedule failed: $e\n$st');
  } finally {
    await native.backgroundDone();
  }
}
