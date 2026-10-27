// Basic smoke test for Lahuma app.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lahuma/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Don't try to download fonts during tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('App starts on the splash screen and moves on to Home',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: LahumaApp()));
    await tester.pump(const Duration(milliseconds: 100));

    // MaterialApp.router builds a MaterialApp with a Router inside.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Router<Object>), findsOneWidget);
    expect(find.image(const AssetImage('assets/images/logo.png')),
        findsOneWidget);

    // Let the splash delay elapse and the route change settle.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('السلام عليكم'), findsOneWidget);
  });
}
