import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/core/notifications/local_notifications.dart';
import 'package:lahuma/features/adhan/domain/adhan_plan.dart';
import 'package:lahuma/features/fajr_call/data/fajr_notifications.dart';
import 'package:lahuma/features/khatma/data/khatma_notifications.dart';
import 'package:lahuma/features/khatma/domain/khatma.dart';
import 'package:lahuma/features/khatma/domain/khatma_planner.dart';
import 'package:lahuma/features/khatma/domain/khatma_reminders.dart';
import 'package:lahuma/features/khatma/domain/khatma_text.dart';
import 'package:lahuma/features/reminders/domain/reminder_plan.dart';
import 'package:lahuma/features/khatma/domain/quran_pages.dart';
import 'package:lahuma/features/khatma/presentation/khatma_providers.dart';
import 'package:lahuma/features/quran/mushaf/domain/mushaf_meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

final day1 = DateTime(2026, 11, 1);

/// A 30-day khatma from the beginning, started on [day1] (ends 30 Nov).
Khatma thirtyDays({int startPage = 1}) => KhatmaPlanner.create(
      id: 'k1',
      today: day1,
      endDate: KhatmaPlanner.endDateFor(day1, 30),
      startPage: startPage,
    );

DateTime nov(int day, [int hour = 0]) => DateTime(2026, 11, day, hour);

