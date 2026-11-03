import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../../../core/design/design.dart';
import 'prayer_painters.dart';

/// Which way "down" is on the screen, in radians clockwise from straight
/// down the screen, from the accelerometer. 0 while the phone lies flat
/// (no clear down). Empty where there is no phone accelerometer (tests,
/// desktop).
final screenGravityProvider = Provider<Stream<double>>((ref) {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
    return const Stream.empty();
  }
  return accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
      .map((e) =>
          math.sqrt(e.x * e.x + e.y * e.y) < 2.5 ? 0.0 : math.atan2(e.x, e.y))
      .handleError((Object _) {});
});

/// Paints the Ramadan lanterns behind [child] and swings them as the phone
/// tilts: each is a damped pendulum pulled towards hanging plumb, the
/// shorter chain a little quicker. Still under Reduce Motion; the ticker
/// stops whenever both are at rest.
class PrayerLanterns extends ConsumerStatefulWidget {
  const PrayerLanterns({
    super.key,
    required this.gold,
    required this.glow,
    required this.child,
  });

  final Color gold;
  final double glow;
  final Widget child;

  @override
  ConsumerState<PrayerLanterns> createState() => _PrayerLanternsState();
}

class _PrayerLanternsState extends ConsumerState<PrayerLanterns>
    with SingleTickerProviderStateMixin {
  /// Pull back to plumb (rad/s² per rad) for each chain length.
  static const double _stiffShort = 30;
  static const double _stiffLong = 20;
  static const double _damping = 1.8;

  /// Furthest they swing either way, so they stay inside the card.
  static const double _maxAngle = 0.45;

  final _sway = LanternSway();
  late final Ticker _ticker = createTicker(_step);
  StreamSubscription<double>? _gravity;
  bool _still = false;
  double _target = 0;
  double _vShort = 0;
  double _vLong = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _gravity = ref.read(screenGravityProvider).listen(_onGravity);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _ticker.stop();
      _vShort = _vLong = 0;
      _sway.set(0, 0);
    }
  }

  @override
  void dispose() {
    _gravity?.cancel();
    _ticker.dispose();
    _sway.dispose();
    super.dispose();
  }

  void _onGravity(double angle) {
    if (_still) return;
    // Smooth the sensor's jitter before it becomes the pendulums' target.
    _target += (angle.clamp(-_maxAngle, _maxAngle) - _target) * 0.35;
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _step(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;

    double swing(double angle, double stiffness, double v) =>
        v + (-stiffness * (angle - _target) - _damping * v) * dt;
    _vShort = swing(_sway.shortChain, _stiffShort, _vShort);
    _vLong = swing(_sway.longChain, _stiffLong, _vLong);
    final short = (_sway.shortChain + _vShort * dt)
        .clamp(-_maxAngle, _maxAngle)
        .toDouble();
    final long =
        (_sway.longChain + _vLong * dt).clamp(-_maxAngle, _maxAngle).toDouble();
    _sway.set(short, long);

    bool resting(double angle, double v) =>
        (angle - _target).abs() < 1e-3 && v.abs() < 1e-3;
    if (resting(short, _vShort) && resting(long, _vLong)) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: PrayerLanternsPainter(
          gold: widget.gold,
          glow: widget.glow,
          sway: _sway,
        ),
        child: widget.child,
      );
}
