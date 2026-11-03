import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lahuma/core/design/app_theme.dart';
import 'package:lahuma/core/notifications/local_notifications.dart';
import 'package:lahuma/features/khatma/data/khatma_notifications.dart';
import 'package:lahuma/features/khatma/domain/khatma.dart';
import 'package:lahuma/features/khatma/presentation/khatma_providers.dart';
import 'package:lahuma/features/khatma/presentation/screens/khatma_complete_screen.dart';
import 'package:lahuma/features/khatma/presentation/screens/khatma_screen.dart';
import 'package:lahuma/features/khatma/presentation/screens/khatma_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    now = DateTime(2026, 11, 1, 8);
  });

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget screen, {
    String locale = 'ar',
    ThemeMode mode = ThemeMode.light,
    Size size = const Size(390, 844),
    Future<void> Function(KhatmaNotifier n)? setup,
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      khatmaClockProvider.overrideWithValue(() => now),
      khatmaNotificationsProvider.overrideWithValue(_SilentNotifications()),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(khatmaProvider.notifier);
    // Prefs mocks complete in microtasks, so pumping runs the setup in
    // the test's fake-async zone (runAsync would deadlock on its futures).
    var done = false;
    notifier.ready
        .then((_) => setup?.call(notifier))
        .whenComplete(() => done = true);
    for (var i = 0; !done && i < 100; i++) {
      await tester.pump();
    }
    expect(done, isTrue);
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
        home: screen,
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return container;
  }

  Future<void> start(KhatmaNotifier n) => n.create(
        endDate: DateTime(2026, 11, 30),
        startPage: 1,
        displayUnit: ReadingUnit.juz,
        morningEnabled: true,
        morningMinutes: 7 * 60,
        eveningEnabled: true,
        eveningMinutes: 21 * 60,
      );

  testWidgets('without a khatma it invites to start one', (tester) async {
    await pump(tester, const KhatmaScreen());
    expect(find.text('ابدأ ختمة جديدة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (locale, mode, size) in [
    ('ar', ThemeMode.light, const Size(390, 844)),
    ('en', ThemeMode.dark, const Size(390, 844)),
    ('ar', ThemeMode.dark, const Size(320, 568)),
  ]) {
    testWidgets(
        'active khatma · $locale · ${mode.name} · ${size.width.round()}',
        (tester) async {
      final container = await pump(tester, const KhatmaScreen(),
          locale: locale, mode: mode, size: size, setup: start);
      expect(find.text(locale == 'ar' ? 'ورد اليوم' : "Today's portion"),
          findsOneWidget);

      final plusPage = find.text(locale == 'ar' ? '+ صفحة' : '+1 page');
      await tester.scrollUntilVisible(plusPage, 120,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(plusPage);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(plusPage);
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(khatmaProvider).active!.lastPageRead, 1);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
    });
  }

  testWidgets('paused and overdue states render', (tester) async {
    await pump(tester, const KhatmaScreen(), setup: (n) async {
      await start(n);
      await n.pause();
    });
    expect(find.text('الختمة متوقفة مؤقتًا'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('past the end date offers to extend', (tester) async {
    await pump(tester, const KhatmaScreen(), setup: (n) async {
      await start(n);
      now = DateTime(2026, 12, 3, 8);
      await n.refresh();
    });
    expect(find.text('انتهت المدة ولم تكتمل الختمة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['ar', 'en']) {
    testWidgets('setup screen shows a live preview · $locale', (tester) async {
      await pump(tester, const KhatmaSetupScreen(), locale: locale);
      expect(
          find.textContaining(
              locale == 'ar' ? 'ستقرأ نحو 21 صفحة' : "You'll read about 21"),
          findsOneWidget);
      await tester.tap(find.text(locale == 'ar' ? '7 أيام' : '7 days'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
          find.textContaining(
              locale == 'ar' ? 'ستقرأ نحو 87 صفحة' : "You'll read about 87"),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('edit screen opens on the active plan', (tester) async {
    await pump(tester, const KhatmaSetupScreen(edit: true), setup: start);
    expect(find.text('تعديل الختمة'), findsOneWidget);
    expect(find.text('نقطة البداية'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['ar', 'en']) {
    testWidgets('completion screen · $locale', (tester) async {
      late String id;
      await pump(tester, const SizedBox(), setup: (n) async {
        await start(n);
        await n.reachPage(604);
      });
      final container = ProviderScope.containerOf(
          tester.element(find.byType(SizedBox).first));
      id = container.read(khatmaProvider).history.single.id;
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: Locale(locale),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: AppTheme.builder,
          home: KhatmaCompleteScreen(id: id),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
          find.text(locale == 'ar'
              ? 'مبارك! أتممت ختمة القرآن'
              : 'Congratulations! You completed the Quran'),
          findsOneWidget);
      expect(find.text(KhatmaCompleteScreen.dua), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _SilentNotifications extends KhatmaNotifications {
  _SilentNotifications() : super(LocalNotifications());

  @override
  Future<void> sync(Khatma? khatma,
      {required DateTime now, required bool arabic}) async {}
}
