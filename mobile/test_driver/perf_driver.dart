// Host side of integration_test/perf_test.dart: writes one timeline summary
// per scenario (frame build / raster average, 90th and 99th percentiles,
// missed frames) and the plain metrics to build/perf/.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

const String _outDir = 'build/perf';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data == null) return;
      await Directory(_outDir).create(recursive: true);
      for (final entry in data.entries) {
        if (entry.key == 'metrics') {
          await File('$_outDir/metrics.json').writeAsString(
              const JsonEncoder.withIndent('  ').convert(entry.value));
          continue;
        }
        final timeline = driver.Timeline.fromJson(
            Map<String, dynamic>.from(entry.value as Map));
        await driver.TimelineSummary.summarize(timeline).writeTimelineToFile(
          entry.key,
          destinationDirectory: _outDir,
          pretty: true,
          includeSummary: true,
        );
      }
    },
  );
}
