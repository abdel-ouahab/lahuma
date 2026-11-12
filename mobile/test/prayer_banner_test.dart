import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/prayer_banner/data/prayer_banner_platform.dart';
import 'package:lahuma/features/prayer_banner/domain/prayer_banner.dart';
import 'package:lahuma/features/prayer_times/domain/prayer_times.dart';

DayPrayerTimes dayOf(DateTime d) => DayPrayerTimes(
      date: d,
      hijri: null,
      times: {
        PrayerKind.fajr: d.add(const Duration(hours: 5, minutes: 41)),
        PrayerKind.sunrise: d.add(const Duration(hours: 7, minutes: 5)),
        PrayerKind.dhuhr: d.add(const Duration(hours: 12, minutes: 18)),
        PrayerKind.asr: d.add(const Duration(hours: 15, minutes: 2)),
        PrayerKind.maghrib: d.add(const Duration(hours: 17, minutes: 24)),
        PrayerKind.isha: d.add(const Duration(hours: 18, minutes: 45)),
      },
    );

void main() {
  final today = DateTime(2026, 11, 11);
  final tomorrow = DateTime(2026, 11, 12);
  final days = [dayOf(tomorrow), dayOf(today)]; // out of order on purpose

  group('nextBannerPrayer', () {
    test('before Fajr: Fajr, counted from midnight', () {
      final n = nextBannerPrayer(days, today.add(const Duration(hours: 3)))!;
      expect(n.prayer, PrayerKind.fajr);
      expect(n.day.date, today);
      expect(n.since, today);
    });

    test('skips sunrise: after Fajr comes Dhuhr', () {
      final n = nextBannerPrayer(days, today.add(const Duration(hours: 6)))!;
      expect(n.prayer, PrayerKind.dhuhr);
      expect(n.since, today.add(const Duration(hours: 5, minutes: 41)));
    });

    test('at the minute of a prayer it has passed', () {
      final n = nextBannerPrayer(
          days, today.add(const Duration(hours: 15, minutes: 2)))!;
      expect(n.prayer, PrayerKind.maghrib);
    });

    test("after Isha: tomorrow's Fajr, with tomorrow's day", () {
      final n = nextBannerPrayer(days, today.add(const Duration(hours: 22)))!;
      expect(n.prayer, PrayerKind.fajr);
      expect(n.day.date, tomorrow);
    });

    test('no days left: null', () {
      expect(nextBannerPrayer(days, DateTime(2026, 11, 13)), isNull);
      expect(nextBannerPrayer(const [], today), isNull);
    });
  });

  test('Android gets five times a day, sunrise left out', () {
    final native = PrayerBannerPlatform.nativeDays([dayOf(today)]);
    expect(native.single, hasLength(5));
    expect(native.single.first,
        today.add(const Duration(hours: 5, minutes: 41)).millisecondsSinceEpoch);
  });

  test('iOS state: the shown day, the next index and Arabic texts', () {
    final s = PrayerBannerPlatform.iosState(
        days, today.add(const Duration(hours: 13)),
        arabic: true)!;
    expect(s['next'], 2);
    expect((s['names'] as List)[2], 'العصر');
    expect(s['countdown'], 'بعد');
    expect(s['rtl'], true);
    expect(s['since'],
        today.add(const Duration(hours: 12, minutes: 18)).millisecondsSinceEpoch);
  });

  test('strings: the count-down keeps its %s', () {
    expect(PrayerBannerStrings.of(arabic: false).countdown, 'in %s');
    expect(PrayerBannerStrings.of(arabic: true).names.first, 'الفجر');
  });
}
