// Responsive check of the first half of the sheets and dialogs.
import 'harness.dart';
import 'overlay_cases.dart';

void main() {
  for (final c in overlayCases.take(overlayCases.length ~/ 2)) {
    responsiveTest(c);
  }
}
