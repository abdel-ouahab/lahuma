import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/qibla/domain/qibla_service.dart';

void main() {
  const s = QiblaService();

  group('bearing', () {
    // Published Qibla directions (degrees from true north).
    for (final (city, lat, lon, expected) in [
      ('London', 51.5074, -0.1278, 118.99),
      ('New York', 40.7128, -74.0060, 58.48),
      ('Jakarta', -6.2088, 106.8456, 295.15),
      ('Sydney', -33.8688, 151.2093, 277.50),
      ('Cairo', 30.0444, 31.2357, 136.14),
      ('Tokyo', 35.6762, 139.6503, 293.00),
    ]) {
      test(city, () => expect(s.bearing(lat, lon), closeTo(expected, 0.05)));
    }

    test('due south and due north on the Kaaba meridian', () {
      expect(s.bearing(30, QiblaService.kaabaLongitude), closeTo(180, 1e-9));
      expect(s.bearing(10, QiblaService.kaabaLongitude), closeTo(0, 1e-9));
    });

    test('always in [0, 360)', () {
      for (var lat = -80.0; lat <= 80; lat += 20) {
        for (var lon = -180.0; lon < 180; lon += 15) {
          final b = s.bearing(lat, lon);
          expect(b, greaterThanOrEqualTo(0));
          expect(b, lessThan(360));
        }
      }
    });
  });

  group('distanceKm', () {
    test('known cities', () {
      expect(s.distanceKm(51.5074, -0.1278), closeTo(4794, 5));
      expect(s.distanceKm(40.7128, -74.0060), closeTo(10306, 10));
      expect(s.distanceKm(36.7538, 3.0588), closeTo(3926, 5));
    });

    test('zero at the Kaaba', () {
      expect(
          s.distanceKm(QiblaService.kaabaLatitude, QiblaService.kaabaLongitude),
          closeTo(0, 1e-6));
    });
  });

  group('angles', () {
    test('normalizeDegrees', () {
      expect(normalizeDegrees(0), 0);
      expect(normalizeDegrees(360), 0);
      expect(normalizeDegrees(-90), 270);
      expect(normalizeDegrees(725), 5);
      expect(normalizeDegrees(-1e-14), lessThan(360));
    });

    test('signedDelta takes the short way across north', () {
      expect(signedDelta(350, 10), closeTo(20, 1e-9));
      expect(signedDelta(10, 350), closeTo(-20, 1e-9));
      expect(signedDelta(90, 90), 0);
      expect(signedDelta(0, 180), 180);
    });

    test('unwrapDegrees keeps a continuous angle', () {
      expect(unwrapDegrees(359, 1), closeTo(361, 1e-9));
      expect(unwrapDegrees(361, 358), closeTo(358, 1e-9));
      expect(unwrapDegrees(-2, 355), closeTo(-5, 1e-9));
      expect(unwrapDegrees(720, 10), closeTo(730, 1e-9));
    });

    test('turn is positive to the right', () {
      expect(s.turn(80, 98), closeTo(18, 1e-9));
      expect(s.turn(120, 98), closeTo(-22, 1e-9));
      expect(s.turn(350, 5), closeTo(15, 1e-9));
    });

    test('isAligned has a wider release band', () {
      expect(s.isAligned(2.9), isTrue);
      expect(s.isAligned(-3), isTrue);
      expect(s.isAligned(4), isFalse);
      expect(s.isAligned(4, wasAligned: true), isTrue);
      expect(s.isAligned(-4.6, wasAligned: true), isFalse);
    });
  });

  group('HeadingFilter', () {
    test('first reading passes through', () {
      final f = HeadingFilter();
      expect(f.value, isNull);
      expect(f.add(42), closeTo(42, 1e-9));
    });

    test('averages across north without flipping to south', () {
      final f = HeadingFilter(smoothing: 0.5);
      f.add(358);
      final v = f.add(2);
      expect(signedDelta(0, v).abs(), lessThan(1));
    });

    test('damps jitter and converges on a steady heading', () {
      final f = HeadingFilter(smoothing: 0.2);
      f.add(100);
      final jittered = f.add(110);
      expect(jittered, lessThan(103));
      for (var i = 0; i < 60; i++) {
        f.add(120);
      }
      expect(f.value, closeTo(120, 0.01));
    });

    test('reset forgets the history', () {
      final f = HeadingFilter()..add(10);
      f.reset();
      expect(f.value, isNull);
      expect(f.add(200), closeTo(200, 1e-9));
    });
  });
}
