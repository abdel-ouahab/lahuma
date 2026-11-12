// Swiping through the introduction, traced in profile mode on a device.
// From mobile/:
//
//   flutter drive --profile --no-dds -d <device> \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/onboarding_perf_test.dart
//
// The timeline summary lands in build/perf/onboarding_swipe.timeline_summary.json
// (frame build / raster percentiles, missed frames).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lahuma/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:lahuma/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('onboarding swipe', (tester) async {
    // First run: the splash hands over to the introduction.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_completed_v1');
    await prefs.setString('settings.locale', 'arabic');

    await app.main();
    final end = DateTime.now().add(const Duration(seconds: 30));
    while (find.byType(OnboardingScreen).evaluate().isEmpty) {
      if (DateTime.now().isAfter(end)) throw TestFailure('No onboarding');
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 2));

    final pages = find.byType(PageView);
    final width = tester.getSize(pages).width;
    // A finger drag across most of the page, about as fast as people swipe.
    Future<void> swipe(double direction) async {
      await tester.timedDrag(pages, Offset(direction * width * 0.7, 0),
          const Duration(milliseconds: 280));
      await tester.pump(const Duration(milliseconds: 700));
    }

    await binding.traceAction(() async {
      // Arabic: the next page comes in from the left, so drag right.
      for (var i = 0; i < 6; i++) {
        await swipe(1);
      }
      for (var i = 0; i < 6; i++) {
        await swipe(-1);
      }
    }, reportKey: 'onboarding_swipe');
  });
}
