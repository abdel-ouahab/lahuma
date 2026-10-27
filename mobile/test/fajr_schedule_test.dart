import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/fajr_call/data/fajr_schedule.dart';
import 'package:lahuma/features/fajr_call/data/prayer_times_service.dart';
import 'package:lahuma/features/fajr_call/domain/fajr_call_list.dart';
import 'package:lahuma/features/fajr_call/domain/prayer_settings.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// Reference times from api.aladhan.com (independent implementation):
//   Algiers, method 19 "Algeria" (Fajr 18° / Isha 17°):
//     2026-11-15 → 05:56, 2026-06-21 → 03:37
//   Paris, Muslim World League:
//     2026-03-28 → 04:48 (CET), 2026-03-29 → 05:45 (CEST, DST day)
const algiers = PrayerSettings(latitude: 36.7538, longitude: 3.0588);
const paris = PrayerSettings(
  latitude: 48.8566,
  longitude: 2.3522,
  method: PrayerMethod.muslimWorldLeague,
);

String hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Minutes between two clock readings, ignoring the date.
int minutesApart(DateTime t, String expected) {
  final p = expected.split(':').map(int.parse).toList();
  return ((t.hour * 60 + t.minute) - (p[0] * 60 + p[1])).abs();
}

void main() {
  late tz.Location algiersTz;
  late tz.Location parisTz;
  const service = PrayerTimesService();
  const schedule = FajrSchedule();

  setUpAll(() {
    tzdata.initializeTimeZones();
    algiersTz = tz.getLocation('Africa/Algiers');
    parisTz = tz.getLocation('Europe/Paris');
  });

  group('PrayerTimesService', () {
    test('Algiers Fajr matches the reference within 1 minute', () {
      final nov = service.fajrOn(algiers, DateTime(2026, 11, 15),
          location: algiersTz)!;
      final jun = service.fajrOn(algiers, DateTime(2026, 6, 21),
          location: algiersTz)!;
      expect(minutesApart(nov, '05:56'), lessThanOrEqualTo(1), reason: hm(nov));
      expect(minutesApart(jun, '03:37'), lessThanOrEqualTo(1), reason: hm(jun));
      expect(nov.day, 15);
    });

    test('Paris Fajr across the spring DST change', () {
      final before =
          service.fajrOn(paris, DateTime(2026, 3, 28), location: parisTz)!;
      final after =
          service.fajrOn(paris, DateTime(2026, 3, 29), location: parisTz)!;
      expect(minutesApart(before, '04:48'), lessThanOrEqualTo(1),
          reason: hm(before));
      expect(minutesApart(after, '05:45'), lessThanOrEqualTo(1),
          reason: hm(after));
      expect(before.timeZoneOffset, const Duration(hours: 1));
      expect(after.timeZoneOffset, const Duration(hours: 2));
    });

    test('returns null without a location', () {
      expect(service.fajrOn(const PrayerSettings(), DateTime(2026, 1, 1)),
          isNull);
    });

    test('the method changes the result', () {
      final dz = service.fajrOn(algiers, DateTime(2026, 11, 15),
          location: algiersTz)!;
      final eg = service.fajrOn(
          algiers.copyWith(method: PrayerMethod.egyptian),
          DateTime(2026, 11, 15),
          location: algiersTz)!;
      expect(eg.isBefore(dz), isTrue, reason: '19.5° is earlier than 18°');
    });
  });

  group('FajrSchedule', () {
    const fajrList = FajrCallList(id: 'l', name: 'والداي');

    test('Fajr + offset, later today', () {
      final from = tz.TZDateTime(algiersTz, 2026, 11, 15, 1);
      final next = schedule.next(
          fajrList.copyWith(fajrOffsetMinutes: 10), algiers,
          from: from, location: algiersTz)!;
      expect(next.day, 15);
      expect(minutesApart(next, '06:06'), lessThanOrEqualTo(1),
          reason: hm(next));
    });

    test('a negative offset moves the call before Fajr', () {
      final from = tz.TZDateTime(algiersTz, 2026, 11, 15, 1);
      final plain =
          schedule.next(fajrList, algiers, from: from, location: algiersTz)!;
      final early = schedule.next(
          fajrList.copyWith(fajrOffsetMinutes: -15), algiers,
          from: from, location: algiersTz)!;
      expect(plain.difference(early), const Duration(minutes: 15));
    });

    test('past time today rolls over to tomorrow', () {
      final from = tz.TZDateTime(algiersTz, 2026, 11, 15, 7);
      final next =
          schedule.next(fajrList, algiers, from: from, location: algiersTz)!;
      expect(next.day, 16);
    });

    test('fixed time: today if still ahead, else tomorrow', () {
      final list = fajrList.copyWith(
          startMode: FajrStartMode.fixed, fixedTime: const TimeOfDayHm(5, 0));
      final early = schedule.next(list, algiers,
          from: tz.TZDateTime(algiersTz, 2026, 11, 15, 4, 59),
          location: algiersTz)!;
      expect(early, tz.TZDateTime(algiersTz, 2026, 11, 15, 5));
      final late = schedule.next(list, algiers,
          from: tz.TZDateTime(algiersTz, 2026, 11, 15, 5),
          location: algiersTz)!;
      expect(late, tz.TZDateTime(algiersTz, 2026, 11, 16, 5),
          reason: 'exactly now is not "next"');
    });

    test('fixed time does not need a location', () {
      final list = fajrList.copyWith(startMode: FajrStartMode.fixed);
      expect(
          schedule.next(list, const PrayerSettings(),
              from: tz.TZDateTime(algiersTz, 2026, 11, 15),
              location: algiersTz),
          isNotNull);
      expect(
          schedule.nextFireTimes(fajrList, const PrayerSettings(),
              from: DateTime(2026, 11, 15), location: algiersTz),
          isEmpty,
          reason: 'Fajr mode needs a location');
    });

    test('weekdays filter (15 Nov 2026 is a Sunday)', () {
      final list = fajrList.copyWith(
          weekdays: {DateTime.friday, DateTime.monday});
      final times = schedule.nextFireTimes(list, algiers,
          from: tz.TZDateTime(algiersTz, 2026, 11, 15), count: 4,
          location: algiersTz);
      expect(times.map((t) => t.day), [16, 20, 23, 27]);
      expect(times.every((t) => list.runsOn(t.weekday)), isTrue);
    });

    test('precomputes 14 strictly increasing daily times', () {
      final times = schedule.nextFireTimes(fajrList, algiers,
          from: tz.TZDateTime(algiersTz, 2026, 11, 15), location: algiersTz);
      expect(times, hasLength(FajrSchedule.precomputeCount));
      for (var i = 1; i < times.length; i++) {
        expect(times[i].isAfter(times[i - 1]), isTrue);
        expect(times[i].difference(times[i - 1]).inHours, inInclusiveRange(23, 25));
      }
    });

    test('a one-off list fires once', () {
      final times = schedule.nextFireTimes(
          fajrList.copyWith(repeatDaily: false), algiers,
          from: tz.TZDateTime(algiersTz, 2026, 11, 15), location: algiersTz);
      expect(times, hasLength(1));
    });

    test('fixed time keeps its wall-clock hour across DST', () {
      final list = fajrList.copyWith(
          startMode: FajrStartMode.fixed, fixedTime: const TimeOfDayHm(5, 0));
      final times = schedule.nextFireTimes(list, paris,
          from: tz.TZDateTime(parisTz, 2026, 3, 27, 12), count: 3,
          location: parisTz);
      // 28, 29 and 30 March at 05:00.
      expect(times.map((t) => t.day), [28, 29, 30]);
      expect(times.map((t) => t.hour), [5, 5, 5]);
      expect(times[1].difference(times[0]), const Duration(hours: 23),
          reason: 'the night of 28→29 March is an hour shorter');
      expect(times[2].difference(times[1]), const Duration(hours: 24));
    });

    test('a fixed time inside the DST gap rolls forward', () {
      final list = fajrList.copyWith(
          startMode: FajrStartMode.fixed, fixedTime: const TimeOfDayHm(2, 30));
      final next = schedule.next(list, paris,
          from: tz.TZDateTime(parisTz, 2026, 3, 29), location: parisTz)!;
      expect(next.day, 29);
      expect(next.hour, 3, reason: '02:30 does not exist on 29 March');
    });

    test('asking for no times returns none', () {
      final list = fajrList.copyWith(weekdays: {});
      expect(
          schedule.nextFireTimes(list, algiers,
              from: DateTime(2026, 11, 15), count: 0, location: algiersTz),
          isEmpty);
    });
  });
}
