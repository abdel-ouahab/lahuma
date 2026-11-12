import '../../prayer_times/domain/prayer_times.dart';

/// The prayers the banner lists, in order (sunrise isn't one).
const List<PrayerKind> bannerPrayers = [
  PrayerKind.fajr,
  PrayerKind.dhuhr,
  PrayerKind.asr,
  PrayerKind.maghrib,
  PrayerKind.isha,
];

/// The day the banner shows and the prayer that comes next in it.
class BannerNext {
  const BannerNext(this.day, this.prayer);

  final DayPrayerTimes day;
  final PrayerKind prayer;

  DateTime get at => day[prayer];
  int get index => bannerPrayers.indexOf(prayer);

  /// When the count-down started: the prayer before, or the day's start.
  DateTime get since => index == 0 ? day.date : day[bannerPrayers[index - 1]];
}

/// The first prayer after [now]. After Isha it is the next day's Fajr, and
/// that day is shown. Null when [days] run out. Same rule as
/// `PrayerBanner.next` (Android).
BannerNext? nextBannerPrayer(List<DayPrayerTimes> days, DateTime now) {
  final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
  for (final d in sorted) {
    if (!bannerPrayers.every(d.times.containsKey)) continue;
    for (final p in bannerPrayers) {
      if (d[p].isAfter(now)) return BannerNext(d, p);
    }
  }
  return null;
}

/// Texts for the banner, in the app's language.
class PrayerBannerStrings {
  const PrayerBannerStrings({
    required this.names,
    required this.countdown,
    required this.channel,
    required this.rtl,
  });

  factory PrayerBannerStrings.of({required bool arabic}) =>
      PrayerBannerStrings(
        names: [for (final p in bannerPrayers) arabic ? p.ar : p.en],
        countdown: arabic ? 'بعد %s' : 'in %s',
        channel: arabic ? 'مواقيت الصلاة' : 'Prayer times',
        rtl: arabic,
      );

  /// Fajr to Isha.
  final List<String> names;

  /// `%s` is the time left.
  final String countdown;
  final String channel;
  final bool rtl;

  Map<String, Object> toMap() => {
        'names': names,
        'countdown': countdown,
        'channel': channel,
        'rtl': rtl,
      };
}
