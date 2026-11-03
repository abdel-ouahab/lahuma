import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../prayer_times/presentation/prayer_times_providers.dart';
import '../data/compass_source.dart';
import '../domain/qibla_service.dart';

final compassSourceProvider =
    Provider<CompassSource>((ref) => const CompassSource());

/// The Qibla from where the prayer times are calculated (GPS, the cached
/// fix, or the city chosen in settings). Null until a location is known.
class QiblaInfo {
  const QiblaInfo({
    required this.bearing,
    required this.distanceKm,
    required this.city,
  });

  /// Degrees clockwise from true north.
  final double bearing;
  final double distanceKm;

  /// Empty when the place has no name yet.
  final String city;
}

final qiblaInfoProvider = Provider.autoDispose<QiblaInfo?>((ref) {
  final loc = ref.watch(prayerTimesProvider.select((s) => s.location));
  if (loc == null) return null;
  const qibla = QiblaService();
  return QiblaInfo(
    bearing: qibla.bearing(loc.latitude, loc.longitude),
    distanceKm: qibla.distanceKm(loc.latitude, loc.longitude),
    city: loc.city,
  );
});

/// Correction from the compass's north to true north at the current place.
final magneticDeclinationProvider = FutureProvider.autoDispose<double>((ref) {
  final loc = ref.watch(prayerTimesProvider.select((s) => s.location));
  if (loc == null) return 0;
  return ref
      .watch(compassSourceProvider)
      .declination(loc.latitude, loc.longitude);
});

enum CompassStatus {
  /// Listening, no reading yet.
  starting,

  /// Readings are coming in.
  live,

  /// No magnetometer, or nothing arrived in time.
  unavailable,
}

class CompassState {
  const CompassState({
    this.status = CompassStatus.starting,
    this.heading,
    this.accuracy,
    this.noSensor = false,
    this.needsCalibration = false,
  });

  final CompassStatus status;

  /// Smoothed heading in the platform's reference (see
  /// [CompassReading.heading]); null until [CompassStatus.live].
  final double? heading;

  /// ± degrees from the platform, null when unknown.
  final double? accuracy;

  /// The phone said it has no magnetometer (rather than just staying quiet).
  final bool noSensor;

  /// Accuracy is poor or unknown: suggest the figure-8 calibration.
  final bool needsCalibration;
}

/// Smoothed compass readings while the Qibla screen is open. Auto-disposed
/// with the screen, which cancels the subscription and stops the sensors.
class CompassNotifier extends StateNotifier<CompassState> {
  CompassNotifier(
    this._source, {
    this.silence = const Duration(seconds: 4),
  }) : super(const CompassState()) {
    _start();
  }

  final CompassSource _source;

  /// How long to wait for a first reading before calling it unavailable.
  final Duration silence;

  /// Accuracy (± degrees) worse than this asks for calibration; it has to
  /// get to [_calibratedAccuracy] before the hint goes away, so the hint
  /// doesn't flicker around one value.
  static const double _poorAccuracy = 30;
  static const double _calibratedAccuracy = 20;

  final _filter = HeadingFilter();
  StreamSubscription<CompassReading>? _sub;
  Timer? _silenceTimer;

  Future<void> _start() async {
    final has = await _source.hasCompass();
    if (!mounted) return;
    if (has == false) {
      state =
          const CompassState(status: CompassStatus.unavailable, noSensor: true);
      return;
    }
    _silenceTimer = Timer(silence, () {
      if (mounted && state.status == CompassStatus.starting) {
        state = const CompassState(status: CompassStatus.unavailable);
      }
    });
    _sub = _source.readings().listen(_onReading, onError: (Object e) {
      if (mounted && state.status != CompassStatus.live) {
        state = const CompassState(status: CompassStatus.unavailable);
      }
    });
  }

  void _onReading(CompassReading r) {
    _silenceTimer?.cancel();
    final heading = _filter.add(r.heading);
    final prev = state;
    final accuracy = r.accuracy;
    final needsCalibration = prev.needsCalibration
        ? accuracy == null || accuracy > _calibratedAccuracy
        : accuracy == null || accuracy > _poorAccuracy;
    // Sub-degree noise after smoothing: not worth a rebuild.
    if (prev.status == CompassStatus.live &&
        signedDelta(prev.heading!, heading).abs() < 0.1 &&
        prev.accuracy == accuracy) {
      return;
    }
    state = CompassState(
      status: CompassStatus.live,
      heading: heading,
      accuracy: accuracy,
      needsCalibration: needsCalibration,
    );
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

final compassProvider =
    StateNotifierProvider.autoDispose<CompassNotifier, CompassState>(
        (ref) => CompassNotifier(ref.watch(compassSourceProvider)));
