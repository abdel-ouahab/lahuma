import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lahuma/core/design/app_theme.dart';
import 'package:lahuma/core/design/design_system_preview.dart';

void main() {
  // The activity indicator spins forever, so pumpAndSettle never settles.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpPreview(
    WidgetTester tester, {
    String locale = 'ar',
    ThemeMode mode = ThemeMode.light,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: AppTheme.builder(context, child),
      ),
      scrollBehavior: AppTheme.scrollBehavior,
      home: const DesignSystemPreview(),
    ));
    await settle(tester);
  }

  Future<void> scrollThrough(WidgetTester tester) async {
    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 12; i++) {
      await tester.drag(list, const Offset(0, -500));
      await settle(tester);
    }
  }

  for (final locale in ['ar', 'en']) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('renders without errors · $locale · ${mode.name}',
          (tester) async {
        await pumpPreview(tester, locale: locale, mode: mode);
        expect(find.text('Design System'), findsWidgets);
        await scrollThrough(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('survives large text (Dynamic Type) in Arabic', (tester) async {
    await pumpPreview(tester, textScale: 1.6);
    await scrollThrough(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local toggles switch to dark / English', (tester) async {
    await pumpPreview(tester);
    await tester.tap(find.text('Dark'));
    await settle(tester);
    await tester.tap(find.text('English LTR'));
    await settle(tester);
    final ctx = tester.element(find.text('Typography'));
    expect(Directionality.of(ctx), TextDirection.ltr);
    expect(Theme.of(ctx).brightness, Brightness.dark);
  });

  testWidgets('overlays open and close', (tester) async {
    await pumpPreview(tester);
    Future<void> open(String label) async {
      final target = find.text(label);
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(target, 300, scrollable: scrollable);
      // Bring it out from under the pinned navigation bar.
      final y = tester.getCenter(target).dy;
      final mid = tester.getCenter(scrollable).dy;
      if (y < mid) await tester.drag(scrollable, Offset(0, mid - y));
      await settle(tester);
      await tester.tap(target);
      await settle(tester);
    }

    await open('Alert');
    expect(find.text('Delete note?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    await open('Action sheet');
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await settle(tester);

    await open('Bottom sheet');
    expect(find.text('Daily goal'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);

    await open('Page sheet');
    expect(find.text('Tafsir'), findsOneWidget);
    await tester.tap(find.text('تم'));
    await settle(tester);

    await open('Toast with action');
    expect(find.text('Bookmark removed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(find.text('Bookmark removed'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
