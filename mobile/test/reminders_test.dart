import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/core/notifications/local_notifications.dart';
import 'package:lahuma/features/prayer_times/domain/prayer_times.dart';
import 'package:lahuma/features/quran/mushaf/domain/mushaf_meta.dart';
import 'package:lahuma/features/reminders/data/reminder_notifications.dart';
import 'package:lahuma/features/reminders/domain/reminder_plan.dart';
import 'package:lahuma/features/reminders/presentation/reminder_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

DayPrayerTimes dayOf(DateTime d) => DayPrayerTimes(
      date: DateTime(d.year, d.month, d.day),
      times: {
        PrayerKind.fajr: DateTime(d.year, d.month, d.day, 5, 30),
        PrayerKind.sunrise: DateTime(d.year, d.month, d.day, 7),
        PrayerKind.dhuhr: DateTime(d.year, d.month, d.day, 12, 45),
        PrayerKind.asr: DateTime(d.year, d.month, d.day, 15, 50),
        PrayerKind.maghrib: DateTime(d.year, d.month, d.day, 18, 20),
        PrayerKind.isha: DateTime(d.year, d.month, d.day, 19, 40),
      },
      hijri: null,
    );

List<DayPrayerTimes> week(DateTime from) => [
      for (var i = 0; i < 7; i++)
        dayOf(DateTime(from.year, from.month, from.day + i))
    ];

class RecordingNotifications extends LocalNotifications {
  final scheduled = <int, ({DateTime at, String title, String? route})>{};

  @override
  Future<List<({int id, String? route})>> pending() async => [
        for (final e in scheduled.entries) (id: e.key, route: e.value.route)
      ];

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);

  @override
  Future<void> ensureChannel(NotificationChannelSpec channel) async {}

  @override
  Future<void> scheduleAt({
    required int id,
    required at,
    required String title,
    required String body,
    required NotificationChannelSpec channel,
    String? route,
    bool alarmClock = false,
    String? category,
    repeat,
  }) async {
    scheduled[id] = (at: at as DateTime, title: title, route: route);
  }
}

