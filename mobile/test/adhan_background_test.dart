import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/core/notifications/local_notifications.dart';
import 'package:lahuma/features/adhan/background/adhan_background.dart';
import 'package:lahuma/features/adhan/data/adhan_alarm_platform.dart';
import 'package:lahuma/features/adhan/data/adhan_scheduler.dart';
import 'package:lahuma/features/adhan/data/adhan_settings_repository.dart';
import 'package:lahuma/features/adhan/domain/adhan_plan.dart';
import 'package:lahuma/features/adhan/domain/adhan_settings.dart';
import 'package:lahuma/features/adhan/domain/muezzin.dart';
import 'package:lahuma/features/prayer_times/data/prayer_days_source.dart';
import 'package:lahuma/features/prayer_times/data/prayer_times_cache.dart';
import 'package:lahuma/features/prayer_times/data/prayer_times_service.dart';
import 'package:lahuma/features/prayer_times/domain/local_prayer_times.dart';
import 'package:lahuma/features/prayer_times/domain/prayer_times.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'adhan_test.dart' show FakeMuezzins, FakeStore, dayOf, week;

class FakeNative extends AdhanAlarmPlatform {
  FakeNative({this.available = true});
  final bool available;
  final syncs = <List<AdhanAlarm>>[];
  final tests = <AdhanAlarm>[];
  int dailies = 0;

  @override
  bool get supported => true;

  @override
  Future<bool> sync(List<AdhanAlarm> alarms, AdhanNativeStrings strings) async {
    syncs.add(alarms);
    return available;
  }

  @override
  Future<bool> test(AdhanAlarm alarm, AdhanNativeStrings strings) async {
    tests.add(alarm);
    return available;
  }

  @override
  Future<void> ensureDaily() async => dailies++;
}

class FakeMonthsApi extends PrayerTimesApiService {
  bool fail = false;
  int calls = 0;

  @override
  Future<List<DayPrayerTimes>> fetchMonths(
      List<DateTime> days, double lat, double lng) async {
    calls++;
    if (fail) throw Exception('offline');
    final months = {for (final d in days) (d.year, d.month)};
    return [
      for (final (y, m) in months)
        for (var d = 1; d <= DateTime(y, m + 1, 0).day; d++)
          dayOf(DateTime(y, m, d)),
    ];
  }
}

class RecordingScheduler extends AdhanScheduler {
  RecordingScheduler() : super(LocalNotifications(), ios: false);
  final syncs = <List<AdhanSlot>>[];

  @override
  Future<bool> sync(List<AdhanSlot> slots,
      {required String? muezzinName,
      required bool arabic,
      AdhanDownload? download}) async {
    syncs.add(slots);
    return true;
  }
}

const algiers =
    PrayerLocation(latitude: 36.75, longitude: 3.06, city: 'الجزائر');

Future<void> seedCache(DateTime now, List<DayPrayerTimes> days,
    {PrayerLocation? location = algiers}) async {
  await PrayerTimesCache().save(
      PrayerTimesSnapshot(
          location: location, days: {for (final d in days) d.key: d}),
      now: now);
}

