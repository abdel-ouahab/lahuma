import 'package:adhan/adhan.dart' as adhan;
import 'package:timezone/timezone.dart' as tz;
import '../domain/prayer_settings.dart';

/// Offline prayer-time calculation (wraps the `adhan` package).
///
/// Only Fajr is used today; the class is kept free of Fajr Call concerns so a
/// prayer-times screen can reuse it. Results are [tz.TZDateTime]s in the
/// given location so daylight-saving changes are handled in one place.
class PrayerTimesService {
  const PrayerTimesService();

  adhan.CalculationParameters parameters(PrayerSettings settings) {
    final params = switch (settings.method) {
      PrayerMethod.algeria =>
        adhan.CalculationParameters(fajrAngle: 18, ishaAngle: 17),
      PrayerMethod.morocco =>
        adhan.CalculationParameters(fajrAngle: 19, ishaAngle: 17),
      PrayerMethod.tunisia =>
        adhan.CalculationParameters(fajrAngle: 18, ishaAngle: 18),
      PrayerMethod.muslimWorldLeague =>
        adhan.CalculationMethod.muslim_world_league.getParameters(),
      PrayerMethod.egyptian => adhan.CalculationMethod.egyptian.getParameters(),
      PrayerMethod.ummAlQura =>
        adhan.CalculationMethod.umm_al_qura.getParameters(),
      PrayerMethod.karachi => adhan.CalculationMethod.karachi.getParameters(),
      PrayerMethod.northAmerica =>
        adhan.CalculationMethod.north_america.getParameters(),
      PrayerMethod.dubai => adhan.CalculationMethod.dubai.getParameters(),
      PrayerMethod.kuwait => adhan.CalculationMethod.kuwait.getParameters(),
      PrayerMethod.qatar => adhan.CalculationMethod.qatar.getParameters(),
      PrayerMethod.singapore =>
        adhan.CalculationMethod.singapore.getParameters(),
      PrayerMethod.turkey => adhan.CalculationMethod.turkey.getParameters(),
      PrayerMethod.tehran => adhan.CalculationMethod.tehran.getParameters(),
    };
    params.madhab = settings.madhab == PrayerMadhab.hanafi
        ? adhan.Madhab.hanafi
        : adhan.Madhab.shafi;
    return params;
  }

  /// Fajr on the calendar day of [day] in [location], or null when no
  /// location is set yet.
  tz.TZDateTime? fajrOn(
    PrayerSettings settings,
    DateTime day, {
    tz.Location? location,
  }) {
    if (!settings.hasLocation) return null;
    final loc = location ?? tz.local;
    final times = adhan.PrayerTimes.utc(
      adhan.Coordinates(settings.latitude!, settings.longitude!),
      adhan.DateComponents(day.year, day.month, day.day),
      parameters(settings),
    );
    return tz.TZDateTime.from(times.fajr, loc);
  }
}