void main() {
  // Sunday 8 November 2026; the Friday is the 13th.
  final sunday = DateTime(2026, 11, 8);

  group('ReminderKind', () {
    test('frequencies add reminders, never remove them', () {
      Set<ReminderKind> at(ReminderFrequency f) =>
          {for (final k in ReminderKind.values) if (k.sentAt(f)) k};
      expect(at(ReminderFrequency.off), isEmpty);
      expect(at(ReminderFrequency.rare), {
        ReminderKind.morningAdhkar,
        ReminderKind.eveningAdhkar,
        ReminderKind.kahf,
      });
      expect(at(ReminderFrequency.moderate),
          {...at(ReminderFrequency.rare), ReminderKind.mulk, ReminderKind.salawat});
      expect(at(ReminderFrequency.frequent), ReminderKind.values.toSet());
    });

    test('times sit in their windows of the day', () {
      final d = dayOf(sunday);
      DateTime t(ReminderKind k) => k.timeOn(d);
      expect(t(ReminderKind.morningAdhkar), DateTime(2026, 11, 8, 6));
      expect(t(ReminderKind.morningAdhkar).isBefore(d[PrayerKind.sunrise]),
          isTrue);
      expect(t(ReminderKind.eveningAdhkar), DateTime(2026, 11, 8, 16, 20));
      expect(t(ReminderKind.midday), DateTime(2026, 11, 8, 13, 25));
      // Isha 19:40 + 90 min = 21:10, raised to 21:45.
      expect(t(ReminderKind.sleepAdhkar), DateTime(2026, 11, 8, 21, 45));
      expect(t(ReminderKind.mulk), DateTime(2026, 11, 8, 21));
    });

    test('a short morning still lands between Fajr and sunrise', () {
      final d = DayPrayerTimes(date: sunday, hijri: null, times: {
        ...dayOf(sunday).times,
        PrayerKind.fajr: DateTime(2026, 11, 8, 5, 30),
        PrayerKind.sunrise: DateTime(2026, 11, 8, 5, 55),
      });
      final at = ReminderKind.morningAdhkar.timeOn(d);
      expect(at, DateTime(2026, 11, 8, 5, 40));
    });

    test('Mushaf pages open on Al-Kahf and Al-Mulk', () {
      // Al-Kahf opens partway down page 293, after the end of Al-Isra.
      bool on(int page, int surah) =>
          MushafMeta.surahsOn(page).any((s) => s.surah == surah);
      expect(on(ReminderKind.kahfPage, 18), isTrue);
      expect(on(ReminderKind.kahfPage - 1, 18), isFalse);
      expect(MushafMeta.surahOf(ReminderKind.mulkPage), 67);
      expect(MushafMeta.surahOf(ReminderKind.mulkPage - 1), isNot(67));
      expect(ReminderKind.mulk.route, '/mushaf?page=562');
    });
  });

  group('ReminderPlanner', () {
    test('Android: a week ahead, Friday ones on Friday only', () {
      final slots = ReminderPlanner.plan(
        days: week(sunday),
        frequency: ReminderFrequency.moderate,
        now: DateTime(2026, 11, 8, 12),
        ios: false,
      );
      // Today: evening + Mulk. Then 6 days × 3, and Friday's 2 extra.
      expect(slots.length, 2 + 6 * 3 + 2);
      final friday = slots.where((s) => s.kind.friday);
      expect(friday.every((s) => s.at.weekday == DateTime.friday), isTrue);
      expect(slots.map((s) => s.id).toSet().length, slots.length);
      expect(slots.every((s) => ReminderPlanner.isReminderId(s.id)), isTrue);
      for (var i = 1; i < slots.length; i++) {
        expect(slots[i].at.isBefore(slots[i - 1].at), isFalse);
      }
    });

    test('off or no prayer times: nothing', () {
      expect(
          ReminderPlanner.plan(
              days: week(sunday),
              frequency: ReminderFrequency.off,
              now: sunday,
              ios: false),
          isEmpty);
      expect(
          ReminderPlanner.plan(
              days: const [],
              frequency: ReminderFrequency.frequent,
              now: sunday,
              ios: false),
          isEmpty);
    });

    test('iOS: one repeating notification per kind, within the budget', () {
      final slots = ReminderPlanner.plan(
        days: week(sunday),
        frequency: ReminderFrequency.frequent,
        now: DateTime(2026, 11, 8, 12),
        ios: true,
      );
      expect(slots.length, ReminderPlanner.iosBudget);
      expect(slots.every((s) => s.repeats), isTrue);
      final kahf = slots.firstWhere((s) => s.kind == ReminderKind.kahf);
      expect(kahf.at.weekday, DateTime.friday);
    });

    test('ids stay clear of the adhan and the khatma', () {
      final id = ReminderPlanner.idFor(DateTime(2199, 12, 31),
          ReminderKind.values.last);
      expect(ReminderPlanner.isReminderId(id), isTrue);
      expect(ReminderPlanner.minId, greaterThanOrEqualTo(230000100));
    });
  });

  group('ReminderNotifier', () {
    setUpAll(() {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.UTC);
    });
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to moderate and replaces the schedule on change',
        () async {
      final n = RecordingNotifications();
      final notifier = ReminderNotifier(
        repository: ReminderSettingsRepository(),
        notifications: ReminderNotifications(n),
        days: () => week(sunday),
        arabic: () => true,
        now: () => DateTime(2026, 11, 8, 12),
        ios: false,
      );
      await notifier.ready;
      expect(notifier.state.frequency, ReminderFrequency.moderate);
      expect(n.scheduled.length, 22);

      await notifier.setFrequency(ReminderFrequency.rare);
      expect(n.scheduled.length, 1 + 6 * 2 + 1);
      expect(
          n.scheduled.values.map((s) => s.title).toSet(),
          {'أذكار المساء', 'أذكار الصباح', 'سورة الكهف'});

      await notifier.setFrequency(ReminderFrequency.off);
      expect(n.scheduled, isEmpty);
      expect((await SharedPreferences.getInstance())
          .getString('reminders.frequency'), 'off');
      notifier.dispose();
    });

    test('no prayer times yet: pending reminders stay', () async {
      final n = RecordingNotifications();
      n.scheduled[ReminderPlanner.minId + 100] =
          (at: DateTime(2026, 11, 9), title: 'x', route: null);
      final notifier = ReminderNotifier(
        repository: ReminderSettingsRepository(),
        notifications: ReminderNotifications(n),
        days: () => const [],
        arabic: () => true,
        now: () => sunday,
        ios: false,
      );
      await notifier.ready;
      expect(n.scheduled.length, 1);
      notifier.dispose();
    });
  });

  test('provider builds', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(reminderSettingsRepositoryProvider), isNotNull);
  });
}
