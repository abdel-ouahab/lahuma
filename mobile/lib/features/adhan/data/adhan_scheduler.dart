import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/notifications/local_notifications.dart';
import '../../prayer_times/domain/prayer_times.dart';
import '../domain/adhan_plan.dart';
import '../domain/muezzin.dart';
import 'adhan_alarm_platform.dart';

/// Turns an adhan plan into alarms and notifications.
///
/// **Android.** Each audible adhan is a native exact alarm
/// ([AdhanAlarmPlatform]): `setAlarmClock` fires a receiver, which starts a
/// `mediaPlayback` foreground service that plays the full adhan on the
/// alarm stream, with or without the app. Silent prayers and reminders stay
/// `flutter_local_notifications` alarm clocks. When the native engine is
/// missing, every adhan falls back to a silent notification.
///
/// **iOS.** No app code runs at a scheduled time and a notification sound
/// is at most 30 s, so an audible adhan is a notification whose sound is a
/// ≤ 30 s clip (the muezzin's short .caf, or the bundled
/// `adhan_default_regular.caf`). Tapping it opens the app, which plays the
/// full adhan. The plan is capped at the adhan's share of iOS's 64 pending
/// notifications ([AdhanPlanner.iosBudget]).
class AdhanScheduler {
  AdhanScheduler(
    this._notifications, {
    AdhanAlarmPlatform native = const AdhanAlarmPlatform(),
    bool? ios,
  })  : _native = native,
        _ios = ios ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  final LocalNotifications _notifications;
  final AdhanAlarmPlatform _native;
  final bool _ios;

  static const String channelPrefix = 'adhan_';

  /// Channels the native engine owns (`AdhanNotify.kt`); [sync] must not
  /// delete them with the old ones.
  static const Set<String> nativeChannels = {'adhan_playing', 'adhan_alert'};

  /// Tapping an adhan opens the full-length player.
  static const String playRoute = '/adhan/play';

  static String playRouteFor(PrayerKind prayer) =>
      '$playRoute?prayer=${prayer.name}';

  /// iOS bundled clip (Runner target), when no muezzin is downloaded.
  static const String iosDefaultSound = 'adhan_default_regular.caf';

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

  /// iOS: the adhan clip as the sound. Quiet while the app is open, which
  /// plays the full adhan itself.
  static NotificationChannelSpec iosSoundChannel(String sound) =>
      NotificationChannelSpec(
        id: 'adhan_prayer_sound',
        name: 'الأذان · Adhan',
        description: 'وقت الصلاة · Prayer time',
        timeSensitive: true,
        quietInForeground: true,
        sound: NotificationSound(iosName: sound),
      );

  /// The full recording the native player plays for [prayer]; null for the
  /// bundled one.
  static String? fileFor(PrayerKind prayer, AdhanDownload? download) {
    if (download == null) return null;
    final fajr = prayer == PrayerKind.fajr;
    final path = download.files[AdhanSoundKind.full(fajr: fajr)] ??
        download.files[AdhanSoundKind.regular];
    return path != null && File(path).existsSync() ? path : null;
  }

  static String iosSoundFor(PrayerKind prayer, AdhanDownload? download) {
    final fajr = prayer == PrayerKind.fajr;
    return download?.iosSounds[AdhanSoundKind.short(fajr: fajr)] ??
        download?.iosSounds[AdhanSoundKind.regularShort] ??
        iosDefaultSound;
  }

  /// Replaces every pending adhan alarm and notification with [slots].
  /// Returns whether the audible adhans went to the native engine (then
  /// the app must not play them itself).
  Future<bool> sync(
    List<AdhanSlot> slots, {
    required String? muezzinName,
    required bool arabic,
    AdhanDownload? download,
  }) async {
    var native = false;
    if (!_ios && _native.supported) {
      native = await _native.sync([
        for (final s in slots)
          if (s.audible) _alarm(s, s.id, muezzinName, arabic, download),
      ], AdhanNativeStrings.of(arabic: arabic));
      if (native) await _native.ensureDaily();
    }
    for (final p in await _notifications.pending()) {
      if (AdhanPlanner.isAdhanId(p.id)) await _notifications.cancel(p.id);
    }
    final used = <String>{};
    for (final s in slots) {
      if (native && s.audible) continue;
      final channel = s.reminder
          ? reminderChannel
          : _ios && s.audible
              ? iosSoundChannel(iosSoundFor(s.prayer, download))
              : adhanChannel;
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
    await _notifications.deleteChannels(prefix: channelPrefix, keep: {
      adhanChannel.id,
      reminderChannel.id,
      ...nativeChannels,
    });
    debugPrint('Adhan: ${slots.length} scheduled${native ? ' (native)' : ''}'
        '${slots.isEmpty ? '' : ', next ${slots.first}'}');
    return native;
  }

  AdhanAlarm _alarm(AdhanSlot s, int id, String? muezzinName, bool arabic,
          AdhanDownload? download) =>
      AdhanAlarm(
        id: id,
        at: s.at,
        prayer: s.prayer,
        title: adhanTitle(s.prayer, arabic),
        body: adhanBody(s.prayer, muezzinName, arabic, playing: true),
        file: fileFor(s.prayer, download),
      );

  /// "Test the adhan": [prayer]'s adhan at [at], with id [id] (outside the
  /// planner's range, so a sync leaves it alone). Android plays it through
  /// the native engine, even with the app closed (returns true); iOS posts
  /// the notification with its clip.
  Future<bool> scheduleTest(
    int id,
    PrayerKind prayer,
    DateTime at, {
    required String? muezzinName,
    required bool arabic,
    AdhanDownload? download,
  }) async {
    if (!_ios && _native.supported) {
      final slot = AdhanSlot(id: id, at: at, prayer: prayer);
      if (await _native.test(_alarm(slot, id, muezzinName, arabic, download),
          AdhanNativeStrings.of(arabic: arabic))) {
        return true;
      }
    }
    final channel =
        _ios ? iosSoundChannel(iosSoundFor(prayer, download)) : adhanChannel;
    await _notifications.ensureChannel(channel);
    await _notifications.scheduleAt(
      id: id,
      at: tz.TZDateTime.from(at, tz.local),
      channel: channel,
      route: playRouteFor(prayer),
      title: adhanTitle(prayer, arabic),
      body: adhanBody(prayer, muezzinName, arabic),
      alarmClock: true,
    );
    return false;
  }

  static String adhanTitle(PrayerKind p, bool arabic) =>
      arabic ? 'حان الآن وقت صلاة ${p.ar}' : "It's time for ${p.en}";

  /// [playing]: the text under the Android player's Stop button.
  static String adhanBody(PrayerKind p, String? muezzin, bool arabic,
      {bool playing = false}) {
    if (p == PrayerKind.fajr) {
      return arabic ? 'الصلاة خير من النوم' : 'Prayer is better than sleep';
    }
    if (muezzin != null) return muezzin;
    if (playing) return arabic ? 'يُرفع الأذان' : 'The adhan is playing';
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
