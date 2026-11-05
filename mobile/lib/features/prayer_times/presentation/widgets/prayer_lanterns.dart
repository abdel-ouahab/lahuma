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
/// stops whenever both are at rest, and the accelerometer is only read
/// while the lanterns are on screen and the app is in the foreground.
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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
  bool _visible = true;
  bool _resumed = true;
  double _target = 0;
  double _vShort = 0;
  double _vLong = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _resumed = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    // False while another route covers Home or its tab is in the background.
    _visible = TickerMode.valuesOf(context).enabled;
    if (_still) {
      _ticker.stop();
      _vShort = _vLong = 0;
      _sway.set(0, 0);
    }
    _listen();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _listen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gravity?.cancel();
    _ticker.dispose();
    _sway.dispose();
    super.dispose();
  }

  /// Reads the accelerometer only while the lanterns can be seen, so a
  /// covered Home or a backgrounded app doesn't keep the sensor running.
  void _listen() {
    final want = !_still && _visible && _resumed;
    if (want && _gravity == null) {
      _gravity = ref.read(screenGravityProvider).listen(_onGravity);
    } else if (!want && _gravity != null) {
      _gravity!.cancel();
      _gravity = null;
    }
  }

  bool _resting(double angle, double v) =>
      (angle - _target).abs() < 1e-3 && v.abs() < 1e-3;

  void _onGravity(double angle) {
    if (_still) return;
    // Smooth the sensor's jitter before it becomes the pendulums' target.
    _target += (angle.clamp(-_maxAngle, _maxAngle) - _target) * 0.35;
    if (_ticker.isActive) return;
    // A phone held still sends the same reading over and over: nothing to
    // swing, so no frame.
    if (_resting(_sway.shortChain, _vShort) &&
        _resting(_sway.longChain, _vLong)) {
      return;
    }
    _last = Duration.zero;
    _ticker.start();
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

    if (_resting(short, _vShort) && _resting(long, _vLong)) _ticker.stop();
  }

  // The boundaries keep a swing from repainting the card under the lanterns
  // and the rest of Home with them.
  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: PrayerLanternsPainter(
            gold: widget.gold,
            glow: widget.glow,
            sway: _sway,
          ),
          child: RepaintBoundary(child: widget.child),
        ),
      );
}
