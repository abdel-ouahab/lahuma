import 'dart:math' as math;
import 'khatma.dart';
import 'quran_pages.dart';

/// How the reader stands against the plan's pace line.
enum KhatmaPace { onTrack, behind, ahead, overdue }

/// The khatma arithmetic: daily targets, today's portion, pace, and every
/// change to the plan. Pure — the caller passes `today` (a local calendar
/// day), so it never reads the clock and is unit-tested in isolation.
class KhatmaPlanner {
  KhatmaPlanner._();

  static const int totalPages = QuranPages.total;

  static int remainingPages(int lastPageRead) =>
      math.max(0, totalPages - lastPageRead);

  /// Days left to read, counting today; 0 once the end date has passed.
  static int remainingDays(DateTime endDate, DateTime today) =>
      math.max(0, daysBetween(today, endDate) + 1);

  static bool isOverdue(Khatma k, DateTime today) =>
      !k.finished && daysBetween(k.endDate, today) > 0;

  /// Pages to read per day from [today] to finish by [endDate]. Past the
  /// end date, everything that is left.
  static int dailyTarget({
    required int lastPageRead,
    required DateTime endDate,
    required DateTime today,
  }) {
    final pages = remainingPages(lastPageRead);
    if (pages == 0) return 0;
    final days = remainingDays(endDate, today);
    if (days == 0) return pages;
    return (pages / days).ceil();
  }

  /// A fresh plan for [today] from [lastPageRead].
  static DayPlan planDay({
    required int lastPageRead,
    required DateTime endDate,
    required DateTime today,
  }) =>
      DayPlan(
        date: dateOnly(today),
        startPage: lastPageRead,
        targetPage: lastPageRead +
            dailyTarget(
                lastPageRead: lastPageRead, endDate: endDate, today: today),
      );

  /// Today's portion: the one fixed earlier today, or a new one when the
  /// day has changed since.
  static DayPlan dayPlan(Khatma k, DateTime today) {
    final plan = k.today;
    if (plan != null && daysBetween(plan.date, today) == 0) return plan;
    return planDay(
        lastPageRead: k.lastPageRead, endDate: k.endDate, today: today);
  }

  /// Fixes today's portion on [k] when the day has turned.
  static Khatma startDay(Khatma k, DateTime today) {
    if (k.status != KhatmaStatus.active) return k;
    final plan = dayPlan(k, today);
    return identical(plan, k.today) ? k : k.copyWith(today: plan);
  }

  /// Pages still to read today to finish today's portion.
  static int todayRemaining(Khatma k, DateTime today) =>
      math.max(0, dayPlan(k, today).targetPage - k.lastPageRead);

  /// Pages read so far today.
  static int readToday(Khatma k, DateTime today) =>
      math.max(0, k.lastPageRead - dayPlan(k, today).startPage);

  static bool todayDone(Khatma k, DateTime today) =>
      todayRemaining(k, today) == 0;

  /// A new khatma from [startPage] (1 = the beginning) to [endDate].
  static Khatma create({
    required String id,
    required DateTime today,
    required DateTime endDate,
    int startPage = 1,
    ReadingUnit displayUnit = ReadingUnit.pages,
    bool morningEnabled = true,
    int morningMinutes = Khatma.defaultMorningMinutes,
    bool eveningEnabled = false,
    int eveningMinutes = Khatma.defaultEveningMinutes,
  }) {
    final day = dateOnly(today);
    final start = startPage.clamp(1, totalPages);
    final end = daysBetween(day, endDate) < 0 ? day : dateOnly(endDate);
    final k = Khatma(
      id: id,
      startDate: day,
      endDate: end,
      startPage: start,
      lastPageRead: start - 1,
      planFrom: day,
      planFromPage: start - 1,
      displayUnit: displayUnit,
      morningEnabled: morningEnabled,
      morningMinutes: morningMinutes,
      eveningEnabled: eveningEnabled,
      eveningMinutes: eveningMinutes,
    );
    return startDay(k, day);
  }

  /// The end date for a duration of [days] days starting [today].
  static DateTime endDateFor(DateTime today, int days) =>
      addDays(dateOnly(today), math.max(1, days) - 1);

  /// The reader is now at [page] (raised or, to fix a mistake, lowered).
  /// Today's portion stays put unless the correction goes below where the
  /// day began; then the day is planned again from the corrected page.
  static Khatma reachPage(Khatma k, int page, DateTime today) {
    final p = page.clamp(k.startPage - 1, totalPages);
    var plan = dayPlan(k, today);
    if (p < plan.startPage) {
      plan = planDay(lastPageRead: p, endDate: k.endDate, today: today);
    }
    return k.copyWith(lastPageRead: p, today: plan);
  }

