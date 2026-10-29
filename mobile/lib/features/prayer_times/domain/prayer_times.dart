/// The six times shown on Home, in daily order.
enum PrayerKind {
  fajr('Fajr', 'الفجر', 'Fajr'),
  sunrise('Sunrise', 'الشروق', 'Sunrise'),
  dhuhr('Dhuhr', 'الظهر', 'Dhuhr'),
  asr('Asr', 'العصر', 'Asr'),
  maghrib('Maghrib', 'المغرب', 'Maghrib'),
  isha('Isha', 'العشاء', 'Isha');

  const PrayerKind(this.apiKey, this.ar, this.en);

  /// Key in the Aladhan `timings` object.
  final String apiKey;
  final String ar;
  final String en;
}

class HijriDate {
  const HijriDate({
    required this.day,
    required this.monthAr,
    required this.monthEn,
    required this.year,
  });

  final int day;
  final String monthAr;
  final String monthEn;
  final int year;

  String format(bool arabic) =>
      arabic ? '$day $monthAr $year هـ' : '$day $monthEn $year AH';

  Map<String, dynamic> toJson() =>
      {'day': day, 'monthAr': monthAr, 'monthEn': monthEn, 'year': year};

  factory HijriDate.fromJson(Map<String, dynamic> json) => HijriDate(
        day: json['day'] as int,
        monthAr: json['monthAr'] as String,
        monthEn: json['monthEn'] as String,
        year: json['year'] as int,
      );
}

/// Where the times were calculated for. [city] may be empty when reverse
/// geocoding failed.
class PrayerLocation {
  const PrayerLocation({
    required this.latitude,
    required this.longitude,
    this.city = '',
  });

  final double latitude;
  final double longitude;
  final String city;

  PrayerLocation copyWith({String? city}) => PrayerLocation(
      latitude: latitude, longitude: longitude, city: city ?? this.city);

  Map<String, dynamic> toJson() =>
      {'lat': latitude, 'lng': longitude, 'city': city};

  factory PrayerLocation.fromJson(Map<String, dynamic> json) => PrayerLocation(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
        city: (json['city'] as String?) ?? '',
      );
}

/// One calendar day of timings, as local [DateTime]s.
class DayPrayerTimes {
  const DayPrayerTimes({
    required this.date,
    required this.times,
    required this.hijri,
  });

  /// Midnight of the calendar day these times belong to.
  final DateTime date;
  final Map<PrayerKind, DateTime> times;
  final HijriDate? hijri;

  DateTime operator [](PrayerKind kind) => times[kind]!;

  DateTime get fajr => this[PrayerKind.fajr];

  /// Local `yyyy-MM-dd`, the cache key.
  String get key => dayKey(date);

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'date': key,
        'times': {
          for (final e in times.entries)
            e.key.name: e.value.millisecondsSinceEpoch,
        },
        if (hijri != null) 'hijri': hijri!.toJson(),
      };

  factory DayPrayerTimes.fromJson(Map<String, dynamic> json) {
    final d = DateTime.parse(json['date'] as String);
    final raw = Map<String, dynamic>.from(json['times'] as Map);
    return DayPrayerTimes(
      date: DateTime(d.year, d.month, d.day),
      times: {
        for (final k in PrayerKind.values)
          k: DateTime.fromMillisecondsSinceEpoch(raw[k.name] as int),
      },
      hijri: json['hijri'] != null
          ? HijriDate.fromJson(Map<String, dynamic>.from(json['hijri'] as Map))
          : null,
    );
  }
}

/// The prayer after [now], and when it falls.
class NextPrayer {
  const NextPrayer(this.kind, this.at, {this.tomorrow = false});

  final PrayerKind kind;
  final DateTime at;

  /// True when it is tomorrow's Fajr (after Isha).
  final bool tomorrow;

  Duration remaining(DateTime now) {
    final d = at.difference(now);
    return d.isNegative ? Duration.zero : d;
  }
}

/// The first of [today]'s times after [now]; after Isha, tomorrow's Fajr.
/// Without [tomorrow] data, today's Fajr + 1 day stands in (off by a minute
/// or so) until the real timings arrive.
NextPrayer nextPrayerOf(
    DayPrayerTimes today, DayPrayerTimes? tomorrow, DateTime now) {
  for (final k in PrayerKind.values) {
    if (today[k].isAfter(now)) return NextPrayer(k, today[k]);
  }
  return NextPrayer(
    PrayerKind.fajr,
    tomorrow?.fajr ?? today.fajr.add(const Duration(days: 1)),
    tomorrow: true,
  );
}
