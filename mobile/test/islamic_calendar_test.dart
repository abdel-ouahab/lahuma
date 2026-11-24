import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/islamic_calendar/data/calendar_notifications.dart';
import 'package:lahuma/features/islamic_calendar/data/calendar_repository.dart';
import 'package:lahuma/features/islamic_calendar/domain/calendar_reminders.dart';
import 'package:lahuma/features/islamic_calendar/domain/hijri_date.dart';
import 'package:lahuma/features/islamic_calendar/domain/islamic_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const uaq = HijriConverter();

  group('HijriConverter', () {
    test('matches the Umm al-Qura dates of 1446 AH', () {
      // Announced in Saudi Arabia: Ramadan from 1 March 2025, Eid al-Fitr
      // on 30 March, Eid al-Adha on 6 June.
      expect(uaq.toGregorian(const HijriDay(1446, 9, 1)), DateTime(2025, 3, 1));
      expect(uaq.toGregorian(const HijriDay(1446, 10, 1)), DateTime(2025, 3, 30));
      expect(uaq.toGregorian(const HijriDay(1446, 12, 10)), DateTime(2025, 6, 6));
      expect(uaq.fromGregorian(DateTime(2025, 3, 1)), const HijriDay(1446, 9, 1));
    });

    test('round-trips every day of a year', () {
      for (var d = DateTime(2026); d.year == 2026;
          d = DateTime(d.year, d.month, d.day + 1)) {
        expect(uaq.toGregorian(uaq.fromGregorian(d)), d, reason: '$d');
      }
    });

    test('an adjustment moves the Hijri date by whole days', () {
      const late = HijriConverter(adjustment: -1);
      expect(late.toGregorian(const HijriDay(1446, 9, 1)), DateTime(2025, 3, 2));
      expect(late.fromGregorian(DateTime(2025, 3, 2)), const HijriDay(1446, 9, 1));
      const early = HijriConverter(adjustment: 1);
      expect(early.fromGregorian(DateTime(2025, 2, 28)), const HijriDay(1446, 9, 1));
    });

    test('months have 29 or 30 days', () {
      for (var m = 1; m <= 12; m++) {
        expect(uaq.monthLength(1447, m), inInclusiveRange(29, 30));
      }
    });
  });

  group('IslamicEventCalendar', () {
    const calendar = IslamicEventCalendar(uaq);

    test('dates the occasions of a year in order', () {
      final year = calendar.between(DateTime(2025, 1, 1), DateTime(2025, 12, 31));
      DateTime dateOf(IslamicEvent e) =>
          year.firstWhere((o) => o.event == e).date;
      expect(dateOf(IslamicEvent.ramadan), DateTime(2025, 3, 1));
      expect(dateOf(IslamicEvent.eidAlFitr), DateTime(2025, 3, 30));
      expect(dateOf(IslamicEvent.arafah), DateTime(2025, 6, 5));
      expect(dateOf(IslamicEvent.eidAlAdha), DateTime(2025, 6, 6));
      for (var i = 1; i < year.length; i++) {
        expect(year[i].date.isBefore(year[i - 1].date), isFalse);
      }
    });

    test('the white days skip Dhu al-Hijjah (Tashreeq)', () {
      expect(IslamicEvent.whiteDays.covers(const HijriDay(1446, 11, 13)), isTrue);
      expect(IslamicEvent.whiteDays.covers(const HijriDay(1446, 12, 13)), isFalse);
      expect(calendar.on(const HijriDay(1446, 12, 13)), [IslamicEvent.tashreeq]);
    });

    test('lists an occasion under way only when asked', () {
      // 25 Ramadan 1446 is 25 March 2025, inside the last ten nights.
      final from = DateTime(2025, 3, 25);
      bool lists(List<EventOccurrence> l) =>
          l.any((o) => o.event == IslamicEvent.lastTenNights);
      expect(lists(calendar.between(from, from.add(const Duration(days: 3)))),
          isFalse);
      expect(
          lists(calendar.between(from, from.add(const Duration(days: 3)),
              ongoing: true)),
          isTrue);
    });
  });

  group('CalendarReminderPlanner', () {
    const calendar = IslamicEventCalendar(uaq);
    final now = DateTime(2025, 2, 1, 12);
    final occurrences =
        calendar.between(now, now.add(CalendarReminderPlanner.horizon));

    List<CalendarReminder> plan(CalendarSettings s, {bool ios = false}) =>
        CalendarReminderPlanner.plan(
            occurrences: occurrences, settings: s, now: now, ios: ios);

    test('nothing while the reminders are off', () {
      expect(
          plan(CalendarSettings(events: IslamicEvent.values.toSet())), isEmpty);
    });

    test('the evening before, at 8 pm', () {
      final r = plan(const CalendarSettings(
          remindersOn: true, events: {IslamicEvent.eidAlFitr}));
      expect(r.first.at, DateTime(2025, 3, 29, 20));
      expect(r.first.eveningBefore, isTrue);
    });

    test('on the morning of the day, except nights and Ramadan', () {
      final r = plan(const CalendarSettings(
        remindersOn: true,
        timing: CalendarReminderTiming.morningOf,
        events: {
          IslamicEvent.eidAlFitr,
          IslamicEvent.ramadan,
          IslamicEvent.laylatAlQadr,
        },
      ));
      DateTime at(IslamicEvent e) =>
          r.firstWhere((x) => x.occurrence.event == e).at;
      expect(at(IslamicEvent.eidAlFitr), DateTime(2025, 3, 30, 8));
      expect(at(IslamicEvent.ramadan), DateTime(2025, 2, 28, 20));
      expect(at(IslamicEvent.laylatAlQadr), DateTime(2025, 3, 26, 20));
    });

    test('ids are unique and in the calendar range', () {
      final r = plan(CalendarSettings(
          remindersOn: true, events: IslamicEvent.values.toSet()));
      expect(r, isNotEmpty);
      expect(r.map((x) => x.id).toSet().length, r.length);
      expect(r.every((x) => CalendarReminderPlanner.isCalendarId(x.id)), isTrue);
      // The white days only for the next two months.
      expect(
          r.where((x) => x.occurrence.event == IslamicEvent.whiteDays).every(
              (x) => x.at.isBefore(
                  now.add(CalendarReminderPlanner.monthlyHorizon))),
          isTrue);
    });

    test('only the nearest few on iOS', () {
      final r = plan(
          CalendarSettings(remindersOn: true, events: IslamicEvent.values.toSet()),
          ios: true);
      expect(r.length, CalendarReminderPlanner.iosLimit);
    });

    test('the text says when, and warns about the sighting', () {
      final r = plan(const CalendarSettings(
              remindersOn: true, events: {IslamicEvent.ramadan}))
          .first;
      final ar = CalendarNotifications.body(r, arabic: true);
      expect(ar, startsWith('غدًا إن شاء الله.'));
      expect(ar, contains('رؤية الهلال'));
      final night = plan(const CalendarSettings(
              remindersOn: true, events: {IslamicEvent.laylatAlQadr}))
          .first;
      expect(CalendarNotifications.body(night, arabic: false),
          startsWith('Tonight'));
    });
  });

  group('CalendarRepository', () {
    test('defaults to the major occasions, reminders off', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await CalendarRepository().load();
      expect(s.remindersOn, isFalse);
      expect(s.events, IslamicEvent.defaultReminders);
      expect(s.events, contains(IslamicEvent.arafah));
    });

    test('saves and loads', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = CalendarRepository();
      await repo.save(const CalendarSettings(
        remindersOn: true,
        timing: CalendarReminderTiming.morningOf,
        events: {IslamicEvent.ashura},
        adjustment: -1,
      ));
      final s = await repo.load();
      expect(s.remindersOn, isTrue);
      expect(s.timing, CalendarReminderTiming.morningOf);
      expect(s.events, {IslamicEvent.ashura});
      expect(s.adjustment, -1);
    });
  });
}
