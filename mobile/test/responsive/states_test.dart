// Responsive check of screens in their after-use states (see harness.dart).
import 'harness.dart';
import 'state_cases.dart';

void main() {
  for (final c in stateCases) {
    responsiveTest(c);
  }
}
