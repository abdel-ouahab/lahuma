import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/notifications/local_notifications.dart';
import '../domain/khatma.dart';
import '../domain/khatma_reminders.dart';
import '../domain/khatma_text.dart';

/// The khatma's daily reminders. Every sync replaces all of them, so the
/// text always carries the real amount left.
class KhatmaNotifications {
  KhatmaNotifications(this._notifications);

  final LocalNotifications _notifications;

  static const channel = NotificationChannelSpec(
    id: 'khatma',
    name: 'ختمة القرآن · Khatma',
    description: 'تذكير بورد الختمة اليومي · Daily Quran khatma reminders',
  );

  static const String route = '/khatma';

  /// Replaces the pending khatma reminders with those [khatma] needs from
  /// [now]; none when it is null, paused or finished.
  Future<void> sync(
    Khatma? khatma, {
    required DateTime now,
    required bool arabic,
  }) async {
    for (final p in await _notifications.pending()) {
      if (KhatmaReminderPlan.isKhatmaId(p.id)) {
        await _notifications.cancel(p.id);
      }
    }
    if (khatma == null) return;
    final reminders = KhatmaReminderPlan.plan(khatma, now,
        ios: defaultTargetPlatform == TargetPlatform.iOS);
    for (final r in reminders) {
      await _notifications.scheduleAt(
        id: r.id,
        at: tz.TZDateTime(
            tz.local, r.at.year, r.at.month, r.at.day, r.at.hour, r.at.minute),
        channel: channel,
        route: route,
        title: arabic ? 'ورد الختمة' : 'Khatma reading',
        body: body(r, arabic: arabic),
      );
    }
  }

  /// "وردك اليوم: 20 صفحة — من صفحة 142 (الأنعام) إلى 161", or, once some
  /// of it is read (and every evening), "بقي لك اليوم 8 صفحات لإتمام وردك".
  static String body(KhatmaReminder r, {required bool arabic}) {
    final pages = KhatmaText.pages(r.pages, arabic: arabic);
    if (r.partial || r.kind == KhatmaReminderKind.evening) {
      return arabic
          ? 'بقي لك اليوم $pages لإتمام وردك (حتى صفحة ${r.toPage})'
          : "$pages left to finish today's portion (up to page ${r.toPage})";
    }
    final range = KhatmaText.range(r.fromPage, r.toPage, arabic: arabic);
    return arabic
        ? 'وردك اليوم: $pages — $range'
        : "Today's portion: $pages — $range";
  }
}