  /// The page reached after reading one more hizb from [lastPageRead]:
  /// the end of the hizb the next page belongs to.
  static int afterOneHizb(int lastPageRead) {
    if (lastPageRead >= totalPages) return totalPages;
    final next = lastPageRead + 1;
    return math.max(next, QuranPages.hizbEndPage(QuranPages.hizbAt(next)));
  }

  /// [logs] after the reader moved from [from] to [to] on [today]: a step
  /// forward extends today's entry; a step back trims every entry past
  /// [to] (dropping the ones that start after it).
  static List<DailyLog> logProgress(
    List<DailyLog> logs, {
    required String khatmaId,
    required DateTime today,
    required int from,
    required int to,
  }) {
    if (to == from) return logs;
    if (to < from) {
      return [
        for (final log in logs)
          if (log.khatmaId != khatmaId || log.toPage <= to)
            log
          else if (log.fromPage <= to)
            log.copyWith(toPage: to),
      ];
    }
    final i = logs.indexWhere(
        (l) => l.khatmaId == khatmaId && daysBetween(l.date, today) == 0);
    if (i < 0) {
      return [
        ...logs,
        DailyLog(
          khatmaId: khatmaId,
          date: dateOnly(today),
          fromPage: from + 1,
          toPage: to,
        ),
      ];
    }
    final log = logs[i];
    return [...logs]..[i] = log.copyWith(
        fromPage: math.min(log.fromPage, from + 1),
        toPage: math.max(log.toPage, to),
      );
  }

  /// A new end date mid-khatma. Today's portion is planned again from
  /// where the day began, so pages already read today still count towards
  /// it, and the pace line restarts from today.
  static Khatma reschedule(Khatma k, DateTime endDate, DateTime today) {
    final day = dateOnly(today);
    final end = daysBetween(day, endDate) < 0 ? day : dateOnly(endDate);
    final start = math.min(dayPlan(k, day).startPage, k.lastPageRead);
    return k.copyWith(
      endDate: end,
      planFrom: day,
      planFromPage: start,
      overdueKept: false,
      today: DayPlan(
        date: day,
        startPage: start,
        targetPage:
            start + dailyTarget(lastPageRead: start, endDate: end, today: day),
      ),
    );
  }

  /// Past the end date: [days] more days, counting today.
  static Khatma extend(Khatma k, int days, DateTime today) =>
      reschedule(k, endDateFor(today, days), today);

  static Khatma pause(Khatma k, DateTime today) => k.copyWith(
        status: KhatmaStatus.paused,
        pausedOn: dateOnly(today),
        today: null,
      );

  /// Back from a pause: the end date moves on by the days paused, and the
  /// day is planned from where the reader is.
  static Khatma resume(Khatma k, DateTime today) {
    final day = dateOnly(today);
    final gap = math.max(0, daysBetween(k.pausedOn ?? day, day));
    final end = addDays(k.endDate, gap);
    return k.copyWith(
      status: KhatmaStatus.active,
      pausedOn: null,
      endDate: end,
      planFrom: day,
      planFromPage: k.lastPageRead,
      today: planDay(lastPageRead: k.lastPageRead, endDate: end, today: day),
    );
  }

  static Khatma complete(Khatma k, DateTime now) => k.copyWith(
        lastPageRead: totalPages,
        status: KhatmaStatus.completed,
        completedAt: now,
        today: null,
      );

  /// Where the pace line expects the reader after [daysDone] full days.
  static int idealPage(Khatma k, int daysDone) {
    final span = math.max(1, daysBetween(k.planFrom, k.endDate) + 1);
    final total = totalPages - k.planFromPage;
    final done = daysDone.clamp(0, span);
    return k.planFromPage + (total * done / span).ceil();
  }

  /// Behind: short of where yesterday should have ended. Ahead: past where
  /// today should end. Overdue: the end date has gone by.
  static KhatmaPace pace(Khatma k, DateTime today) {
    if (isOverdue(k, today)) return KhatmaPace.overdue;
    final daysDone = daysBetween(k.planFrom, today);
    if (k.lastPageRead < idealPage(k, daysDone)) return KhatmaPace.behind;
    if (k.lastPageRead > idealPage(k, daysDone + 1)) return KhatmaPace.ahead;
    return KhatmaPace.onTrack;
  }

  /// Days the khatma has run, counting its first day and [today] (or the
  /// day it was completed).
  static int daysTaken(Khatma k, DateTime today) =>
      daysBetween(k.startDate, k.completedAt ?? today) + 1;

  /// Average pages read per day so far.
  static double averagePerDay(Khatma k, DateTime today) =>
      k.pagesRead / math.max(1, daysTaken(k, today));
}
