import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lahuma/core/design/design.dart'
    show AppColors, DrawnStarPainter;
import 'package:lahuma/features/adhkar/domain/dhikr.dart';
import 'package:lahuma/features/adhkar/presentation/adhkar_providers.dart';
import 'package:lahuma/features/home/presentation/home_screen.dart';
import 'package:lahuma/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:lahuma/features/splash/bootstrap.dart';
import 'package:lahuma/features/splash/splash_screen.dart';
import 'package:lahuma/features/tasbih/presentation/screens/tasbih_screen.dart';
import 'package:lahuma/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _seen = {'onboarding_completed_v1': true};

Future<void> _launch(WidgetTester tester,
    {List<Override> overrides = const []}) async {
  await tester.pumpWidget(ProviderScope(overrides: [
    // Home reads today's adhkar progress; none are loaded in tests.
    adhkarProvider.overrideWith((ref) async => const AdhkarCollection({})),
    ...overrides,
  ], child: const LahumaApp()));
}

/// Pumps [total] in 100 ms frames, so timers and transitions run.
Future<void> _wait(WidgetTester tester, Duration total) async {
  for (var t = Duration.zero;
      t < total;
      t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

DrawnStarPainter _star(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((p) => p.painter)
    .whereType<DrawnStarPainter>()
    .single;

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('the first frame is the native launch screen', (tester) async {
    SharedPreferences.setMockInitialValues(_seen);
    await _launch(tester);
    await tester.pump();

    // The gold wordmark, 160 pt wide, dead centre, on the launch colour…
    final wordmark = find.image(const AssetImage(SplashLayout.wordmarkAsset));
    expect(
      tester.getRect(wordmark),
      Rect.fromCenter(
        center: tester.getCenter(find.byType(SplashScreen)),
        width: SplashLayout.wordmarkWidth,
        height: SplashLayout.wordmarkWidth * SplashLayout.wordmarkAspect,
      ),
    );
    final background = tester
        .widgetList<ColoredBox>(find.descendant(
            of: find.byType(SplashScreen), matching: find.byType(ColoredBox)))
        .first
        .color;
    expect(background.toARGB32(), AppColors.splashBackground.color.toARGB32());
    // …and nothing else yet: the star has not started drawing.
    expect(_star(tester).progress.value, 0);
    await _wait(tester, const Duration(seconds: 3));
  });

  testWidgets('the first launch opens the introduction', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _launch(tester);
    await _wait(tester, const Duration(milliseconds: 1500));
    // Still on the splash while its animation runs.
    expect(find.byType(SplashScreen), findsOneWidget);
    await _wait(tester, const Duration(seconds: 1));
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('later launches open Home', (tester) async {
    SharedPreferences.setMockInitialValues(_seen);
    await _launch(tester);
    await _wait(tester, const Duration(milliseconds: 2500));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('a launch from a notification skips the introduction',
      (tester) async {
    // First launch, but the Fajr wake list or an adhan is waiting.
    SharedPreferences.setMockInitialValues({});
    await _launch(tester,
        overrides: [launchRouteProvider.overrideWithValue(TasbihScreen.path)]);
    await _wait(tester, const Duration(milliseconds: 3000));
    expect(find.byType(TasbihScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    // Home is underneath, for "back".
    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
    // The introduction still waits for an ordinary launch.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_completed_v1'), isNull);
  });

  testWidgets('a stuck start-up still leaves after five seconds',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final never = Completer<BootstrapResult>();
    await _launch(tester, overrides: [
      bootstrapProvider.overrideWith((ref) => never.future),
    ]);
    await _wait(tester, const Duration(milliseconds: 4500));
    expect(find.byType(SplashScreen), findsOneWidget);
    await _wait(tester, const Duration(milliseconds: 1500));
    // Unknown whether the introduction was seen: Home, never a trap.
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Reduce Motion: the last frame at once, then straight on',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    SharedPreferences.setMockInitialValues(_seen);
    await _launch(tester);
    await tester.pump();
    expect(_star(tester).progress.value, 1);

    // Start-up is quick here: no 1.6 s wait for an animation nobody sees.
    await _wait(tester, const Duration(milliseconds: 600));
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
