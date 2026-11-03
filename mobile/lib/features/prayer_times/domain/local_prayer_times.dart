import 'package:adhan/adhan.dart' as adhan;
import 'prayer_times.dart';

/// On-device prayer times, the offline fallback only.
///
/// The app's times come from Aladhan (method 19, Algeria), so that the
/// adhan matches Home exactly. This is used only when a headless reschedule
/// has neither a cached day nor a network: Fajr 18°, Isha 17°, as method 19.
/// Aladhan's own rounding and adjustments may differ by a minute or two.
class LocalPrayerTimes {
  const LocalPrayerTimes();

  static adhan.CalculationParameters get _params =>
      adhan.CalculationParameters(fajrAngle: 18, ishaAngle: 17)
        ..madhab = adhan.Madhab.shafi;

  /// [day]'s times at [location], as local [DateTime]s.
  DayPrayerTimes dayAt(DateTime day, PrayerLocation location) {
    final t = adhan.PrayerTimes.utc(
      adhan.Coordinates(location.latitude, location.longitude),
      adhan.DateComponents(day.year, day.month, day.day),
      _params,
    );
    return DayPrayerTimes(
      date: DateTime(day.year, day.month, day.day),
      times: {
        PrayerKind.fajr: t.fajr.toLocal(),
        PrayerKind.sunrise: t.sunrise.toLocal(),
        PrayerKind.dhuhr: t.dhuhr.toLocal(),
        PrayerKind.asr: t.asr.toLocal(),
        PrayerKind.maghrib: t.maghrib.toLocal(),
        PrayerKind.isha: t.isha.toLocal(),
      },
      hijri: null,
    );
  }
}
