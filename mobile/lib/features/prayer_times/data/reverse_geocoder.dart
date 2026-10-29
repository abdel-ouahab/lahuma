import 'package:flutter/widgets.dart' show Locale;
import 'package:geocoding/geocoding.dart' as geo;

/// Coordinates → city name, in Arabic when the platform geocoder has it.
/// Returns '' on any failure (offline, no result); the caller keeps going.
class ReverseGeocoder {
  const ReverseGeocoder();

  Future<String> cityName(double lat, double lng) async {
    try {
      final marks = await geo.Geocoding()
          .placemarkFromCoordinates(lat, lng, locale: const Locale('ar'))
          .timeout(const Duration(seconds: 8));
      for (final m in marks) {
        for (final v in [
          m.locality,
          m.subAdministrativeArea,
          m.administrativeArea
        ]) {
          if (v != null && v.trim().isNotEmpty) return v.trim();
        }
      }
    } catch (_) {}
    return '';
  }
}