void main() {
  group('daily target', () {
    test('normal: 604 pages over 30 days is 21 a day', () {
      final k = thirtyDays();
      expect(k.endDate, nov(30));
      expect(KhatmaPlanner.remainingDays(k.endDate, day1), 30);
      expect(k.today!.startPage, 0);
      expect(k.today!.targetPage, 21);
      expect(KhatmaPlanner.todayRemaining(k, day1), 21);
      expect(KhatmaPlanner.pace(k, day1), KhatmaPace.onTrack);
    });

    test('behind: five missed days raise the target', () {
      final k = thirtyDays();
      final today = nov(6);
      // 604 pages over the 25 days left.
      expect(KhatmaPlanner.dayPlan(k, today).targetPage, 25);
      expect(KhatmaPlanner.pace(k, today), KhatmaPace.behind);
    });

    test('ahead: reading more lowers the next targets', () {
      var k = KhatmaPlanner.reachPage(thirtyDays(), 100, day1);
      expect(KhatmaPlanner.todayDone(k, day1), isTrue);
      final tomorrow = nov(2);
      k = KhatmaPlanner.startDay(k, tomorrow);
      // 504 pages over 29 days.
      expect(k.today!.pages, 18);
      expect(KhatmaPlanner.pace(k, tomorrow), KhatmaPace.ahead);
    });

    test('on track after exactly the day\'s portion', () {
      var k = KhatmaPlanner.reachPage(thirtyDays(), 21, day1);
      k = KhatmaPlanner.startDay(k, nov(2));
      expect(KhatmaPlanner.pace(k, nov(2)), KhatmaPace.onTrack);
    });

    test('today\'s target is fixed while reading', () {
      var k = KhatmaPlanner.reachPage(thirtyDays(), 10, day1);
      expect(k.today!.targetPage, 21);
      expect(KhatmaPlanner.todayRemaining(k, day1), 11);
      expect(KhatmaPlanner.readToday(k, day1), 10);
      k = KhatmaPlanner.reachPage(k, 30, day1);
      expect(k.today!.targetPage, 21);
      expect(KhatmaPlanner.todayRemaining(k, day1), 0);
    });

    test('overdue: everything left becomes the target', () {
      var k = KhatmaPlanner.reachPage(thirtyDays(), 500, day1);
      final today = DateTime(2026, 12, 2);
      expect(KhatmaPlanner.remainingDays(k.endDate, today), 0);
      expect(KhatmaPlanner.isOverdue(k, today), isTrue);
      expect(KhatmaPlanner.pace(k, today), KhatmaPace.overdue);
      k = KhatmaPlanner.startDay(k, today);
      expect(k.today!.targetPage, 604);
    });

    test('extending an overdue khatma spreads what is left', () {
      final k = KhatmaPlanner.reachPage(thirtyDays(), 504, day1);
      final today = DateTime(2026, 12, 2);
      final extended = KhatmaPlanner.extend(k, 10, today);
      expect(extended.endDate, DateTime(2026, 12, 11));
      expect(KhatmaPlanner.isOverdue(extended, today), isFalse);
      expect(extended.today!.pages, 10);
    });

    test('last day: the target is the rest of the Quran', () {
      final k = KhatmaPlanner.reachPage(thirtyDays(), 580, day1);
      final plan = KhatmaPlanner.dayPlan(k, nov(30));
      expect(plan.targetPage, 604);
      expect(plan.pages, 24);
    });

    test('the target never passes page 604', () {
      final k = KhatmaPlanner.reachPage(thirtyDays(), 603, day1);
      expect(
          KhatmaPlanner.dailyTarget(
              lastPageRead: 603, endDate: k.endDate, today: nov(2)),
          1);
      expect(KhatmaPlanner.dayPlan(k, nov(2)).targetPage, 604);
    });

    test('finished early: nothing left', () {
      final k = KhatmaPlanner.reachPage(thirtyDays(), 604, day1);
      expect(k.finished, isTrue);
      expect(
          KhatmaPlanner.dailyTarget(
              lastPageRead: 604, endDate: k.endDate, today: nov(5)),
          0);
      final done = KhatmaPlanner.complete(k, nov(5, 9));
      expect(done.status, KhatmaStatus.completed);
      expect(KhatmaPlanner.daysTaken(done, nov(20)), 5);
      expect(KhatmaPlanner.averagePerDay(done, nov(20)), closeTo(120.8, 0.01));
    });

    test('starting partway counts only the pages left', () {
      final k = thirtyDays(startPage: 302);
      expect(k.lastPageRead, 301);
      expect(k.pagesToRead, 303);
      expect(k.today!.pages, 11); // ceil(303 / 30)
    });

    test('a day boundary is a calendar day, not 24 hours', () {
      // Across the end of daylight saving time (25-hour day in many zones).
      expect(
          daysBetween(DateTime(2026, 10, 24, 23), DateTime(2026, 10, 26)), 2);
      expect(addDays(DateTime(2026, 3, 28), 2), DateTime(2026, 3, 30));
    });
  });

  group('corrections', () {
    test('lowering within the day keeps the day\'s plan', () {
      var k = KhatmaPlanner.reachPage(thirtyDays(), 15, day1);
      k = KhatmaPlanner.reachPage(k, 12, day1);
      expect(k.lastPageRead, 12);
      expect(k.today!.targetPage, 21);
    });

    test('lowering below where the day began plans the day again', () {
      var k = KhatmaPlanner.reachPage(thirtyDays(), 100, day1);
      k = KhatmaPlanner.startDay(k, nov(2));
      expect(k.today!.startPage, 100);
      k = KhatmaPlanner.reachPage(k, 90, nov(2));
      expect(k.today!.startPage, 90);
      expect(k.today!.targetPage, 90 + 18); // ceil(514 / 29)
    });

    test('a page below the khatma\'s start is not allowed', () {
      final k = KhatmaPlanner.reachPage(thirtyDays(startPage: 302), 5, day1);
      expect(k.lastPageRead, 301);
    });

    test('the log extends forward and trims back', () {
      var logs = KhatmaPlanner.logProgress(const [],
          khatmaId: 'k1', today: day1, from: 0, to: 15);
      logs = KhatmaPlanner.logProgress(logs,
          khatmaId: 'k1', today: day1, from: 15, to: 21);
      expect(logs.single.fromPage, 1);
      expect(logs.single.toPage, 21);

      logs = KhatmaPlanner.logProgress(logs,
          khatmaId: 'k1', today: nov(2), from: 21, to: 40);
      expect(logs.length, 2);

      // Back to 18: today's entry goes, yesterday's is trimmed.
      logs = KhatmaPlanner.logProgress(logs,
          khatmaId: 'k1', today: nov(2), from: 40, to: 18);
      expect(logs.single.toPage, 18);
      expect(logs.single.pages, 18);
    });
  });

  group('editing mid-khatma', () {
    test('today\'s pages still count towards the new plan', () {
      var k = KhatmaPlanner.reachPage(thirtyDays(), 15, day1);
      k = KhatmaPlanner.reschedule(k, nov(10), day1);
      expect(k.endDate, nov(10));
      expect(k.today!.startPage, 0);
      expect(k.today!.targetPage, 61); // ceil(604 / 10)
      expect(KhatmaPlanner.readToday(k, day1), 15);
      expect(KhatmaPlanner.todayRemaining(k, day1), 46);
      expect(k.planFrom, day1);
      expect(k.planFromPage, 0);
    });

    test('pausing moves the end date by the days paused', () {
      var k = KhatmaPlanner.pause(thirtyDays(), nov(5));
      expect(k.status, KhatmaStatus.paused);
      expect(k.today, isNull);
      k = KhatmaPlanner.resume(k, nov(8));
      expect(k.status, KhatmaStatus.active);
      expect(k.endDate, DateTime(2026, 12, 3));
      expect(k.pausedOn, isNull);
      expect(k.today!.date, nov(8));
    });
  });

  group('hizb data', () {
    test('a page opens with the first words of its first ayah', () {
      // The Basmala is four words: shown whole.
      expect(QuranPages.openingWords(1), MushafMeta.ayahText(1, 1).trim());
      // Page 2 opens on Al-Baqarah 1–5: "الٓمٓ" alone is the whole ayah.
      expect(QuranPages.openingWords(2), isNot(contains('…')));
      final long = QuranPages.openingWords(129, words: 3);
      expect(long.split(' ').length, 4); // three words and the ellipsis
      expect(long, endsWith('…'));
    });

    test('hizb start pages match the Madinah Mushaf', () {
      // Checked against the printed 604-page Madinah Mushaf.
      const known = {
        1: 1, // al-Fatiha 1
        2: 11, // al-Baqarah 75
        3: 22, // al-Baqarah 142
        5: 42, // al-Baqarah 253
        41: 402, // al-'Ankabut 46
        57: 562, // al-Mulk 1
        59: 582, // an-Naba' 1
        60: 591, // al-A'la 1
      };
      known.forEach((hizb, page) {
        expect(QuranPages.hizbStartPage(hizb), page, reason: 'hizb $hizb');
      });
    });

    test('every odd hizb opens a juz\'', () {
      for (var juz = 1; juz <= 30; juz++) {
        expect(
            QuranPages.hizbStartPage(juz * 2 - 1), MushafMeta.juzStartPage(juz),
            reason: 'juz $juz');
      }
    });

    test('pages map to ahzab and one more hizb moves to its end', () {
      expect(QuranPages.hizbAt(1), 1);
      expect(QuranPages.hizbAt(11), 2);
      expect(QuranPages.hizbAt(604), 60);
      expect(KhatmaPlanner.afterOneHizb(0), 10);
      expect(KhatmaPlanner.afterOneHizb(10), 21);
      expect(KhatmaPlanner.afterOneHizb(600), 604);
    });
  });

  group('reminders', () {
    final k = Khatma(
      id: 'k1',
      startDate: day1,
      endDate: nov(30),
      startPage: 1,
      lastPageRead: 0,
      planFrom: day1,
      planFromPage: 0,
      eveningEnabled: true,
    );

    test('iOS budgets of adhan, reminders, Fajr Call and khatma fill 64',
        () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(
          AdhanPlanner.iosBudget +
              ReminderPlanner.iosBudget +
              FajrNotifications.maxPending +
              KhatmaReminderPlan.iosBudget,
          64);
    });

    test('iOS: the next 3 mornings and this evening', () {
      final r = KhatmaReminderPlan.plan(k, nov(1, 8), ios: true);
      expect(r.length, KhatmaReminderPlan.iosBudget);
      expect(r.first.kind, KhatmaReminderKind.evening);
      expect(r.first.at, DateTime(2026, 11, 1, 21));
      expect(r.first.pages, 21);
      expect([for (final x in r.skip(1)) x.at.day], [2, 3, 4]);
      expect(
          r.skip(1).every((x) => x.kind == KhatmaReminderKind.morning), isTrue);
    });

    test('iOS before the morning reminder: today counts as one of 3', () {
      final r = KhatmaReminderPlan.plan(k, nov(1, 6), ios: true);
      expect(r.length, 4);
      expect([for (final x in r) '${x.at.day}:${x.kind.name}'],
          ['1:morning', '1:evening', '2:morning', '3:morning']);
    });

    test('Android: a week of mornings and evenings', () {
      final r = KhatmaReminderPlan.plan(k, nov(1, 8), ios: false);
      expect(r.length, 1 + 6 * 2);
      expect(r.map((x) => x.id).toSet().length, r.length);
      expect(r.every((x) => KhatmaReminderPlan.isKhatmaId(x.id)), isTrue);
    });

    test('nothing for today once its portion is read', () {
      final done = KhatmaPlanner.reachPage(k, 21, day1);
      final r = KhatmaReminderPlan.plan(done, nov(1, 8), ios: true);
      expect(r.any((x) => x.at.day == 1), isFalse);
    });

    test('partly read: today\'s reminders carry what is left', () {
      final part = KhatmaPlanner.reachPage(k, 13, day1);
      final evening = KhatmaReminderPlan.plan(part, nov(1, 8), ios: true).first;
      expect(evening.partial, isTrue);
      expect(evening.pages, 8);
      expect(KhatmaNotifications.body(evening, arabic: true),
          'بقي لك اليوم 8 صفحات لإتمام وردك (حتى صفحة 21)');
    });

    test('future days assume nothing more is read', () {
      final r = KhatmaReminderPlan.plan(k, nov(1, 22), ios: true);
      // Tomorrow: 604 pages over the 29 days left.
      expect(r.first.at.day, 2);
      expect(r.first.pages, 21);
      expect(r.first.partial, isFalse);
    });

    test('paused, finished or silent khatmas have none', () {
      expect(
          KhatmaReminderPlan.plan(KhatmaPlanner.pause(k, day1), nov(1, 6),
              ios: false),
          isEmpty);
      expect(
          KhatmaReminderPlan.plan(
              KhatmaPlanner.reachPage(k, 604, day1), nov(1, 6),
              ios: false),
          isEmpty);
      expect(
          KhatmaReminderPlan.plan(
              k.copyWith(morningEnabled: false, eveningEnabled: false),
              nov(1, 6),
              ios: false),
          isEmpty);
    });

    test('the morning text names the range and its surah', () {
      final r = KhatmaReminder(
        id: KhatmaReminderPlan.minId,
        at: nov(1, 7),
        kind: KhatmaReminderKind.morning,
        fromPage: 142,
        toPage: 161,
        partial: false,
      );
      final body = KhatmaNotifications.body(r, arabic: true);
      expect(body, startsWith('وردك اليوم: 20 صفحة — من صفحة 142 ('));
      expect(body, endsWith(') إلى 161'));
      expect(KhatmaNotifications.body(r, arabic: false),
          startsWith("Today's portion: 20 pages — page 142 ("));
    });
  });

  group('wording', () {
    test('Arabic page counts agree with the number', () {
      String p(int n) => KhatmaText.pages(n, arabic: true);
      expect(p(1), 'صفحة واحدة');
      expect(p(2), 'صفحتان');
      expect(p(8), '8 صفحات');
      expect(p(20), '20 صفحة');
      expect(p(103), '103 صفحات');
    });

    test('amounts in juz\' and ahzab round to a quarter', () {
      expect(KhatmaText.amount(20, ReadingUnit.juz, arabic: true), 'جزء واحد');
      expect(KhatmaText.amount(30, ReadingUnit.juz, arabic: true), 'جزء ونصف');
      expect(KhatmaText.amount(30, ReadingUnit.juz, arabic: false), '1½ juz');
      expect(KhatmaText.amount(10, ReadingUnit.hizb, arabic: true), 'حزب واحد');
      expect(KhatmaText.amount(61, ReadingUnit.hizb, arabic: true), '6 أحزاب');
      expect(KhatmaText.amount(2, ReadingUnit.juz, arabic: true),
          'أقل من ربع جزء');
    });
  });

  group('notifier', () {
    late DateTime now;
    late _RecordingNotifications notifications;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      now = nov(1, 8);
      notifications = _RecordingNotifications();
      container = ProviderContainer(overrides: [
        khatmaClockProvider.overrideWithValue(() => now),
        khatmaNotificationsProvider.overrideWithValue(notifications),
      ]);
      addTearDown(container.dispose);
    });

    KhatmaNotifier notifier() => container.read(khatmaProvider.notifier);
    KhatmaState state() => container.read(khatmaProvider);

    Future<void> start() async {
      await notifier().ready;
      await notifier().create(
        endDate: nov(30),
        startPage: 1,
        displayUnit: ReadingUnit.pages,
        morningEnabled: true,
        morningMinutes: 7 * 60,
        eveningEnabled: false,
        eveningMinutes: 21 * 60,
      );
    }

    test('mark today done reaches the target and logs it', () async {
      await start();
      expect(await notifier().markTodayDone(), KhatmaProgress.saved);
      expect(state().active!.lastPageRead, 21);
      expect(state().logs.single.pages, 21);
      expect(notifications.synced.last?.lastPageRead, 21);
    });

    test('undo takes back the last update and its log', () async {
      await start();
      await notifier().addPages(5);
      await notifier().addHizb();
      expect(state().active!.lastPageRead, 10);
      expect(state().canUndo, isTrue);
      expect(await notifier().undo(), isTrue);
      expect(state().active!.lastPageRead, 5);
      expect(state().logs.single.toPage, 5);
      expect(state().canUndo, isFalse);
      expect(await notifier().undo(), isFalse);
    });

    test('lowering the page corrects the log', () async {
      await start();
      await notifier().reachPage(30);
      expect(await notifier().reachPage(12), KhatmaProgress.saved);
      expect(state().active!.lastPageRead, 12);
      expect(state().logs.single.toPage, 12);
    });

    test('editing the end date keeps today\'s pages and log', () async {
      await start();
      await notifier().reachPage(15);
      await notifier().edit(
        endDate: nov(10),
        displayUnit: ReadingUnit.juz,
        morningEnabled: true,
        morningMinutes: 6 * 60,
        eveningEnabled: true,
        eveningMinutes: 20 * 60,
      );
      final k = state().active!;
      expect(k.lastPageRead, 15);
      expect(KhatmaPlanner.todayRemaining(k, day1), 46);
      expect(state().logs.single.toPage, 15);
      expect(k.displayUnit, ReadingUnit.juz);
    });

    test('reaching 604 completes, cancels reminders and can be undone',
        () async {
      await start();
      expect(await notifier().reachPage(604), KhatmaProgress.completed);
      expect(state().active, isNull);
      expect(state().history.single.status, KhatmaStatus.completed);
      expect(notifications.synced.last, isNull);

      await notifier().undo();
      expect(state().active!.lastPageRead, 0);
      expect(state().history, isEmpty);
    });

    test('a new day fixes a new portion and survives a restart', () async {
      await start();
      await notifier().reachPage(21);
      now = nov(2, 8);
      await notifier().refresh();
      expect(state().active!.today!.date, nov(2));
      expect(state().active!.today!.startPage, 21);

      final again = ProviderContainer(overrides: [
        khatmaClockProvider.overrideWithValue(() => now),
        khatmaNotificationsProvider.overrideWithValue(notifications),
      ]);
      addTearDown(again.dispose);
      await again.read(khatmaProvider.notifier).ready;
      expect(again.read(khatmaProvider).active!.lastPageRead, 21);
      expect(again.read(khatmaProvider).logs.single.pages, 21);
    });

    test('pause and delete clear the reminders', () async {
      await start();
      await notifier().pause();
      expect(notifications.synced.last?.status, KhatmaStatus.paused);
      expect(await notifier().reachPage(40), KhatmaProgress.unchanged);
      await notifier().delete();
      expect(state().active, isNull);
      expect(notifications.synced.last, isNull);
    });
  });
}

class _RecordingNotifications extends KhatmaNotifications {
  _RecordingNotifications() : super(LocalNotifications());

  final List<Khatma?> synced = [];

  @override
  Future<void> sync(Khatma? khatma,
      {required DateTime now, required bool arabic}) async {
    synced.add(khatma);
  }
}
