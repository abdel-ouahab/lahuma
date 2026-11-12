// Responsive check of the screens outside the tab bar (see harness.dart).
import 'harness.dart';
import 'route_cases.dart';

void main() {
  for (final c in outsideShellCases) {
    responsiveTest(c);
  }
}
