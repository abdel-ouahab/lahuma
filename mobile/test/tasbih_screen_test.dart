import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lahuma/features/adhkar/presentation/adhkar_providers.dart';
import 'package:lahuma/features/adhkar/domain/dhikr.dart';
import 'package:lahuma/core/design/app_theme.dart';
import 'package:lahuma/features/tasbih/presentation/screens/tasbih_screen.dart';
import 'package:lahuma/features/tasbih/presentation/tasbih_providers.dart';
import 'package:lahuma/features/tasbih/presentation/widgets/misbaha.dart';
import 'package:lahuma/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    String locale = 'ar',
    ThemeMode mode = ThemeMode.light,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        locale: Locale(locale),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: AppTheme.builder,
        home: const TasbihScreen(),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return container;
  }

  for (final (locale, mode, size) in [
    ('ar', ThemeMode.light, const Size(390, 844)),
    ('en', ThemeMode.dark, const Size(390, 844)),
    ('ar', ThemeMode.dark, const Size(320, 568)),
    ('ar', ThemeMode.light, const Size(820, 1180)),
  ]) {
    testWidgets(
        'renders and counts · $locale · ${mode.name} · ${size.width.round()}',
        (tester) async {
      final container =
          await pump(tester, locale: locale, mode: mode, size: size);
      expect(find.byType(Misbaha), findsOneWidget);

      await tester.tap(find.byType(Misbaha));
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(tasbihProvider).count, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reaching the target offers the next dhikr', (tester) async {
    final container = await pump(tester);
    for (var i = 0; i < 33; i++) {
      await tester.tap(find.byType(Misbaha));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('الذكر التالي'), findsOneWidget);

    // Taps right after the target are held back.
    await tester.tap(find.byType(Misbaha));
    expect(container.read(tasbihProvider).count, 33);

    await tester.tap(find.text('الذكر التالي'));
    // The card fades out, then leaves the tree on the next frame.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final state = container.read(tasbihProvider);
    expect(state.currentId, 'hamd');
    expect(state.countOf('subhan'), 0);
    expect(find.text('الذكر التالي'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the home tile follows the adhkar and opens the tasbih',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Home reads today's adhkar progress; none are loaded in tests.
    await tester.pumpWidget(ProviderScope(overrides: [
      adhkarProvider.overrideWith((ref) async => const AdhkarCollection({})),
    ], child: const LahumaApp()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));

    final tile = find.text('التسبيح');
    await tester.scrollUntilVisible(tile, 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.getTopLeft(tile).dy,
        greaterThan(tester.getTopLeft(find.text('أذكار المساء')).dy));

    // Clear of the floating tab bar; slowly, so it doesn't fling.
    await tester.timedDrag(find.byType(Scrollable).first, const Offset(0, -250),
        const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(tile);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(TasbihScreen), findsOneWidget);
  });

  testWidgets('undo and reset with confirmation', (tester) async {
    final container = await pump(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(Misbaha));
      await tester.pump(const Duration(milliseconds: 250));
    }

    await tester.tap(find.text('تراجع'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(container.read(tasbihProvider).count, 2);

    await tester.tap(find.text('تصفير'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'تصفير'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(container.read(tasbihProvider).count, 0);
    expect(tester.takeException(), isNull);
  });
}
