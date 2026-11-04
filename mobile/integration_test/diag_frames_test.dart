// TEMPORARY diagnostic (not committed): who schedules frames on idle Home.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lahuma/core/constants/storage_keys.dart';
import 'package:lahuma/features/fajr_call/presentation/fajr_call_providers.dart';
import 'package:lahuma/features/prayer_times/presentation/prayer_times_providers.dart';
import 'package:lahuma/features/fajr_call/domain/prayer_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lahuma/features/home/presentation/home_screen.dart';
import 'package:lahuma/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;

  testWidgets('diag', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.fajrCallPrayerSettings,
      jsonEncode(const PrayerSettings(
              latitude: 36.7538, longitude: 3.0588, placeName: 'Algiers')
          .toJson()),
    );
    await app.main();
    final end = DateTime.now().add(const Duration(seconds: 30));
    while (find.byType(HomeScreen).evaluate().isEmpty &&
        DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
        listen: false);
    for (var i = 0; i < 40; i++) {
      if (container.read(prayerTimesProvider).today != null) break;
      final s = container.read(prayerTimesProvider);
      // ignore: avoid_print
      print('DIAG state t=${i * 2}s loading=${s.loading} '
          'location=${s.location?.city} failure=${s.locationFailure} '
          'fetchFailed=${s.fetchFailed} today=${s.today != null} '
          'fajrReady=${container.read(fajrCallProvider).prayer.hasLocation}');
      await tester.pump(const Duration(seconds: 2));
    }
    var frames = 0;
    SchedulerBinding.instance.addPersistentFrameCallback((_) => frames++);
    final paints = <String, int>{};
    final builds = <String, int>{};
    debugProfilePaintsEnabled = true;
    debugOnProfilePaint = (ro) {
      final k = '${ro.runtimeType}'
          '${ro is RenderCustomPaint ? '(${ro.painter?.runtimeType})' : ''}';
      paints[k] = (paints[k] ?? 0) + 1;
    };
    debugOnRebuildDirtyWidget = (e, builtOnce) {
      final k = '${e.widget.runtimeType}';
      builds[k] = (builds[k] ?? 0) + 1;
    };
    // Capture "who marked paint / who asked for a frame" stacks in memory.
    final origins = <String, int>{};
    final oldPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      final m = message ?? '';
      final lines = m.split('\n');
      final kind = m.contains('markNeedsPaint')
          ? 'PAINT'
          : m.contains('scheduleFrame')
              ? 'FRAME'
              : null;
      if (kind == null) return;
      final origin = lines.firstWhere(
          (l) =>
              l.contains('package:lahuma') ||
              l.contains('animation/') ||
              l.contains('ticker.dart') ||
              l.contains('image_stream') ||
              l.contains('_ScrollPosition') ||
              l.contains('scroll_position'),
          orElse: () => lines.length > 4 ? lines[4] : m);
      final k = '$kind ${origin.replaceAll(RegExp(r'^#\d+\s+'), '').trim()}';
      origins[k] = (origins[k] ?? 0) + 1;
    };
    debugPrintMarkNeedsPaintStacks = true;
    debugPrintScheduleFrameStacks = true;
    await tester.pump(const Duration(seconds: 3));
    debugPrintMarkNeedsPaintStacks = false;
    debugPrintScheduleFrameStacks = false;
    debugPrint = oldPrint;
    final topO = origins.entries.toList()..sort((a, b) => b.value - a.value);
    // ignore: avoid_print
    for (final e in topO.take(20)) print('DIAG ORIGIN ${e.value} ${e.key}');
    debugProfilePaintsEnabled = false;
    debugOnProfilePaint = null;
    debugOnRebuildDirtyWidget = null;
    final topP = paints.entries.toList()..sort((a, b) => b.value - a.value);
    final topB = builds.entries.toList()..sort((a, b) => b.value - a.value);
    // ignore: avoid_print
    for (final e in topP.where((e) => e.key.contains("(") || e.key.contains("Repaint") || e.key.contains("Opacity") || e.key.contains("Image") || e.key.contains("Animated"))) print('DIAG PAINT ${e.value} ${e.key}');
    // ignore: avoid_print
    for (final e in topB.take(15)) print('DIAG BUILD ${e.value} ${e.key}');
    // ignore: avoid_print
    print('DIAG frames in 3s: $frames');
    void visit(Element e) {
      if (e is StatefulElement) {
        final props = e.state.toDiagnosticsNode().getProperties();
        for (final p in props) {
          final d = p.toDescription();
          if ((p.name == 'ticker' || p.name == 'tickers') &&
              d.contains('active') &&
              !d.contains('inactive')) {
            // ignore: avoid_print
            print('DIAG ACTIVE ${e.widget.runtimeType} -> $d');
          }
        }
      }
      e.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement!.visitChildren(visit);
  });
}
