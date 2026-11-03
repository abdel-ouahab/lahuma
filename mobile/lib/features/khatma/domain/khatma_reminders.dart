import 'dart:math' as math;
import 'khatma.dart';
import 'khatma_planner.dart';

enum KhatmaReminderKind { morning, evening }

/// One reminder to schedule: when, and the portion it announces.
class KhatmaReminder {
  const KhatmaReminder({
    required this.id,
    required this.at,
    required this.kind,
    required this.fromPage,
    required this.toPage,
    required this.partial,
  });

  final int id;

  /// Local wall-clock time.
  final DateTime at;
  final KhatmaReminderKind kind;

  /// The pages still to read that day.
  final int fromPage;
  final int toPage;

  /// Some of the day's portion was already read ("8 pages left").
  final bool partial;

  int get pages => toPage - fromPage + 1;
}

/// Which khatma reminders to schedule from [now].
///
/// Days after today assume nothing more is read in between, so each one
/// carries the target the reader would really face; every progress update
/// replans them. Today's reminders are left out once its portion is done.
class KhatmaReminderPlan {
  KhatmaReminderPlan._();

  /// Ids `minId … maxId - 1`: clear of Fajr Call (< 16 000 000) and the
  /// adhan (200 000 000 … 220 000 000).
  static const int minId = 230000000;
  static const int maxId = 230000100;

  static bool isKhatmaId(int id) => id >= minId && id < maxId;

  static int idFor(int dayOffset, KhatmaReminderKind kind) =>
      minId + dayOffset * 2 + (kind == KhatmaReminderKind.evening ? 1 : 0);

  /// Android has no pending cap: a week of mornings and evenings.
  static const int androidDays = 7;

  /// iOS shares 64 pending notifications with the adhan and Fajr Call:
  /// the next 3 mornings and this evening.
  static const int iosMornings = 3;
  static const int iosBudget = iosMornings + 1;

  static List<KhatmaReminder> plan(
    Khatma k,
    DateTime now, {
    required bool ios,
  }) {
    if (k.status != KhatmaStatus.active || k.finished) return const [];
    if (!k.morningEnabled && !k.eveningEnabled) return const [];
    final today = dateOnly(now);
    final result = <KhatmaReminder>[];
    var mornings = 0;

    void add(
        int offset, KhatmaReminderKind kind, int from, int to, bool partial) {
      final minutes = kind == KhatmaReminderKind.morning
          ? k.morningMinutes
          : k.eveningMinutes;
      final day = addDays(today, offset);
      final at =
          DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
      if (!at.isAfter(now)) return;
      if (kind == KhatmaReminderKind.morning) {
        if (ios && mornings >= iosMornings) return;
        mornings++;
      }
      result.add(KhatmaReminder(
        id: idFor(offset, kind),
        at: at,
        kind: kind,
        fromPage: from,
        toPage: to,
        partial: partial,
      ));
    }

    // Today: what is left of the portion fixed this morning.
    final plan = KhatmaPlanner.dayPlan(k, today);
    if (k.lastPageRead < plan.targetPage) {
      final partial = k.lastPageRead > plan.startPage;
      final from = math.max(plan.fromPage, k.lastPageRead + 1);
      if (k.morningEnabled) {
        add(0, KhatmaReminderKind.morning, from, plan.targetPage, partial);
      }
      if (k.eveningEnabled) {
        add(0, KhatmaReminderKind.evening, from, plan.targetPage, partial);
      }
    }

    final days = ios ? iosMornings + 1 : androidDays;
    for (var offset = 1; offset < days; offset++) {
      if (ios && (!k.morningEnabled || mornings >= iosMornings)) break;
      final day = addDays(today, offset);
      final target = KhatmaPlanner.dailyTarget(
          lastPageRead: k.lastPageRead, endDate: k.endDate, today: day);
      if (target == 0) break;
      final from = k.lastPageRead + 1;
      final to = k.lastPageRead + target;
      if (k.morningEnabled) {
        add(offset, KhatmaReminderKind.morning, from, to, false);
      }
      if (!ios && k.eveningEnabled) {
        add(offset, KhatmaReminderKind.evening, from, to, false);
      }
    }
    return result;
  }
}
