import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/notifications/local_notifications.dart';
import '../../prayer_times/domain/prayer_times.dart';
import '../domain/adhan_plan.dart';

/// Turns an adhan plan into scheduled notifications.
///
/// The notifications are silent: the adhan itself is only ever played by
/// the app's own player (`AdhanForeground`, while the app is open, or the
/// player screen a tap opens), never as a notification or alarm sound.
/// Each one is an alarm clock on Android (`setAlarmClock`), the one exact
/// alarm Doze and OEM battery savers leave on time. Reminders keep the
/// default notification sound.
class AdhanScheduler {
  AdhanScheduler(this._notifications);

  final LocalNotifications _notifications;

  static const String channelPrefix = 'adhan_';

  /// Tapping an adhan opens the full-length player.
  static const String playRoute = '/adhan/play';

  static String playRouteFor(PrayerKind prayer) =>
      '$playRoute?prayer=${prayer.name}';

  /// Silent, so a new id: the old channels had the adhan as their sound,
  /// and a channel's sound can't change once it exists.
  static const adhanChannel = NotificationChannelSpec(
    id: 'adhan_prayer_silent',
    name: 'الأذان · Adhan',
    description: 'وقت الصلاة · Prayer time',
    timeSensitive: true,
    silent: true,
  );

  static const reminderChannel = NotificationChannelSpec(
    id: 'adhan_reminder',
    name: 'تذكير قبل الصلاة · Prayer reminder',
    description: 'اقترب وقت الصلاة · Before each prayer',
    timeSensitive: true,
  );

  /// Replaces every pending adhan notification with [slots].
  Future<void> sync(
    List<AdhanSlot> slots, {
    required String? muezzinName,
    required bool arabic,
  }) async {
    for (final p in await _notifications.pending()) {
      if (AdhanPlanner.isAdhanId(p.id)) await _notifications.cancel(p.id);
    }
    final used = <String>{};
    for (final s in slots) {
      final channel = s.reminder ? reminderChannel : adhanChannel;
      if (used.add(channel.id)) await _notifications.ensureChannel(channel);
      await _notifications.scheduleAt(
        id: s.id,
        at: tz.TZDateTime.from(s.at, tz.local),
        channel: channel,
        route: s.reminder ? null : playRouteFor(s.prayer),
        title: s.reminder
            ? reminderTitle(s.prayer, arabic)
            : adhanTitle(s.prayer, arabic),
        body: s.reminder
            ? reminderBody(s.leadMinutes, arabic)
            : adhanBody(s.prayer, muezzinName, arabic),
        alarmClock: true,
      );
    }
    // Drops the old channels that played the adhan as their sound.
    await _notifications.deleteChannels(
        prefix: channelPrefix, keep: {adhanChannel.id, reminderChannel.id});
    debugPrint('Adhan: ${slots.length} scheduled'
        '${slots.isEmpty ? '' : ', next ${slots.first}'}');
  }

  /// "Test the adhan": [prayer]'s notification at [at], with id [id]
  /// (outside the planner's range, so a sync leaves it alone).
  Future<void> scheduleTest(
    int id,
    PrayerKind prayer,
    DateTime at, {
    required String? muezzinName,
    required bool arabic,
  }) async {
    await _notifications.ensureChannel(adhanChannel);
    await _notifications.scheduleAt(
      id: id,
      at: tz.TZDateTime.from(at, tz.local),
      channel: adhanChannel,
      route: playRouteFor(prayer),
      title: adhanTitle(prayer, arabic),
      body: adhanBody(prayer, muezzinName, arabic),
      alarmClock: true,
    );
  }

  static String adhanTitle(PrayerKind p, bool arabic) =>
      arabic ? 'حان الآن وقت صلاة ${p.ar}' : "It's time for ${p.en}";

  static String adhanBody(PrayerKind p, String? muezzin, bool arabic) {
    if (p == PrayerKind.fajr) {
      return arabic ? 'الصلاة خير من النوم' : 'Prayer is better than sleep';
    }
    if (muezzin != null) return muezzin;
    return arabic ? 'اضغط للاستماع إلى الأذان' : 'Tap to listen to the adhan';
  }

  static String reminderTitle(PrayerKind p, bool arabic) =>
      arabic ? 'اقترب وقت صلاة ${p.ar}' : '${p.en} is coming up';

  static String reminderBody(int minutes, bool arabic) {
    if (!arabic) return 'In $minutes minutes';
    // 3–10: دقائق; 11 and up: دقيقة.
    return 'بعد $minutes ${minutes <= 10 ? 'دقائق' : 'دقيقة'}';
  }
}
