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

  /// [duration], or zero when the user asked to reduce motion.
  static Duration of(BuildContext context, [Duration duration = standard]) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
          ? Duration.zero
          : duration;
}
