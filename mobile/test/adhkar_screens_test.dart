import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lahuma/core/design/app_theme.dart';
import 'package:lahuma/core/router/app_router.dart';
import 'package:lahuma/features/adhkar/data/adhkar_service.dart';
import 'package:lahuma/features/adhkar/domain/dhikr.dart';
import 'package:lahuma/features/adhkar/presentation/adhkar_providers.dart';
import 'package:lahuma/features/adhkar/presentation/screens/adhkar_reader_screen.dart';
import 'package:lahuma/features/adhkar/presentation/screens/adhkar_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/adhkar_fakes.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// Offline device; [cached] decides whether adhkar were fetched before.
  AdhkarService offlineService({required bool cached}) => AdhkarService(
        dio: Dio()
          ..httpClientAdapter =
              FakeAdapter(error: DioExceptionType.connectionError),
        cache: MemoryCache(cached ? fixture : null),
      );

  Future<ProviderContainer> pump(WidgetTester tester, Widget home,
      {required AdhkarService service, String locale = 'ar'}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
        overrides: [adhkarServiceProvider.overrideWithValue(service)]);
    addTearDown(container.dispose);
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
        home: home,
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return container;
  }

  final morning = AdhkarService.parse(fixture).of(AdhkarPeriod.morning);
  final evening = AdhkarService.parse(fixture).of(AdhkarPeriod.evening);

  testWidgets('list shows morning adhkar from the cache, then evening',
      (tester) async {
    await pump(tester, const AdhkarScreen(initialTab: AdhkarTab.morning),
        service: offlineService(cached: true));

    expect(find.text(morning.first.text), findsOneWidget);
    expect(find.text('0 / 25'), findsOneWidget);

    await tester.tap(find.text('المساء'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(evening.first.text), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline first launch explains and offers a retry',
      (tester) async {
    await pump(tester, const AdhkarScreen(initialTab: AdhkarTab.morning),
        service: offlineService(cached: false));

    expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  testWidgets('favorites tab is empty until a dhikr is bookmarked',
      (tester) async {
    await pump(tester, const AdhkarScreen(initialTab: AdhkarTab.favorites),
        service: offlineService(cached: true));
    expect(find.text('لا توجد أذكار مفضلة'), findsOneWidget);

    await tester.tap(find.text('الصباح'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byIcon(CupertinoIcons.bookmark).first);
    await tester.tap(find.text('المفضلة'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(morning.first.text), findsOneWidget);
    expect(find.text('لا توجد أذكار مفضلة'), findsNothing);
    // Let the rows' entrance animations (flutter_animate timers) finish.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('reader counts to the required count, then moves on',
      (tester) async {
    // Index 2 (رضيت بالله ربا…) is said 3 times.
    final container = await pump(tester,
        const AdhkarReaderScreen(period: AdhkarPeriod.morning, initialIndex: 2),
        service: offlineService(cached: true));
    expect(find.text(morning[2].text), findsOneWidget);

    final counter = find.bySemanticsLabel('عدّاد الذكر');
    for (var i = 0; i < 3; i++) {
      await tester.tap(counter);
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(container.read(adhkarProgressProvider).countOf('morning-2'), 3);
    expect(container
        .read(adhkarCompletionsProvider)
        .countOf(AdhkarPeriod.morning), 1);

    // Extra taps on a completed dhikr don't count.
    await tester.tap(counter, warnIfMissed: false);
    expect(container.read(adhkarProgressProvider).countOf('morning-2'), 3);

    // Auto-advance to the next dhikr.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(morning[3].text), findsOneWidget);
    expect(find.textContaining('4 / 25'), findsOneWidget);
  });

  testWidgets('reader previous / next buttons navigate and bound',
      (tester) async {
    await pump(tester, const AdhkarReaderScreen(period: AdhkarPeriod.evening),
        service: offlineService(cached: true), locale: 'en');
    expect(find.text(evening[0].text), findsOneWidget);
    expect(find.text('Dhikr 1 of 25'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Dhikr 2 of 25'), findsOneWidget);

    await tester.tap(find.text('Previous'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Dhikr 1 of 25'), findsOneWidget);
  });

  test('routes resolve', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final config = container.read(routerProvider).configuration;
    expect(config.findMatch(Uri.parse('/home/adhkar?tab=evening')).fullPath,
        '/home/adhkar');
    expect(config.findMatch(Uri.parse('/adhkar/morning?index=3')).fullPath,
        '/adhkar/:period(morning|evening)');
    expect(config.findMatch(Uri.parse('/adhkar/night')).matches, isEmpty);
  });
}
