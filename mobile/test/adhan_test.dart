import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/core/notifications/local_notifications.dart';
import 'package:lahuma/features/adhan/data/adhan_audio_store.dart';
import 'package:lahuma/features/adhan/data/adhan_scheduler.dart';
import 'package:lahuma/features/adhan/data/adhan_settings_repository.dart';
import 'package:lahuma/features/adhan/data/muezzin_repository.dart';
import 'package:lahuma/features/adhan/domain/adhan_plan.dart';
import 'package:lahuma/features/adhan/domain/adhan_settings.dart';
import 'package:lahuma/features/adhan/domain/muezzin.dart';
import 'package:lahuma/features/adhan/presentation/adhan_cleared_notice.dart';
import 'package:lahuma/features/adhan/presentation/adhan_foreground.dart';
import 'package:lahuma/features/adhan/presentation/adhan_providers.dart';
import 'package:lahuma/features/prayer_times/domain/prayer_times.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Muezzin muezzin({String id = 'm1', int version = 1}) => Muezzin(
      id: id,
      nameAr: 'مؤذن',
      nameFr: 'Muezzin',
      country: 'DZ',
      regularUrl: 'https://cdn/r.mp3',
      fajrUrl: 'https://cdn/f.mp3',
      regularShortUrl: 'https://cdn/r.caf',
      fajrShortUrl: 'https://cdn/f.caf',
      version: version,
    );

class FakeMuezzins extends MuezzinRepository {
  List<Muezzin> list = [];
  bool fail = false;

  @override
  Future<List<Muezzin>> cached() async => const [];

  @override
  Future<List<Muezzin>> refresh() async {
    if (fail) throw Exception('offline');
    return list;
  }
}

class FakeStore extends AdhanAudioStore {
  FakeStore() : super(ios: false);
  bool fail = false;
  final downloads = <String>[];
  AdhanDownload? kept;

  @override
  Future<AdhanDownload> download(Muezzin m,
      {void Function(double progress)? onProgress}) async {
    downloads.add('${m.id}@${m.version}');
    onProgress?.call(0.5);
    if (fail) throw const AdhanDownloadException('offline');
    return AdhanDownload(
      muezzinId: m.id,
      version: m.version,
      files: {AdhanSoundKind.regular: '/r', AdhanSoundKind.fajr: '/f'},
      androidUris: {
        AdhanSoundKind.regular: 'content://r',
        AdhanSoundKind.fajr: 'content://f',
      },
    );
  }

  @override
  Future<AdhanDownload> republish(AdhanDownload d) async => d;

  @override
  bool isComplete(AdhanDownload d) => true;

  @override
  Future<void> deleteExcept(AdhanDownload? keep) async => kept = keep;
}

class FakeScheduler extends AdhanScheduler {
  FakeScheduler() : super(LocalNotifications());
  final syncs = <({List<AdhanSlot> slots, String? muezzinName})>[];

  @override
  Future<bool> sync(List<AdhanSlot> slots,
      {required String? muezzinName,
      required bool arabic,
      AdhanDownload? download}) async {
    syncs.add((slots: slots, muezzinName: muezzinName));
    return false;
  }
}

