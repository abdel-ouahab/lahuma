// Responsive check of the second half of the sheets and dialogs.
import 'harness.dart';
import 'overlay_cases.dart';

void main() {
  for (final c in overlayCases.skip(overlayCases.length ~/ 2)) {
    responsiveTest(c);
  }
}
