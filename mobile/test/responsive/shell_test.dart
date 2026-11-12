// Responsive check of the screens inside the tab shell (see harness.dart).
import 'harness.dart';
import 'route_cases.dart';

void main() {
  for (final c in shellCases) {
    responsiveTest(c);
  }
}