void main() {
  final now = DateTime(2026, 10, 29, 10); // after Fajr, before Dhuhr

  group('AdhanPlanner', () {
    test('off schedules nothing', () {
      expect(
          AdhanPlanner.plan(
              days: week(now),
              settings: const AdhanSettings(),
              now: now,
              ios: false),
          isEmpty);
    });

    test('a week of the enabled prayers, future only, in order', () {
      final slots = AdhanPlanner.plan(
        days: week(now),
        settings: const AdhanSettings(enabled: true),
        now: now,
        ios: false,
      );
      // Today's Fajr has passed: 4 today + 6 days × 5.
      expect(slots.length, 34);
      expect(slots.first.prayer, PrayerKind.dhuhr);
      expect(slots.every((s) => s.at.isAfter(now)), isTrue);
      for (var i = 1; i < slots.length; i++) {
        expect(slots[i].at.isAfter(slots[i - 1].at), isTrue);
      }
    });

    test('disabled prayers are skipped', () {
      final slots = AdhanPlanner.plan(
        days: week(now),
        settings:
            const AdhanSettings(enabled: true, prayers: {PrayerKind.fajr}),
        now: now,
        ios: false,
      );
      expect(slots.length, 6);
      expect(slots.every((s) => s.prayer == PrayerKind.fajr), isTrue);
    });

    test('ids are stable, distinct and outside Fajr Call\'s range', () {
      final a = AdhanPlanner.plan(
          days: week(now),
          settings: const AdhanSettings(enabled: true, reminderMinutes: 10),
          now: now,
          ios: false);
      final b = AdhanPlanner.plan(
          days: week(now),
          settings: const AdhanSettings(enabled: true, reminderMinutes: 10),
          now: now.add(const Duration(minutes: 1)),
          ios: false);
      expect(a.map((s) => s.id), b.map((s) => s.id));
      expect(a.map((s) => s.id).toSet().length, a.length);
      expect(a.every((s) => AdhanPlanner.isAdhanId(s.id)), isTrue);
      expect(AdhanPlanner.idFor(DateTime(2026, 10, 29), PrayerKind.isha),
          202610294);
      expect(
          AdhanPlanner.idFor(DateTime(2026, 10, 29), PrayerKind.fajr,
              reminder: true),
          202610295);
      expect(AdhanPlanner.isAdhanId(15999999), isFalse);
    });

    test('Android: reminders every day before each adhan', () {
      final slots = AdhanPlanner.plan(
        days: week(now),
        settings: const AdhanSettings(enabled: true, reminderMinutes: 10),
        now: now,
        ios: false,
      );
      final reminders = slots.where((s) => s.reminder).toList();
      expect(reminders.length, 34);
      final dhuhr = reminders.first;
      expect(dhuhr.prayer, PrayerKind.dhuhr);
      expect(dhuhr.at, DateTime(2026, 10, 29, 12, 35));
      expect(dhuhr.leadMinutes, 10);
    });

    test('iOS: reminders for two days only, never over the budget', () {
      final slots = AdhanPlanner.plan(
        days: week(DateTime(2026, 10, 29)),
        settings: const AdhanSettings(enabled: true, reminderMinutes: 15),
        now: DateTime(2026, 10, 29, 1),
        ios: true,
      );
      expect(slots.where((s) => !s.reminder).length, 35);
      expect(slots.where((s) => s.reminder).length, 10);
      expect(slots.length, lessThanOrEqualTo(AdhanPlanner.iosBudget));
      expect(
          slots
              .where((s) => s.reminder)
              .every((s) => s.at.isBefore(DateTime(2026, 10, 31))),
          isTrue);
    });
  });

  group('AdhanScheduler', () {
    test('adhan notifications are silent; the app plays the adhan', () {
      const c = AdhanScheduler.adhanChannel;
      expect(c.silent, isTrue);
      expect(c.sound, isNull);
      expect(c.alarm, isFalse);
      expect(c.timeSensitive, isTrue);
      expect(c.id.startsWith(AdhanScheduler.channelPrefix), isTrue);
      expect(AdhanScheduler.reminderChannel.silent, isFalse);
    });

    test('reminder text agrees in number', () {
      expect(AdhanScheduler.reminderBody(5, true), 'بعد 5 دقائق');
      expect(AdhanScheduler.reminderBody(15, true), 'بعد 15 دقيقة');
      expect(AdhanScheduler.adhanBody(PrayerKind.fajr, 'x', true),
          'الصلاة خير من النوم');
    });
  });

  test('settings survive a round trip', () {
    const s = AdhanSettings(
      enabled: true,
      muezzinId: 'm1',
      prayers: {PrayerKind.fajr, PrayerKind.isha},
      reminderMinutes: 10,
    );
    expect(AdhanSettings.fromJson(s.toJson()), s);
    expect(AdhanSettings.fromJson({'reminderMinutes': 7}).reminderMinutes, 0);
  });

  test('sound names are unique per muezzin, kind and version', () {
    final a = AdhanAudioStore.soundName(
        muezzin(id: '0000-1111-2222-3333'), AdhanSoundKind.fajr, '.mp3');
    final b = AdhanAudioStore.soundName(
        muezzin(id: '0000-1111-2222-3333', version: 2),
        AdhanSoundKind.fajr,
        '.mp3');
    expect(a, 'adhan_000011112222_fajr_v1.mp3');
    expect(a, isNot(b));
  });

  group('AdhanNotifier', () {
    late FakeMuezzins muezzins;
    late FakeStore store;
    late FakeScheduler scheduler;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      muezzins = FakeMuezzins();
      store = FakeStore();
      scheduler = FakeScheduler();
    });

    AdhanNotifier make() => AdhanNotifier(
          muezzins: muezzins,
          repository: AdhanSettingsRepository(),
          store: store,
          scheduler: scheduler,
          days: () => week(now),
          arabic: () => true,
          now: () => now,
          ios: false,
          autoLoad: false,
        );

    test('selecting downloads, persists, cleans up and reschedules', () async {
      muezzins.list = [muezzin()];
      final n = make();
      await n.load();
      await n.setEnabled(true);
      expect(await n.select(muezzin()), isTrue);

      expect(n.state.settings.muezzinId, 'm1');
      expect(n.state.download!.version, 1);
      expect(store.kept!.muezzinId, 'm1');
      expect(scheduler.syncs.last.slots, isNotEmpty);

      final reloaded = make();
      await reloaded.load();
      expect(reloaded.state.settings.muezzinId, 'm1');
      expect(reloaded.state.download!.muezzinId, 'm1');
    });

    test('a failed download keeps the previous choice', () async {
      muezzins.list = [muezzin()];
      final n = make();
      await n.load();
      store.fail = true;
      expect(await n.select(muezzin()), isFalse);
      expect(n.state.settings.muezzinId, isNull);
      expect(n.state.download, isNull);
      expect(n.state.failedId, 'm1');
    });

    test('a new version on the server is downloaded again', () async {
      muezzins.list = [muezzin()];
      final n = make();
      await n.load();
      await n.select(muezzin());
      muezzins.list = [muezzin(version: 2)];
      await n.refreshList();
      expect(store.downloads, ['m1@1', 'm1@2']);
      expect(n.state.download!.version, 2);
    });

    test('back to the default deletes the downloads', () async {
      muezzins.list = [muezzin()];
      final n = make();
      await n.load();
      await n.select(muezzin());
      await n.useDefault();
      expect(n.state.settings.muezzinId, isNull);
      expect(n.state.download, isNull);
      expect(store.kept, isNull);
    });

    test('settings changes reschedule', () async {
      final n = make();
      await n.load();
      final before = scheduler.syncs.length;
      await n.setEnabled(true);
      await n.setPrayer(PrayerKind.asr, false);
      await n.setReminder(10);
      expect(scheduler.syncs.length, before + 3);
      final last = scheduler.syncs.last.slots;
      expect(last.any((s) => s.prayer == PrayerKind.asr), isFalse);
      expect(last.any((s) => s.reminder), isTrue);
    });

    test('no prayer times yet keeps the pending adhans', () async {
      var days = <DayPrayerTimes>[];
      final n = AdhanNotifier(
        muezzins: muezzins,
        repository: AdhanSettingsRepository(),
        store: store,
        scheduler: scheduler,
        days: () => days,
        arabic: () => true,
        now: () => now,
        ios: false,
        autoLoad: false,
      );
      await n.load();
      final before = scheduler.syncs.length;
      await n.setEnabled(true);
      expect(scheduler.syncs.length, before);

      days = week(now);
      await n.reschedule();
      expect(scheduler.syncs.length, before + 1);
      expect(scheduler.syncs.last.slots, isNotEmpty);

      // Turning it off still cancels everything, times or not.
      days = [];
      await n.setEnabled(false);
      expect(scheduler.syncs.last.slots, isEmpty);
    });
  });

  group('AdhanForeground', () {
    // A clock the test moves, and the timers it would have armed.
    late DateTime clock;
    late List<({Duration after, void Function() fire})> timers;
    late List<AdhanSlot> played;
    late int? saved;
    late AdhanSettings settings;

    setUp(() {
      clock = now;
      timers = [];
      played = [];
      saved = null;
      settings = const AdhanSettings(enabled: true);
    });

    AdhanForeground make({int? lastPlayed}) => AdhanForeground(
          adhans: (from) => [
            for (final s in AdhanPlanner.plan(
                days: week(now), settings: settings, now: from, ios: false))
              if (!s.reminder) s,
          ],
          now: () => clock,
          onAdhan: played.add,
          loadLastPlayed: () async => lastPlayed,
          saveLastPlayed: (id) async => saved = id,
          timer: (after, fire) {
            timers.add((after: after, fire: fire));
            return Timer(const Duration(days: 365), () {});
          },
        );

    /// Moves the clock to the last armed timer and fires it.
    Future<void> fireNext() async {
      final t = timers.last;
      clock = clock.add(t.after);
      t.fire();
      await pumpEventQueue();
    }

    test('plays each of the five prayers at its time, once', () async {
      final fg = make();
      fg.setActive(true);
      await pumpEventQueue();
      // 10:00 → Dhuhr 12:45, then Asr, Maghrib, Isha, tomorrow's Fajr.
      expect(timers.last.after, const Duration(hours: 2, minutes: 45));
      for (var i = 0; i < 5; i++) {
        await fireNext();
      }
      expect(played.map((s) => s.prayer), [
        PrayerKind.dhuhr,
        PrayerKind.asr,
        PrayerKind.maghrib,
        PrayerKind.isha,
        PrayerKind.fajr,
      ]);
      expect(played.last.at, DateTime(2026, 10, 30, 5, 30));
      expect(saved, played.last.id);

      // Coming back, or a refresh, doesn't play it again.
      fg.setActive(false);
      fg.setActive(true);
      await fg.refresh();
      expect(played, hasLength(5));
    });

    test('nothing plays in the background', () async {
      final fg = make();
      fg.setActive(true);
      await pumpEventQueue();
      fg.setActive(false);
      clock = DateTime(2026, 10, 29, 12, 50); // Dhuhr was 5 minutes ago
      fg.setActive(true);
      await pumpEventQueue();
      expect(played, isEmpty);
      // The timer now points at Asr.
      expect(timers.last.after, const Duration(hours: 3));
    });

    test('back within the grace minute still plays it', () async {
      final fg = make();
      clock = DateTime(2026, 10, 29, 12, 45, 30);
      fg.setActive(true);
      await pumpEventQueue();
      expect(played.single.prayer, PrayerKind.dhuhr);
    });

    test('an adhan already played (another launch) is skipped', () async {
      final dhuhr = AdhanPlanner.idFor(now, PrayerKind.dhuhr);
      final fg = make(lastPlayed: dhuhr);
      clock = DateTime(2026, 10, 29, 12, 45, 10);
      fg.setActive(true);
      await pumpEventQueue();
      expect(played, isEmpty);
    });

    test('respects the enabled prayers and the master switch', () async {
      settings = AdhanSettings(
          enabled: true, prayers: {...adhanPrayers}..remove(PrayerKind.dhuhr));
      final fg = make();
      fg.setActive(true);
      await pumpEventQueue();
      await fireNext();
      expect(played.single.prayer, PrayerKind.asr);

      settings = const AdhanSettings();
      timers.clear();
      await fg.refresh();
      expect(timers, isEmpty);
    });

    test('the test adhan plays in 10 seconds, only while open', () async {
      final fg = make();
      fg.setActive(true);
      await pumpEventQueue();
      fg.test(PrayerKind.maghrib);
      await pumpEventQueue();
      expect(timers.last.after, AdhanForeground.testDelay);
      await fireNext();
      expect(played.single.prayer, PrayerKind.maghrib);
      expect(played.single.id, AdhanForeground.testIdFor(PrayerKind.maghrib));
      // A test doesn't count as the real Maghrib.
      expect(saved ?? 0, lessThan(AdhanPlanner.minId));

      fg.test(PrayerKind.isha);
      fg.setActive(false);
      clock = clock.add(const Duration(seconds: 10));
      fg.setActive(true);
      await pumpEventQueue();
      expect(played, hasLength(1));
    });

    test('test ids stay out of the planner range', () {
      for (final p in adhanPrayers) {
        expect(AdhanPlanner.isAdhanId(AdhanForeground.testIdFor(p)), isFalse);
      }
    });
  });

  test('adhansFrom: the allowed adhans only, no reminders', () async {
    SharedPreferences.setMockInitialValues({});
    final n = AdhanNotifier(
      muezzins: FakeMuezzins(),
      repository: AdhanSettingsRepository(),
      store: FakeStore(),
      scheduler: FakeScheduler(),
      days: () => week(now),
      arabic: () => true,
      now: () => now,
      ios: true,
      autoLoad: false,
    );
    expect(n.adhansFrom(now), isEmpty); // not loaded
    await n.load();
    expect(n.adhansFrom(now), isEmpty); // off
    await n.setEnabled(true);
    await n.setReminder(10);
    final slots = n.adhansFrom(now);
    expect(slots.any((s) => s.reminder), isFalse);
    // Not capped by the iOS notification budget.
    expect(slots.length, 34);
  });

  test('the "adhans were cancelled" notice waits 3 days between showings', () {
    final now = DateTime(2026, 11, 4, 16);
    expect(shouldShowAdhanClearedNotice(null, now), isTrue);
    expect(
        shouldShowAdhanClearedNotice(
            now.subtract(const Duration(days: 2, hours: 23)), now),
        isFalse);
    expect(
        shouldShowAdhanClearedNotice(
            now.subtract(const Duration(days: 3)), now),
        isTrue);
  });
}
