import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// A notification channel (Android) and how loud it is. iOS has no channels;
/// [timeSensitive] maps to the Time Sensitive interruption level there.
class NotificationChannelSpec {
  const NotificationChannelSpec({
    required this.id,
    required this.name,
    required this.description,
    this.timeSensitive = false,
  });

  final String id;
  final String name;
  final String description;
  final bool timeSensitive;
}

/// App-wide local notifications (wraps `flutter_local_notifications`).
///
/// Shared by Fajr Call and, later, the reading / adhkar reminders (F1):
/// features schedule through [scheduleAt] with a payload that is a route
/// (`/fajr-call/wake/…`). A tap on a notification is delivered as that
/// route through [taps], or through [takeLaunchRoute] when the tap launched
/// the app.
class LocalNotifications {
  LocalNotifications({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();
  Future<void>? _init;
  String? _launchRoute;

  /// False when the plugin is missing (tests, unsupported platforms).
  bool _available = true;

  /// Routes from notifications tapped while the app is running.
  Stream<String> get taps => _taps.stream;

  bool get _supported =>
      _available &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Loads timezone data, points `tz.local` at the device timezone and
  /// initialises the plugin. Safe to call more than once.
  Future<void> init() => _init ??= _doInit();

  Future<void> _doInit() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Unknown identifier or no plugin (tests): keep tz.local as UTC and
      // let callers pass explicit locations.
    }
    if (!_supported) return;

    try {
      await _initPlugin();
    } catch (e) {
      // MissingPluginException in tests; anything else must not stop the
      // app from starting.
      debugPrint('Local notifications unavailable: $e');
      _available = false;
    }
  }

  Future<void> _initPlugin() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permissions are requested in context, never at launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.startsWith('/')) _taps.add(route);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if ((launch?.didNotificationLaunchApp ?? false) &&
        payload != null &&
        payload.startsWith('/')) {
      _launchRoute = payload;
    }
  }

  /// Records a launch route from a notification posted outside this plugin
  /// (the Android call engine posts its own).
  void setLaunchRoute(String route) {
    if (route.startsWith('/')) _launchRoute ??= route;
  }

  /// The route of the notification that launched the app, once.
  String? takeLaunchRoute() {
    final route = _launchRoute;
    _launchRoute = null;
    return route;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  /// Whether notifications may be shown (Android 13+ / iOS permission).
  Future<bool> areEnabled() async {
    await init();
    if (!_supported) return false;
    if (_android != null) return await _android!.areNotificationsEnabled() ?? false;
    final ios = await _ios?.checkPermissions();
    return ios?.isEnabled ?? false;
  }

  /// Shows the system permission prompt. Returns whether it was granted.
  Future<bool> requestPermission() async {
    await init();
    if (!_supported) return false;
    if (_android != null) {
      return await _android!.requestNotificationsPermission() ?? false;
    }
    return await _ios?.requestPermissions(
            alert: true, sound: true, badge: false) ??
        false;
  }

  /// Android 12+: whether exact alarms are allowed. Always true elsewhere.
  Future<bool> canScheduleExact() async {
    await init();
    if (!_supported || _android == null) return true;
    return await _android!.canScheduleExactNotifications() ?? false;
  }

  /// Android 12+: opens the "Alarms & reminders" settings page.
  Future<void> requestExactAlarms() async {
    await init();
    if (!_supported) return;
    await _android?.requestExactAlarmsPermission();
  }

  /// Schedules a one-off notification at [at]. Uses an exact alarm when
  /// allowed; otherwise Android may deliver it a few minutes late.
  Future<void> scheduleAt({
    required int id,
    required tz.TZDateTime at,
    required String title,
    required String body,
    required NotificationChannelSpec channel,
    String? route,
  }) async {
    await init();
    if (!_supported) return;
    final exact = await canScheduleExact();
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: at,
      title: title,
      body: body,
      payload: route,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance:
              channel.timeSensitive ? Importance.max : Importance.defaultImportance,
          priority:
              channel.timeSensitive ? Priority.high : Priority.defaultPriority,
          category: channel.timeSensitive
              ? AndroidNotificationCategory.reminder
              : null,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          interruptionLevel: channel.timeSensitive
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
        ),
      ),
    );
  }

  /// Ids and routes of the notifications still waiting to fire.
  Future<List<({int id, String? route})>> pending() async {
    await init();
    if (!_supported) return const [];
    final requests = await _plugin.pendingNotificationRequests();
    return [for (final r in requests) (id: r.id, route: r.payload)];
  }

  Future<void> cancel(int id) async {
    await init();
    if (!_supported) return;
    await _plugin.cancel(id: id);
  }
}

/// Stable 31-bit hash (FNV-1a) for deriving notification ids from string
/// ids; `String.hashCode` is not guaranteed stable between runs.
int stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// Keeps a widget's hand on [LocalNotifications.taps] for its lifetime.
typedef NotificationRouteHandler = void Function(String route);

/// Listens to notification taps and forwards their routes to [onRoute].
class NotificationTapListener extends StatefulWidget {
  const NotificationTapListener({
    super.key,
    required this.notifications,
    required this.onRoute,
    required this.child,
  });

  final LocalNotifications notifications;
  final NotificationRouteHandler onRoute;
  final Widget child;

  @override
  State<NotificationTapListener> createState() =>
      _NotificationTapListenerState();
}

class _NotificationTapListenerState extends State<NotificationTapListener> {
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.notifications.taps.listen(widget.onRoute);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
