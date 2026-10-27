import 'dart:math' as math;
import '../domain/prayer_settings.dart';

/// A city offered in the manual location picker.
class Place {
  const Place(this.ar, this.en, this.country, this.latitude, this.longitude);

  final String ar;
  final String en;

  /// ISO 3166 country code.
  final String country;
  final double latitude;
  final double longitude;

  String name(bool arabic) => arabic ? ar : en;
}

/// The method each country's authorities use; Muslim World League elsewhere.
PrayerMethod methodForCountry(String country) => switch (country) {
      'DZ' => PrayerMethod.algeria,
      'MA' => PrayerMethod.morocco,
      'TN' => PrayerMethod.tunisia,
      'SA' => PrayerMethod.ummAlQura,
      'EG' || 'LY' || 'SD' => PrayerMethod.egyptian,
      'AE' => PrayerMethod.dubai,
      'QA' => PrayerMethod.qatar,
      'KW' => PrayerMethod.kuwait,
      'TR' => PrayerMethod.turkey,
      'CA' || 'US' => PrayerMethod.northAmerica,
      _ => PrayerMethod.muslimWorldLeague,
    };

/// Great-circle distance in kilometres.
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// The listed place closest to a GPS fix, with its distance.
({Place place, double km}) nearestPlace(double lat, double lon) {
  var best = kPlaces.first;
  var bestKm = double.infinity;
  for (final p in kPlaces) {
    final d = distanceKm(lat, lon, p.latitude, p.longitude);
    if (d < bestKm) {
      best = p;
      bestKm = d;
    }
  }
  return (place: best, km: bestKm);
}