void main() {
  final now = DateTime(2026, 10, 29, 10);

  group('per-prayer modes', () {
    test('adhan, silent and off', () {
      final s = const AdhanSettings(enabled: true)
          .withMode(PrayerKind.dhuhr, AdhanMode.silent)
          .withMode(PrayerKind.asr, AdhanMode.off);
      expect(s.modeOf(PrayerKind.fajr), AdhanMode.adhan);
      expect(s.modeOf(PrayerKind.dhuhr), AdhanMode.silent);
      expect(s.modeOf(PrayerKind.asr), AdhanMode.off);
      expect(s.plays(PrayerKind.dhuhr), isFalse);

      final slots =
          AdhanPlanner.plan(days: week(now), settings: s, now: now, ios: false);
      expect(slots.any((x) => x.prayer == PrayerKind.asr), isFalse);
      final dhuhr = slots.where((x) => x.prayer == PrayerKind.dhuhr);
      expect(dhuhr, isNotEmpty);
      expect(dhuhr.every((x) => x.silent && !x.audible), isTrue);
      expect(
          slots
              .where((x) => x.prayer == PrayerKind.fajr)
              .every((x) => x.audible),
          isTrue);

      // Back to adhan clears the silent flag.
      expect(s.withMode(PrayerKind.dhuhr, AdhanMode.adhan).silent, isEmpty);
    });

    test('round trip, and settings saved before modes migrate', () {
      final s = const AdhanSettings(enabled: true)
          .withMode(PrayerKind.isha, AdhanMode.silent)
          .withMode(PrayerKind.maghrib, AdhanMode.off);
      expect(AdhanSettings.fromJson(s.toJson()), s);

      final legacy = AdhanSettings.fromJson({
        'enabled': true,
        'prayers': ['fajr', 'isha'],
        'reminderMinutes': 0,
      });
      expect(legacy.modeOf(PrayerKind.fajr), AdhanMode.adhan);
      expect(legacy.modeOf(PrayerKind.isha), AdhanMode.adhan);
      expect(legacy.modeOf(PrayerKind.dhuhr), AdhanMode.off);
    });

    test('plans 7 days (35 adhans) even when more are known', () {
      final days = [
        for (var i = 0; i < 20; i++)
          dayOf(DateTime(now.year, now.month, now.day + i))
      ];
      final slots = AdhanPlanner.plan(
        days: days,
        settings: const AdhanSettings(enabled: true),
        now: DateTime(now.year, now.month, now.day),
        ios: false,
      );
      expect(slots.length, 35);
      expect(slots.map((s) => s.id).toSet().length, 35);
      expect(slots.last.at.isBefore(DateTime(2026, 11, 5)), isTrue);
    });
  });

  group('AdhanScheduler on Android', () {
    test('audible adhans go to the native engine, nothing else', () async {
      final native = FakeNative();
      final scheduler =
          AdhanScheduler(LocalNotifications(), native: native, ios: false);
      final settings = const AdhanSettings(enabled: true, reminderMinutes: 10)
          .withMode(PrayerKind.dhuhr, AdhanMode.silent);
      final slots = AdhanPlanner.plan(
          days: week(now), settings: settings, now: now, ios: false);
      final used = await scheduler.sync(slots,
          muezzinName: null, arabic: true, download: null);
      expect(used, isTrue);
      final alarms = native.syncs.single;
      expect(alarms.length, slots.where((s) => s.audible).length);
      expect(alarms.any((a) => a.prayer == PrayerKind.dhuhr), isFalse);
      expect(alarms.every((a) => AdhanPlanner.isAdhanId(a.id)), isTrue);
      expect(alarms.first.file, isNull); // the bundled res/raw adhan
      expect(native.dailies, 1);
    });

    test('no engine: falls back to notifications', () async {
      final native = FakeNative(available: false);
      final scheduler =
          AdhanScheduler(LocalNotifications(), native: native, ios: false);
      final used = await scheduler.sync(
          AdhanPlanner.plan(
              days: week(now),
              settings: const AdhanSettings(enabled: true),
              now: now,
              ios: false),
          muezzinName: null,
          arabic: true);
      expect(used, isFalse);
      expect(native.dailies, 0);
    });

    test('the test alarm uses an id outside the plan', () async {
      final native = FakeNative();
      final scheduler =
          AdhanScheduler(LocalNotifications(), native: native, ios: false);
      final ok = await scheduler.scheduleTest(AdhanPlanner.maxId,
          PrayerKind.dhuhr, now.add(const Duration(minutes: 1)),
          muezzinName: null, arabic: false);
      expect(ok, isTrue);
      expect(native.tests.single.id, AdhanPlanner.maxId);
      expect(native.tests.single.title, "It's time for Dhuhr");
    });

    test('native channels survive the old-channel cleanup', () {
      for (final id in AdhanScheduler.nativeChannels) {
        expect(id.startsWith(AdhanScheduler.channelPrefix), isTrue);
      }
    });

    test('iOS sound: the muezzin clip, else the bundled one', () {
      expect(AdhanScheduler.iosSoundFor(PrayerKind.isha, null),
          AdhanScheduler.iosDefaultSound);
      const d = AdhanDownload(muezzinId: 'm', version: 1, iosSounds: {
        AdhanSoundKind.regularShort: 'r.caf',
        AdhanSoundKind.fajrShort: 'f.caf',
      });
      expect(AdhanScheduler.iosSoundFor(PrayerKind.fajr, d), 'f.caf');
      expect(AdhanScheduler.iosSoundFor(PrayerKind.asr, d), 'r.caf');
      expect(AdhanScheduler.iosSoundChannel('r.caf').quietInForeground, isTrue);
    });
  });

  group('PrayerDaysSource', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('no saved location: nothing', () async {
      final source = PrayerDaysSource(api: FakeMonthsApi());
      expect(await source.upcoming(now), isEmpty);
    });

    test('cached days first, then whole months from Aladhan, saved', () async {
      await seedCache(now, [dayOf(now)]);
      final api = FakeMonthsApi();
      final days = await PrayerDaysSource(api: api).upcoming(now);
      expect(days.length, 7);
      expect(days.first.key, '2026-10-29');
      expect(days.last.key, '2026-11-04');
      expect(api.calls, 1);
      // The rest of October (and November) is now cached for later.
      final snap = await PrayerTimesCache().load();
      expect(snap.days.containsKey('2026-10-31'), isTrue);
      expect(snap.days.containsKey('2026-11-30'), isTrue);

      // Next run: all cached, no request.
      await PrayerDaysSource(api: api).upcoming(now);
      expect(api.calls, 1);
    });

    test('offline with no cached day: the local calculation', () async {
      await seedCache(now, [dayOf(now)]);
      final api = FakeMonthsApi()..fail = true;
      final days = await PrayerDaysSource(api: api).upcoming(now);
      expect(days.length, 7);
      expect(days.first[PrayerKind.fajr], DateTime(2026, 10, 29, 5, 30));
      final local = days[1];
      expect(local.hijri, isNull);
      for (var i = 1; i < PrayerKind.values.length; i++) {
        expect(
            local[PrayerKind.values[i]]
                .isAfter(local[PrayerKind.values[i - 1]]),
            isTrue);
      }
      // Not saved: Aladhan replaces it once online.
      final snap = await PrayerTimesCache().load();
      expect(snap.days.containsKey(local.key), isFalse);
    });
  });

  test('local fallback is plausible for Algiers', () {
    final d = const LocalPrayerTimes().dayAt(DateTime(2026, 6, 21), algiers);
    expect(d.key, '2026-06-21');
    final dhuhr = d[PrayerKind.dhuhr].toUtc();
    // Solar noon at 3.06° E in late June is about 11:50 UTC.
    expect(dhuhr.hour, 11);
    expect(dhuhr.minute, inInclusiveRange(40, 59));
    expect(d[PrayerKind.fajr].isBefore(d[PrayerKind.sunrise]), isTrue);
    expect(d[PrayerKind.maghrib].isBefore(d[PrayerKind.isha]), isTrue);
  });

  group('AdhanBackgroundReschedule', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    AdhanBackgroundReschedule make(RecordingScheduler scheduler) =>
        AdhanBackgroundReschedule(
          scheduler: scheduler,
          muezzins: FakeMuezzins(),
          store: FakeStore(),
          days: PrayerDaysSource(api: FakeMonthsApi()..fail = true),
          arabic: () async => true,
          ios: false,
        );

    test('rebuilds the week from the saved settings and times', () async {
      await AdhanSettingsRepository()
          .saveSettings(const AdhanSettings(enabled: true));
      await seedCache(now, week(now));
      final scheduler = RecordingScheduler();
      final slots = await make(scheduler).run(now);
      expect(slots, hasLength(34));
      expect(scheduler.syncs.single, slots);
    });

    test('no location yet: what is pending stays', () async {
      await AdhanSettingsRepository()
          .saveSettings(const AdhanSettings(enabled: true));
      final scheduler = RecordingScheduler();
      expect(await make(scheduler).run(now), isNull);
      expect(scheduler.syncs, isEmpty);
    });

    test('off: clears everything', () async {
      final scheduler = RecordingScheduler();
      expect(await make(scheduler).run(now), isEmpty);
      expect(scheduler.syncs.single, isEmpty);
    });
  });

  test('phone makers', () {
    expect(AdhanReliability.makerOf('Xiaomi'), PhoneMaker.xiaomi);
    expect(AdhanReliability.makerOf('realme'), PhoneMaker.oppo);
    expect(AdhanReliability.makerOf('OnePlus'), PhoneMaker.oppo);
    expect(AdhanReliability.makerOf('HUAWEI'), PhoneMaker.huawei);
    expect(AdhanReliability.makerOf('samsung'), PhoneMaker.samsung);
    expect(AdhanReliability.makerOf('Google'), PhoneMaker.other);
  });
}
