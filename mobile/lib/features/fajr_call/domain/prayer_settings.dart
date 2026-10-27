/// Prayer-time calculation methods offered in the app. Each maps onto
/// `adhan` parameters in `PrayerTimesService`.
enum PrayerMethod {
  /// Algerian Ministry of Religious Affairs: Fajr 18°, Isha 17°.
  algeria,

  /// Moroccan Ministry of Habous: Fajr 19°, Isha 17°.
  morocco,

  /// Tunisia: Fajr 18°, Isha 18°.
  tunisia,
  muslimWorldLeague,
  egyptian,
  ummAlQura,
  karachi,
  northAmerica,
  dubai,
  kuwait,
  qatar,
  singapore,
  turkey,
  tehran;

  static PrayerMethod parse(Object? value) {
    for (final m in values) {
      if (m.name == value) return m;
    }
    return algeria;
  }
}

/// Asr shadow rule. Not needed for Fajr; stored for a future prayer-times
/// screen.
enum PrayerMadhab {
  shafi,
  hanafi;

  static PrayerMadhab parse(Object? value) =>
      value == hanafi.name ? hanafi : shafi;
}

enum LocationSource {
  gps,
  manual;

  static LocationSource parse(Object? value) =>
      value == gps.name ? gps : manual;
}

/// Where and how prayer times are calculated. Everything stays on device.
class PrayerSettings {
  const PrayerSettings({
    this.latitude,
    this.longitude,
    this.placeName = '',
    this.source = LocationSource.manual,
    this.method = PrayerMethod.algeria,
    this.madhab = PrayerMadhab.shafi,
  });

  final double? latitude;
  final double? longitude;

  /// City / wilaya name, or a coarse label for a GPS fix.
  final String placeName;
  final LocationSource source;
  final PrayerMethod method;
  final PrayerMadhab madhab;

  bool get hasLocation => latitude != null && longitude != null;

  PrayerSettings copyWith({
    double? latitude,
    double? longitude,
    String? placeName,
    LocationSource? source,
    PrayerMethod? method,
    PrayerMadhab? madhab,
  }) =>
      PrayerSettings(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        placeName: placeName ?? this.placeName,
        source: source ?? this.source,
        method: method ?? this.method,
        madhab: madhab ?? this.madhab,
      );

  Map<String, dynamic> toJson() => {
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'placeName': placeName,
        'source': source.name,
        'method': method.name,
        'madhab': madhab.name,
      };

  factory PrayerSettings.fromJson(Map<String, dynamic> json) {
    double? coord(String key, double limit) {
      final v = json[key];
      if (v is! num) return null;
      final d = v.toDouble();
      return d.abs() <= limit ? d : null;
    }

    return PrayerSettings(
      latitude: coord('latitude', 90),
      longitude: coord('longitude', 180),
      placeName: json['placeName'] as String? ?? '',
      source: LocationSource.parse(json['source']),
      method: PrayerMethod.parse(json['method']),
      madhab: PrayerMadhab.parse(json['madhab']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PrayerSettings &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.placeName == placeName &&
      other.source == source &&
      other.method == method &&
      other.madhab == madhab;

  @override
  int get hashCode =>
      Object.hash(latitude, longitude, placeName, source, method, madhab);
}
