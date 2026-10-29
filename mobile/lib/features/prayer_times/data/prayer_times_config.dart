/// Tunables for the Home prayer-times section.
class PrayerTimesConfig {
  PrayerTimesConfig._();

  static const String baseUrl = 'https://api.aladhan.com/v1/';

  /// Aladhan calculation method id (19 = Algeria). Change here to switch.
  static const int method = 19;

  /// Moving farther than this from the saved location refetches the times.
  static const double refetchDistanceKm = 5;

  /// Days kept ahead (today included), so the adhan can be scheduled a week
  /// out and still fire when the phone is offline.
  static const int daysAhead = 7;
}