/// The 58 Algerian wilayas (by number), then major cities elsewhere.
/// Coordinates are city centres, close enough for prayer times (0.1° ≈ half
/// a minute of Fajr).
const List<Place> kPlaces = [
  Place('أدرار', 'Adrar', 'DZ', 27.874, -0.294),
  Place('الشلف', 'Chlef', 'DZ', 36.165, 1.335),
  Place('الأغواط', 'Laghouat', 'DZ', 33.800, 2.865),
  Place('أم البواقي', 'Oum El Bouaghi', 'DZ', 35.875, 7.114),
  Place('باتنة', 'Batna', 'DZ', 35.556, 6.174),
  Place('بجاية', 'Béjaïa', 'DZ', 36.751, 5.084),
  Place('بسكرة', 'Biskra', 'DZ', 34.851, 5.728),
  Place('بشار', 'Béchar', 'DZ', 31.617, -2.217),
  Place('البليدة', 'Blida', 'DZ', 36.470, 2.828),
  Place('البويرة', 'Bouira', 'DZ', 36.375, 3.902),
  Place('تمنراست', 'Tamanrasset', 'DZ', 22.785, 5.523),
  Place('تبسة', 'Tébessa', 'DZ', 35.404, 8.124),
  Place('تلمسان', 'Tlemcen', 'DZ', 34.878, -1.315),
  Place('تيارت', 'Tiaret', 'DZ', 35.371, 1.317),
  Place('تيزي وزو', 'Tizi Ouzou', 'DZ', 36.712, 4.046),
  Place('الجزائر', 'Algiers', 'DZ', 36.754, 3.059),
  Place('الجلفة', 'Djelfa', 'DZ', 34.673, 3.263),
  Place('جيجل', 'Jijel', 'DZ', 36.820, 5.766),
  Place('سطيف', 'Sétif', 'DZ', 36.190, 5.414),
  Place('سعيدة', 'Saïda', 'DZ', 34.830, 0.152),
  Place('سكيكدة', 'Skikda', 'DZ', 36.876, 6.909),
  Place('سيدي بلعباس', 'Sidi Bel Abbès', 'DZ', 35.190, -0.631),
  Place('عنابة', 'Annaba', 'DZ', 36.900, 7.766),
  Place('قالمة', 'Guelma', 'DZ', 36.462, 7.426),
  Place('قسنطينة', 'Constantine', 'DZ', 36.365, 6.615),
  Place('المدية', 'Médéa', 'DZ', 36.264, 2.753),
  Place('مستغانم', 'Mostaganem', 'DZ', 35.931, 0.089),
  Place('المسيلة', "M'Sila", 'DZ', 35.706, 4.542),
  Place('معسكر', 'Mascara', 'DZ', 35.397, 0.140),
  Place('ورقلة', 'Ouargla', 'DZ', 31.949, 5.325),
  Place('وهران', 'Oran', 'DZ', 35.697, -0.631),
  Place('البيض', 'El Bayadh', 'DZ', 33.683, 1.017),
  Place('إليزي', 'Illizi', 'DZ', 26.483, 8.467),
  Place('برج بوعريريج', 'Bordj Bou Arréridj', 'DZ', 36.073, 4.761),
  Place('بومرداس', 'Boumerdès', 'DZ', 36.766, 3.477),
  Place('الطارف', 'El Tarf', 'DZ', 36.767, 8.314),
  Place('تندوف', 'Tindouf', 'DZ', 27.671, -8.147),
  Place('تيسمسيلت', 'Tissemsilt', 'DZ', 35.607, 1.811),
  Place('الوادي', 'El Oued', 'DZ', 33.368, 6.868),
  Place('خنشلة', 'Khenchela', 'DZ', 35.436, 7.143),
  Place('سوق أهراس', 'Souk Ahras', 'DZ', 36.286, 7.951),
  Place('تيبازة', 'Tipaza', 'DZ', 36.589, 2.447),
  Place('ميلة', 'Mila', 'DZ', 36.450, 6.264),
  Place('عين الدفلى', 'Aïn Defla', 'DZ', 36.264, 1.968),
  Place('النعامة', 'Naâma', 'DZ', 33.267, -0.313),
  Place('عين تموشنت', 'Aïn Témouchent', 'DZ', 35.297, -1.140),
  Place('غرداية', 'Ghardaïa', 'DZ', 32.490, 3.674),
  Place('غليزان', 'Relizane', 'DZ', 35.737, 0.556),
  Place('تيميمون', 'Timimoun', 'DZ', 29.263, 0.241),
  Place('برج باجي مختار', 'Bordj Badji Mokhtar', 'DZ', 21.329, 0.955),
  Place('أولاد جلال', 'Ouled Djellal', 'DZ', 34.421, 5.071),
  Place('بني عباس', 'Béni Abbès', 'DZ', 30.132, -2.169),
  Place('عين صالح', 'In Salah', 'DZ', 27.197, 2.483),
  Place('عين قزام', 'In Guezzam', 'DZ', 19.572, 5.769),
  Place('تقرت', 'Touggourt', 'DZ', 33.106, 6.064),
  Place('جانت', 'Djanet', 'DZ', 24.555, 9.485),
  Place('المغير', "El M'Ghair", 'DZ', 33.951, 5.923),
  Place('المنيعة', 'El Meniaa', 'DZ', 30.579, 2.879),
  Place('مكة المكرمة', 'Makkah', 'SA', 21.423, 39.826),
  Place('المدينة المنورة', 'Madinah', 'SA', 24.469, 39.614),
  Place('الرياض', 'Riyadh', 'SA', 24.714, 46.675),
  Place('جدة', 'Jeddah', 'SA', 21.543, 39.173),
  Place('القاهرة', 'Cairo', 'EG', 30.044, 31.236),
  Place('الإسكندرية', 'Alexandria', 'EG', 31.200, 29.919),
  Place('الدار البيضاء', 'Casablanca', 'MA', 33.573, -7.590),
  Place('الرباط', 'Rabat', 'MA', 34.021, -6.842),
  Place('وجدة', 'Oujda', 'MA', 34.681, -1.908),
  Place('تونس', 'Tunis', 'TN', 36.807, 10.182),
  Place('صفاقس', 'Sfax', 'TN', 34.740, 10.760),
  Place('طرابلس', 'Tripoli', 'LY', 32.887, 13.191),
  Place('نواكشوط', 'Nouakchott', 'MR', 18.074, -15.958),
  Place('عمّان', 'Amman', 'JO', 31.945, 35.928),
  Place('القدس', 'Jerusalem', 'PS', 31.778, 35.235),
  Place('دبي', 'Dubai', 'AE', 25.205, 55.271),
  Place('الدوحة', 'Doha', 'QA', 25.285, 51.531),
  Place('الكويت', 'Kuwait City', 'KW', 29.376, 47.977),
  Place('إسطنبول', 'Istanbul', 'TR', 41.008, 28.978),
  Place('باريس', 'Paris', 'FR', 48.857, 2.352),
  Place('مرسيليا', 'Marseille', 'FR', 43.297, 5.370),
  Place('ليون', 'Lyon', 'FR', 45.764, 4.836),
  Place('بروكسل', 'Brussels', 'BE', 50.850, 4.352),
  Place('لندن', 'London', 'GB', 51.507, -0.128),
  Place('برلين', 'Berlin', 'DE', 52.520, 13.405),
  Place('مونتريال', 'Montreal', 'CA', 45.502, -73.567),
];
