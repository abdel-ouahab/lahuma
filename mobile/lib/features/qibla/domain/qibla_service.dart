import 'dart:math' as math;
import '../../fajr_call/data/places.dart' as places show distanceKm;

/// Qibla math: great-circle bearing and distance to the Kaaba, plus the
/// angle helpers the compass needs. Pure Dart, no Flutter.
class QiblaService {
  const QiblaService();

  static const double kaabaLatitude = 21.4224779;
  static const double kaabaLongitude = 39.8251832;

  /// Within this many degrees of the Qibla the phone counts as facing it.
  static const double alignTolerance = 3;

  /// Once facing it, the phone has to drift this far before it stops
  /// counting, so the state (and its haptic) doesn't flicker at the edge.
  static const double releaseTolerance = 4.5;

  /// Initial great-circle bearing from the given point to the Kaaba, in
  /// degrees clockwise from true north, in [0, 360).
  ///
  /// θ = atan2(sin Δλ · cos φ2, cos φ1 · sin φ2 − sin φ1 · cos φ2 · cos Δλ)
  double bearing(double latitude, double longitude) {
    final phi1 = _rad(latitude);
    final phi2 = _rad(kaabaLatitude);
    final dLambda = _rad(kaabaLongitude - longitude);
    final y = math.sin(dLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);
    return normalizeDegrees(math.atan2(y, x) * 180 / math.pi);
  }

  /// Haversine distance to the Kaaba, in km.
  double distanceKm(double latitude, double longitude) =>
      places.distanceKm(latitude, longitude, kaabaLatitude, kaabaLongitude);

  /// How far to turn from [heading] to face [qibla], in (−180, 180].
  /// Positive means turn right (clockwise).
  double turn(double heading, double qibla) => signedDelta(heading, qibla);

  /// Whether a [turn] this size counts as facing the Qibla. Pass the last
  /// result as [wasAligned] for the wider release band.
  bool isAligned(double turn, {bool wasAligned = false}) =>
      turn.abs() <= (wasAligned ? releaseTolerance : alignTolerance);

  static double _rad(double degrees) => degrees * math.pi / 180;
}

/// [degrees] folded into [0, 360).
double normalizeDegrees(double degrees) {
  final d = degrees % 360;
  return d == 360 ? 0 : d;
}

/// Shortest signed rotation from [from] to [to], in (−180, 180].
double signedDelta(double from, double to) {
  final d = normalizeDegrees(to - from);
  return d > 180 ? d - 360 : d;
}

/// [heading] as a continuous angle next to [previous]: crossing north goes
/// 359 → 361 instead of 359 → 1, so an animation between the two never
/// spins the long way round.
double unwrapDegrees(double previous, double heading) =>
    previous + signedDelta(previous, heading);

/// Low-pass filter for compass headings. Averages the unit vectors rather
/// than the angles, so readings either side of north (359°, 1°) average to
/// 0° instead of 180°.
class HeadingFilter {
  HeadingFilter({this.smoothing = 0.2})
      : assert(smoothing > 0 && smoothing <= 1);

  /// Weight of each new reading: 1 passes readings through unchanged,
  /// smaller values are smoother but slower to follow a turn.
  final double smoothing;

  double? _x;
  double? _y;

  /// The smoothed heading, or null before the first reading.
  double? get value {
    final x = _x, y = _y;
    if (x == null || y == null) return null;
    return normalizeDegrees(math.atan2(y, x) * 180 / math.pi);
  }

  /// Adds a reading (degrees) and returns the smoothed heading.
  double add(double heading) {
    final r = heading * math.pi / 180;
    final x = math.cos(r), y = math.sin(r);
    final px = _x, py = _y;
    if (px == null || py == null) {
      _x = x;
      _y = y;
    } else {
      _x = px + smoothing * (x - px);
      _y = py + smoothing * (y - py);
    }
    return value!;
  }

  void reset() {
    _x = null;
    _y = null;
  }
}
