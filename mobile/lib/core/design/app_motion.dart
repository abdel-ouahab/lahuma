import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Lahuma design tokens — motion.
class AppMotion {
  AppMotion._();

  /// Spring tuned like Apple's UI springs: critically damped, response 0.3 s.
  /// stiffness = (2π / response)², damping = 4π·ζ / response (mass 1).
  static const SpringDescription spring = SpringDescription(
    mass: 1,
    stiffness: 439,
    damping: 41.9,
  );

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 600);

  static const Curve curve = Curves.easeOutCubic;

  /// [spring] as a curve over [duration], for one segment of a timeline
  /// driven by a single controller. Critically damped: it never overshoots.
  static Curve springCurve(Duration duration) => _SpringCurve(duration);

  /// [duration], or zero when the user asked to reduce motion.
  static Duration of(BuildContext context, [Duration duration = standard]) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
          ? Duration.zero
          : duration;
}

class _SpringCurve extends Curve {
  const _SpringCurve(this.duration);

  final Duration duration;

  @override
  double transformInternal(double t) =>
      SpringSimulation(AppMotion.spring, 0, 1, 0)
          .x(t * duration.inMicroseconds / Duration.microsecondsPerSecond);
}
