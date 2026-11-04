import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../prayer_times/domain/prayer_times.dart';

/// One exact alarm that plays the full adhan (Android).
class AdhanAlarm {
  const AdhanAlarm({
    required this.id,
    required this.at,
    required this.prayer,
    required this.title,
    required this.body,
    this.file,
  });

  /// The planner's stable id; also the alarm's PendingIntent request code.
  final int id;
  final DateTime at;
  final PrayerKind prayer;
  final String title;
  final String body;

  /// A downloaded muezzin's full recording; null plays the bundled one
  /// (`res/raw/adhan_default_regular.mp3`).
  final String? file;

  Map<String, Object?> toMap() => {
        'id': id,
        'at': at.millisecondsSinceEpoch,
        'prayer': prayer.name,
        'title': title,
        'body': body,
        'file': file,
      };
}

/// Texts the native side shows; the app language is an in-app setting.
class AdhanNativeStrings {
  const AdhanNativeStrings({
    required this.stop,
    required this.channel,
    required this.fallbackChannel,
  });

  factory AdhanNativeStrings.of({required bool arabic}) => AdhanNativeStrings(
        stop: arabic ? 'إيقاف' : 'Stop',
        channel: arabic ? 'الأذان' : 'Adhan',
        fallbackChannel: arabic ? 'وقت الصلاة' : 'Prayer time',
      );

  final String stop;
  final String channel;
  final String fallbackChannel;

  Map<String, String> toMap() =>
      {'stop': stop, 'channel': channel, 'fallbackChannel': fallbackChannel};
}

/// The phone makers whose battery savers need a manual step.
enum PhoneMaker { xiaomi, oppo, huawei, samsung, other }

/// What can stop the adhan from playing with the app closed (Android).
class AdhanReliability {
  const AdhanReliability({
    this.exactAlarms = true,
    this.ignoringBatteryOptimizations = true,
    this.maker = PhoneMaker.other,
    this.manufacturer = '',
    this.sdk = 0,
  });

  final bool exactAlarms;
  final bool ignoringBatteryOptimizations;
  final PhoneMaker maker;

  /// `Build.MANUFACTURER`, as the phone reports it.
  final String manufacturer;
  final int sdk;

  static PhoneMaker makerOf(String manufacturer) {
    final m = manufacturer.toLowerCase();
    if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) {
      return PhoneMaker.xiaomi;
    }
    if (m.contains('oppo') || m.contains('realme') || m.contains('oneplus')) {
      return PhoneMaker.oppo;
    }
    if (m.contains('huawei') || m.contains('honor')) return PhoneMaker.huawei;
    if (m.contains('samsung')) return PhoneMaker.samsung;
    return PhoneMaker.other;
  }

  factory AdhanReliability.fromMap(Map<dynamic, dynamic> m) {
    final manufacturer = '${m['manufacturer'] ?? ''}';
    return AdhanReliability(
      exactAlarms: m['exactAlarms'] != false,
      ignoringBatteryOptimizations: m['ignoringBatteryOptimizations'] == true,
      maker: makerOf(manufacturer),
      manufacturer: manufacturer,
      sdk: (m['sdk'] as num?)?.toInt() ?? 0,
    );
  }
}

/// `lahuma/adhan_alarm`: the Android alarm engine that plays the adhan
/// with the app closed.
///
/// Native side: `android/app/src/main/kotlin/com/lahuma/app/adhan/`.
/// Exact alarms (`setAlarmClock`) fire `AdhanAlarmReceiver`, which starts
/// `AdhanPlaybackService` (a `mediaPlayback` foreground service playing as
/// a notification sound). The alarms are kept natively and re-armed after a
/// reboot, an update or a clock change; a WorkManager job then runs
/// [adhanBackgroundMain] to recompute them, and again once a day.
///
/// Everything here is a no-op returning false off Android, or when the
/// channel is missing (tests).
class AdhanAlarmPlatform {
  const AdhanAlarmPlatform();

  static const MethodChannel _channel = MethodChannel('lahuma/adhan_alarm');

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<T?> _invoke<T>(String method, [Object? args]) async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } catch (e) {
      // PlatformException, or no binding (unit tests).
      debugPrint('Adhan alarm: $method failed: $e');
      return null;
    }
  }

  /// Replaces every armed adhan alarm with [alarms]. False when the engine
  /// isn't there; the caller then falls back to notifications.
  Future<bool> sync(
          List<AdhanAlarm> alarms, AdhanNativeStrings strings) async =>
      await _invoke<bool>('sync', {
        'alarms': [for (final a in alarms) a.toMap()],
        'strings': strings.toMap(),
      }) ??
      false;

  /// Arms one test alarm (kept apart from [sync]'s).
  Future<bool> test(AdhanAlarm alarm, AdhanNativeStrings strings) async =>
      await _invoke<bool>(
          'test', {'alarm': alarm.toMap(), 'strings': strings.toMap()}) ??
      false;

  /// True, once, when this launch found the armed adhans cancelled: the
  /// app was force-stopped (Settings, or a swipe from Recents on ColorOS
  /// and other skins), so any adhan due since then didn't play.
  Future<bool> takeCleared() async =>
      await _invoke<bool>('takeCleared') ?? false;

  /// Stops an adhan that is playing.
  Future<void> stop() => _invoke<void>('stop');

  /// Schedules the daily WorkManager reschedule (kept if already there).
  Future<void> ensureDaily() => _invoke<void>('ensureDaily');

  Future<AdhanReliability> reliability() async {
    final m = await _invoke<Map<dynamic, dynamic>>('reliability');
    return m == null ? const AdhanReliability() : AdhanReliability.fromMap(m);
  }

  /// The system "ignore battery optimisations" dialog, or its list page.
  Future<void> requestIgnoreBatteryOptimizations() =>
      _invoke<void>('requestIgnoreBatteryOptimizations');

  /// Tries the maker's autostart / battery page; true when one opened.
  /// Falls back to the app's settings page (false).
  Future<bool> openMakerSettings(PhoneMaker maker) async =>
      await _invoke<bool>('openMakerSettings', {'maker': maker.name}) ?? false;

  Future<void> openAppSettings() => _invoke<void>('openAppSettings');

  /// Background engine only: the reschedule finished.
  Future<void> backgroundDone() => _invoke<void>('done');
}
