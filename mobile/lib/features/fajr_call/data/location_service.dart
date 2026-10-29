import 'package:geolocator/geolocator.dart';

enum LocationFailure { serviceDisabled, denied, deniedForever, unavailable }

class LocationException implements Exception {
  const LocationException(this.reason);
  final LocationFailure reason;
}

/// One coarse location fix for prayer times. Asked once, in context; the
/// coordinates are stored on the device and never sent anywhere.
class LocationService {
  const LocationService();

  /// With [request] false a missing permission is reported ([denied]) instead
  /// of prompting, for background refreshes that must not nag.
  Future<({double latitude, double longitude})> currentPosition(
      {bool request = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationFailure.serviceDisabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && request) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(LocationFailure.deniedForever);
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      throw const LocationException(LocationFailure.denied);
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          // City-level accuracy is plenty for prayer times.
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return (latitude: p.latitude, longitude: p.longitude);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return (latitude: last.latitude, longitude: last.longitude);
      }
      throw const LocationException(LocationFailure.unavailable);
    }
  }

  Future<void> openSettings(LocationFailure reason) async {
    if (reason == LocationFailure.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}
