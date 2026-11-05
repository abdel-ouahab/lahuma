import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/notifications/notification_providers.dart';
import '../prayer_times/presentation/prayer_times_providers.dart';
import '../settings/presentation/settings_providers.dart';

/// What the splash needs to know before it leaves.
@immutable
class BootstrapResult {
  const BootstrapResult({
    required this.onboardingCompleted,
    required this.launchRoute,
  });

  /// False on the first launch: the introduction comes before Home.
  final bool onboardingCompleted;

  /// The screen a tapped notification (the Fajr wake list, an adhan) opened
  /// the app for; it goes on top of Home and the introduction waits.
  final String? launchRoute;
}

/// How long the splash stays. It leaves when the bootstrap is done and
/// [minimum] has passed (so its animation finishes), or after [maximum]
/// whatever the bootstrap is doing.
class SplashTiming {
  SplashTiming._();

  static const Duration minimum = Duration(milliseconds: 1600);
  static const Duration maximum = Duration(seconds: 5);

  /// The content fading out before the next screen.
  static const Duration exit = Duration(milliseconds: 250);
}

/// The route a tapped notification launched the app with. Taken from
/// [localNotificationsProvider] once and kept, so the bootstrap and the
/// splash's timeout fallback see the same value.
final launchRouteProvider = Provider<String?>(
    (ref) => ref.read(localNotificationsProvider).takeLaunchRoute());

/// The app's start-up work before Home: the saved theme and language (so
/// the first screen isn't drawn in the wrong ones), whether the
/// introduction was seen, the cached prayer times (so Home opens with
/// them) and the notification launch route. Nothing here waits on the
/// network or asks for a permission. A step that fails is logged and the
/// rest carry on.
final bootstrapProvider = FutureProvider<BootstrapResult>((ref) async {
  final launchRoute = ref.read(launchRouteProvider);
  final repository = ref.read(settingsRepositoryProvider);

  Future<void> step(String name, Future<void> Function() run) async {
    try {
      await run();
    } catch (error, stack) {
      debugPrint('bootstrap: $name failed: $error\n$stack');
    }
  }

  // A stuck or broken read counts as seen: never trap someone in the
  // introduction because the settings could not be read.
  var onboardingCompleted = true;
  await Future.wait([
    step('theme', () => ref.read(themeModeProvider.notifier).ready),
    step('locale', () => ref.read(localeOptionProvider.notifier).ready),
    step('prayer times cache',
        () => ref.read(prayerTimesProvider.notifier).cacheLoaded),
    step('onboarding flag', () async {
      onboardingCompleted = await repository.getOnboardingCompleted();
    }),
  ]);
  return BootstrapResult(
    onboardingCompleted: onboardingCompleted,
    launchRoute: launchRoute,
  );
});

/// Waits for [bootstrap] and [minimum] together. A bootstrap slower than
/// [maximum], or one that throws, gives way to [fallback].
Future<BootstrapResult> splashGate(
  Future<BootstrapResult> bootstrap, {
  required Duration minimum,
  required Duration maximum,
  required BootstrapResult Function() fallback,
}) async {
  final settled = bootstrap.timeout(maximum, onTimeout: () {
    debugPrint('bootstrap: still running after $maximum, carrying on');
    return fallback();
  }).catchError((Object error, StackTrace stack) {
    debugPrint('bootstrap failed: $error\n$stack');
    return fallback();
  });
  final results = await Future.wait<Object?>([
    settled,
    if (minimum > Duration.zero) Future<void>.delayed(minimum),
  ]);
  return results.first! as BootstrapResult;
}
