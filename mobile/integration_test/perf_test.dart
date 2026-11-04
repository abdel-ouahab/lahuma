// Performance scenarios, run in profile mode on a device, from mobile/:
//
//   integration_test/run_perf.sh [device-id]
//
// which runs `flutter drive --profile --no-dds` (`traceAction` connects to
// the VM service itself) and grants location permission once the app is
// installed, since a test can't answer the system prompt.
//
// Each scenario is traced with `traceAction`; the driver turns every trace
// into a timeline summary (frame build / raster percentiles, missed frames)
// under build/perf/. See docs/perf-audit.md.
//
// The Quran list, the reader and the reciters need the network (or a warm
// cache), as in normal use.
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lahuma/core/constants/storage_keys.dart';
import 'package:lahuma/core/router/app_router.dart';
import 'package:lahuma/features/fajr_call/domain/prayer_settings.dart';
import 'package:lahuma/features/prayer_times/presentation/prayer_times_providers.dart';
import 'package:lahuma/features/bookmarks/presentation/screens/bookmarks_screen.dart';
import 'package:lahuma/features/home/presentation/home_screen.dart';
import 'package:lahuma/features/mp3quran/presentation/mp3quran_reciters_screen.dart';
import 'package:lahuma/features/quran/mushaf/presentation/screens/mushaf_screen.dart';
import 'package:lahuma/features/quran/presentation/screens/surah_list_screen.dart';
import 'package:lahuma/features/quran/presentation/screens/surah_reading_screen.dart';
import 'package:lahuma/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Every frame the app asks for is drawn, as on a real run, so idle
  // animations and timers show up in the traces.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('performance scenarios', (tester) async {
    final metrics = <String, Object>{};

    // A fixed city, so Home shows the real countdown (an emulator has no
    // location fix, and Home would stay on its loading skeleton).
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.fajrCallPrayerSettings,
      jsonEncode(const PrayerSettings(
        latitude: 36.7538,
        longitude: 3.0588,
        placeName: 'Algiers',
      ).toJson()),
    );

    // ── Startup: main() to Home on screen (includes the splash). ─────────
    final startup = Stopwatch()..start();
    await binding.traceAction(() async {
      await app.main();
      await _pumpUntil(tester, find.byType(HomeScreen));
    }, reportKey: 'startup');
    metrics['startup_to_home_ms'] = startup.elapsedMilliseconds;

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
      listen: false,
    );
    final router = container.read(routerProvider);

    // ── Home left alone: countdown, lanterns, anything else running. ─────
    // GPS is tried first and gives up after 20 s on a device with no fix.
    final loaded = DateTime.now().add(const Duration(seconds: 60));
    while (container.read(prayerTimesProvider).today == null) {
      if (DateTime.now().isAfter(loaded)) {
        throw TestFailure('Prayer times never loaded');
      }
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump(const Duration(seconds: 2));
    await binding.traceAction(() async {
      await tester.pump(const Duration(seconds: 10));
    }, reportKey: 'home_idle');

    // ── Home scrolled fast, up and down. ──────────────────────────────────
    await binding.traceAction(() async {
      await _flingUpAndDown(tester, _scrollableIn(HomeScreen));
    }, reportKey: 'home_scroll');

    // ── The most used screens, one after another. ─────────────────────────
    await binding.traceAction(() async {
      await _goAndWait(tester, () => router.go('/quran'), SurahListScreen);
      await _goAndWait(
          tester, () => router.push(MushafScreen.path), MushafScreen);
      await tester.pump(const Duration(seconds: 2));
      router.pop();
      await tester.pump(const Duration(seconds: 1));
      await _goAndWait(tester, () => router.go('/bookmarks'), BookmarksScreen);
      await _goAndWait(tester, () => router.go('/home'), HomeScreen);
    }, reportKey: 'navigation');

    // ── Surah list scrolled fast. ─────────────────────────────────────────
    await _goAndWait(tester, () => router.go('/quran'), SurahListScreen);
    await tester.pump(const Duration(seconds: 3)); // the list loads
    await binding.traceAction(() async {
      await _flingUpAndDown(tester, _scrollableIn(SurahListScreen));
    }, reportKey: 'surah_list_scroll');

    // ── Reader: Al-Baqarah, the longest surah, scrolled fast. ─────────────
    await _goAndWait(
        tester, () => router.push('/quran/2'), SurahReadingScreen);
    await tester.pump(const Duration(seconds: 4)); // text loads
    await binding.traceAction(() async {
      await _flingUpAndDown(tester, _scrollableIn(SurahReadingScreen));
    }, reportKey: 'reader_scroll');
    router.pop();
    await tester.pump(const Duration(seconds: 1));

    // ── Image-heavy: the reciters list with their photos. ─────────────────
    await binding.traceAction(() async {
      await _goAndWait(tester, () => router.go('/quran/mp3quran'),
          Mp3QuranRecitersScreen);
      await tester.pump(const Duration(seconds: 5)); // list + photos load
      await _flingUpAndDown(tester, _scrollableIn(Mp3QuranRecitersScreen));
    }, reportKey: 'reciters_images');

    binding.reportData ??= <String, dynamic>{};
    binding.reportData!['metrics'] = metrics;
  });
}

/// Pumps (real time, live binding) until [finder] matches something.
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      throw TestFailure('Timed out waiting for $finder');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _goAndWait(
    WidgetTester tester, void Function() go, Type screen) async {
  go();
  await _pumpUntil(tester, find.byType(screen));
  await tester.pump(const Duration(milliseconds: 600)); // the transition
}

/// The first scrollable inside [screen].
Finder _scrollableIn(Type screen) => find
    .descendant(of: find.byType(screen), matching: find.byType(Scrollable))
    .first;

/// Three fast flings down and back up, letting each one settle.
Future<void> _flingUpAndDown(WidgetTester tester, Finder scrollable) async {
  for (var i = 0; i < 3; i++) {
    await tester.fling(scrollable, const Offset(0, -700), 4000);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.fling(scrollable, const Offset(0, 700), 4000);
    await tester.pump(const Duration(milliseconds: 1200));
  }
}
