import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/notifications/local_notifications.dart';
import '../domain/fajr_call_list.dart';

/// Fajr notifications for manual mode (and iOS): one per upcoming fire
/// time, opening the wake list for that list and that morning.
class FajrNotifications {
  FajrNotifications(this._notifications);

  final LocalNotifications _notifications;

  static const channel = NotificationChannelSpec(
    id: 'fajr_call',
    name: 'نداء الفجر · Fajr Call',
    description: 'تنبيه وقت الفجر لإيقاظ من تحب · Fajr wake-up reminders',
    timeSensitive: true,
  );

  static const String routePrefix = '/fajr-call/wake/';

  /// iOS keeps at most 64 pending notifications per app: the adhan takes 45
  /// (`AdhanPlanner.iosBudget`) and the khatma 4 (`KhatmaReminderPlan.iosBudget`),
  /// leaving 15 here. Android has no such cap.
  static int get maxPending =>
      defaultTargetPlatform == TargetPlatform.iOS ? 15 : 60;
  static const int maxPerList = 14;

  static String wakeRoute(String listId, DateTime at) =>
      '$routePrefix$listId?at=${at.millisecondsSinceEpoch}';

  static int idFor(String listId, int index) =>
      (stableHash(listId) % 1000000) * 16 + index;

  /// How many fire times each list gets when [listCount] lists share the
  /// pending-notification budget.
  static int perList(int listCount) =>
      (maxPending ~/ (listCount < 1 ? 1 : listCount)).clamp(1, maxPerList);

  /// Replaces every pending Fajr notification with [lists].
  Future<void> sync(
    List<({FajrCallList list, List<tz.TZDateTime> times})> lists, {
    required bool arabic,
  }) async {
    for (final p in await _notifications.pending()) {
      if (p.route?.startsWith(routePrefix) ?? false) {
        await _notifications.cancel(p.id);
      }
    }
    final limit = perList(lists.length);
    for (final e in lists) {
      final names =
          e.list.contacts.map((c) => c.name).join(arabic ? '، ' : ', ');
      final times = e.times.take(limit).toList();
      for (var i = 0; i < times.length; i++) {
        await _notifications.scheduleAt(
          id: idFor(e.list.id, i),
          at: times[i],
          channel: channel,
          route: wakeRoute(e.list.id, times[i]),
          title: arabic
              ? 'نداء الفجر · ${e.list.name}'
              : 'Fajr Call · ${e.list.name}',
          body: arabic
              ? 'حان وقت الفجر. اضغط لتتصل بـ $names'
              : "It's time for Fajr. Tap to call $names",
        );
      }
    }
  }
}
