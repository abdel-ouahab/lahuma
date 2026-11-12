import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show RepeatInterval;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/constants/storage_keys.dart';
import '../../../core/notifications/local_notifications.dart';
import '../domain/reminder_plan.dart';

/// What a reminder says. Short, in the user's words, and only what the
/// Quran and the Sunnah say about it.
class ReminderText {
  const ReminderText._();

  static String title(ReminderKind k, {required bool arabic}) => switch (k) {
        ReminderKind.morningAdhkar => arabic ? 'أذكار الصباح' : 'Morning adhkar',
        ReminderKind.eveningAdhkar => arabic ? 'أذكار المساء' : 'Evening adhkar',
        ReminderKind.sleepAdhkar => arabic ? 'أذكار النوم' : 'Adhkar before sleep',
        ReminderKind.kahf => arabic ? 'سورة الكهف' : 'Surah Al-Kahf',
        ReminderKind.mulk => arabic ? 'سورة الملك' : 'Surah Al-Mulk',
        ReminderKind.midday => arabic ? 'سبحان الله وبحمده' : 'Subhan Allah wa bihamdih',
        ReminderKind.salawat =>
          arabic ? 'الصلاة على النبي ﷺ' : 'Blessings on the Prophet ﷺ',
      };

  static String body(ReminderKind k, {required bool arabic}) => switch (k) {
        ReminderKind.morningAdhkar => arabic
            ? 'ابدأ يومك بذكر الله قبل شروق الشمس. اضغط لتبدأ.'
            : 'Start your day remembering Allah, before sunrise. Tap to begin.',
        ReminderKind.eveningAdhkar => arabic
            ? 'قبل غروب الشمس، خذ دقائق لأذكار المساء. اضغط لتبدأ.'
            : 'Take a few minutes before sunset for the evening adhkar. Tap to begin.',
        ReminderKind.sleepAdhkar => arabic
            ? 'اختم يومك بأذكار النوم قبل أن تغفو.'
            : 'Close your day with the adhkar before sleep.',
        ReminderKind.kahf => arabic
            ? 'اليوم الجمعة. اقرأ سورة الكهف قبل المغرب. اضغط لتفتح المصحف.'
            : "It's Friday. Read Surah Al-Kahf before Maghrib. Tap to open the Mushaf.",
        ReminderKind.mulk => arabic
            ? 'اقرأ سورة الملك الليلة قبل أن تنام. اضغط لتفتح المصحف.'
            : 'Read Surah Al-Mulk tonight before you sleep. Tap to open the Mushaf.',
        ReminderKind.midday => arabic
            ? 'مئة مرة في يومك تُحَطّ بها خطاياك. اضغط لتعدّها بالمسبحة.'
            : 'Say it a hundred times today and your sins are wiped away. Tap to count.',
        ReminderKind.salawat => arabic
            ? 'اليوم الجمعة. أكثِر من الصلاة على النبي ﷺ.'
            : "It's Friday. Send many blessings on the Prophet ﷺ.",
      };

  /// Beside the app name in the notification header.
  static String category(ReminderKind k, {required bool arabic}) =>
      switch (k.target) {
        ReminderTarget.mushaf => arabic ? 'القرآن' : 'Quran',
        ReminderTarget.adhkar || ReminderTarget.tasbih =>
          arabic ? 'الأذكار' : 'Adhkar',
      };
}

/// The chosen frequency, in prefs (plain Dart: the background isolate
/// reads it too).
class ReminderSettingsRepository {
  Future<ReminderFrequency> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ReminderFrequency.fromName(
        prefs.getString(StorageKeys.reminderFrequency));
  }

  Future<void> save(ReminderFrequency frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.reminderFrequency, frequency.name);
  }
}

/// Replaces the pending adhkar and surah reminders with [slots].
class ReminderNotifications {
  ReminderNotifications(this._notifications);

  final LocalNotifications _notifications;

  static const channel = NotificationChannelSpec(
    id: 'reminders',
    name: 'الأذكار والسور · Adhkar & surahs',
    description: 'تذكير بالأذكار وسورة الكهف والملك · '
        'Adhkar, Al-Kahf and Al-Mulk reminders',
  );

  Future<void> sync(List<ReminderSlot> slots, {required bool arabic}) async {
    for (final p in await _notifications.pending()) {
      if (ReminderPlanner.isReminderId(p.id)) {
        await _notifications.cancel(p.id);
      }
    }
    if (slots.isEmpty) return;
    await _notifications.ensureChannel(channel);
    for (final s in slots) {
      await _notifications.scheduleAt(
        id: s.id,
        at: tz.TZDateTime(
            tz.local, s.at.year, s.at.month, s.at.day, s.at.hour, s.at.minute),
        channel: channel,
        route: s.kind.route,
        title: ReminderText.title(s.kind, arabic: arabic),
        body: ReminderText.body(s.kind, arabic: arabic),
        category: ReminderText.category(s.kind, arabic: arabic),
        repeat: !s.repeats
            ? null
            : s.kind.friday
                ? RepeatInterval.weekly
                : RepeatInterval.daily,
      );
    }
    debugPrint('Reminders: ${slots.length} scheduled, next ${slots.first}');
  }
}
