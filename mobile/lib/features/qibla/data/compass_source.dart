import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../domain/qibla_service.dart';

/// One raw compass reading.
class CompassReading {
  const CompassReading({required this.heading, this.accuracy});

  /// Where the top of the phone points, degrees clockwise from north, in
  /// [0, 360). Magnetic north on Android, true north on iOS (see
  /// [CompassSource.declination]).
  final double heading;

  /// ± degrees. Null when the platform can't tell, which on Android also
  /// covers "unreliable, needs calibration".
  final double? accuracy;
}

/// The phone's compass: flutter_compass for headings, plus `lahuma/qibla`
/// on Android for what the plugin doesn't expose (see `QiblaChannel.kt`).
class CompassSource {
  const CompassSource();

  static const _channel = MethodChannel('lahuma/qibla');

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// False when the phone has no magnetometer; null when that can't be told
  /// up front (iOS: every iPhone has one, but it may stay silent).
  Future<bool?> hasCompass() async {
    if (!_android) return null;
    try {
      return await _channel.invokeMethod<bool>('hasCompass');
    } catch (e) {
      debugPrint('Qibla: hasCompass failed: $e');
      return null;
    }
  }

  /// Headings while listened to; cancelling stops the sensors.
  Stream<CompassReading> readings() {
    final events = FlutterCompass.events;
    if (events == null) return const Stream.empty();
    return events.where(_valid).map((e) => CompassReading(
          heading: normalizeDegrees(e.heading!),
          accuracy: e.accuracy,
        ));
  }

  bool _valid(CompassEvent e) {
    final h = e.heading;
    if (h == null || h.isNaN) return false;
    // iOS sends trueHeading, which is −1 until it knows where the phone is.
    if (_ios && h < 0) return false;
    return true;
  }

  /// Degrees to add to a reading to get true north at this place (east
  /// positive). Android readings are magnetic; iOS ones are already true.
  Future<double> declination(double latitude, double longitude) async {
    if (!_android) return 0;
    try {
      final d = await _channel.invokeMethod<double>('declination',
          {'latitude': latitude, 'longitude': longitude});
      return d ?? 0;
    } catch (e) {
      debugPrint('Qibla: declination failed: $e');
      return 0;
    }
  }
}
