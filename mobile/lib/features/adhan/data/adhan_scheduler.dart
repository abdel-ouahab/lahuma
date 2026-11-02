import 'package:timezone/timezone.dart' as tz;
import '../../../core/notifications/local_notifications.dart';
import '../../prayer_times/domain/prayer_times.dart';
import '../domain/adhan_plan.dart';
import '../domain/muezzin.dart';

/// Turns an adhan plan into scheduled notifications.
///
/// Android: one channel per muezzin + sound + version (a channel's sound is
/// fixed once created), alarm usage, max importance; obsolete channels are
/// deleted. iOS: the sound is a file name in `Library/Sounds` or the
/// bundle, played at the Time Sensitive level.
class AdhanScheduler {
  AdhanScheduler(this._notifications);

  final LocalNotifications _notifications;

  static const String channelPrefix = 'adhan_';

  /// Tapping an adhan opens the full-length player.
  static const String playRoute = '/adhan/play';

  static String playRouteFor(PrayerKind prayer) =>
      '$playRoute?prayer=${prayer.name}';

  /// Bundled fallback: `res/raw/adhan_default_regular.mp3` on Android,
  /// `Runner/adhan_default_regular.caf` on iOS. There is no Fajr recording
  /// yet, so Fajr uses the same one.
  static String defaultSoundName({required bool fajr}) =>
      'adhan_default_regular';

  /// Bump when the bundled recording changes: a channel's sound is fixed
  /// once created, so the default channels need new ids.
  static const int defaultSoundVersion = 2;

  static const reminderChannel = NotificationChannelSpec(
    id: 'adhan_reminder',
    name: 'تذكير قبل الصلاة · Prayer reminder',
    description: 'اقترب وقت الصلاة · Before each prayer',
    timeSensitive: true,
  );

  /// The channel (and sound) for an adhan, from [download] when its file is
  /// ready, else the bundled default.
  static NotificationChannelSpec channelFor({
    required bool fajr,
    required AdhanDownload? download,
    required String? muezzinName,
  }) {
    final full = AdhanSoundKind.full(fajr: fajr);
    final short = AdhanSoundKind.short(fajr: fajr);
    final uri = download?.androidUris[full];
    final iosName = download?.iosSounds[short];
    final custom = download != null && (uri != null || iosName != null);
    final fallback = defaultSoundName(fajr: fajr);
    final label = fajr ? 'أذان الفجر · Fajr adhan' : 'الأذان · Adhan';
    return NotificationChannelSpec(
      id: custom
          ? '$channelPrefix${download.muezzinId}_${full.name}_v${download.version}'
          : '${channelPrefix}default_${full.name}_v$defaultSoundVersion',
      name: custom && muezzinName != null ? '$label · $muezzinName' : label,
      description: 'وقت الصلاة · Prayer time',
      timeSensitive: true,
      alarm: true,
      sound: NotificationSound(
        androidUri: uri,
        androidRaw: uri == null ? fallback : null,
        iosName: iosName ?? '$fallback.caf',
      ),
    );
  }

  /// Replaces every pending adhan notification with [slots].
  Future<void> sync(
    List<AdhanSlot> slots, {
    required AdhanDownload? download,
    required String? muezzinName,
    required bool arabic,
  }) async {
    for (final p in await _notifications.pending()) {
      if (AdhanPlanner.isAdhanId(p.id)) await _notifications.cancel(p.id);
    }
    final used = <String>{reminderChannel.id};
    if (slots.any((s) => s.reminder)) {
      await _notifications.ensureChannel(reminderChannel);
    }
    for (final s in slots) {
      final fajr = s.prayer == PrayerKind.fajr;
      final channel = s.reminder
          ? reminderChannel
          : channelFor(
              fajr: fajr, download: download, muezzinName: muezzinName);
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
      );
    }
    await _notifications.deleteChannels(prefix: channelPrefix, keep: used);
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
