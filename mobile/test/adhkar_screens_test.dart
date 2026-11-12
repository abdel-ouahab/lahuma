import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lahuma/core/design/app_theme.dart';
import 'package:lahuma/core/router/app_router.dart';
import 'package:lahuma/features/adhkar/data/adhkar_progress_repository.dart';
import 'package:lahuma/features/adhkar/data/adhkar_service.dart';
import 'package:lahuma/features/adhkar/domain/dhikr.dart';
import 'package:lahuma/features/adhkar/presentation/adhkar_providers.dart';
import 'package:lahuma/features/adhkar/presentation/screens/adhkar_category_screen.dart';
import 'package:lahuma/features/adhkar/presentation/screens/adhkar_screen.dart';
import 'package:lahuma/features/quran/mushaf/domain/mushaf_meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

final String bundled = File('assets/data/adhkar.json').readAsStringSync();
final AdhkarCollection collection =
    AdhkarService.parse(bundled, verse: MushafMeta.ayahText);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<ProviderContainer> pump(WidgetTester tester, Widget home,
      {ProviderContainer? reuse, String locale = 'ar'}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = reuse ??
        ProviderContainer(overrides: [
          adhkarServiceProvider.overrideWithValue(AdhkarService(
              load: () async => bundled, verse: MushafMeta.ayahText)),
        ]);
    if (reuse == null) addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        key: UniqueKey(),
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

  /// Lets the move to the next card finish (it scrolls over several frames).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the tab shows the hour\'s collection, then grouped categories',
      (tester) async {
    await pump(tester, AdhkarScreen(now: () => DateTime(2026, 11, 8, 20)));
    expect(find.text('الأذكار والأدعية'), findsWidgets);
    expect(find.text('وقت أذكار المساء'), findsOneWidget);
    expect(find.text('اليوم والليلة'), findsOneWidget);
    expect(find.text('أذكار بعد الصلاة'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('دعاء السفر'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('السفر'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('أدعية نبوية جامعة'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('11 ذكرًا'.replaceAll('11', '\u206611\u2069')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a card counts it down, then moves on', (tester) async {
    final container = await pump(
        tester, const AdhkarCategoryScreen(categoryId: 'after_prayer'));
    final items = collection.category('after_prayer')!.items;
    expect(find.text(items.first.text), findsOneWidget);
    expect(find.bySemanticsLabel('أتممت 0 من ${items.length}'), findsOneWidget);

    // The first one is said once.
    await tester.tap(find.text(items.first.text));
    await tester.pump(const Duration(milliseconds: 50));
    expect(container.read(adhkarProgressProvider).countOf(items.first.id), 1);
    expect(find.bySemanticsLabel('أتممت 1 من ${items.length}'), findsOneWidget);
    expect(find.text('تمّ'), findsOneWidget);
    // The next one is now the lit one, and says how to count it.
    expect(find.bySemanticsLabel(RegExp('^اضغط للعدّ')), findsWidgets);

    // Tapping a finished card does nothing.
    await tester.tap(find.text(items.first.text), warnIfMissed: false);
    expect(container.read(adhkarProgressProvider).countOf(items.first.id), 1);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('finishing a morning dhikr counts towards completions',
      (tester) async {
    final container =
        await pump(tester, const AdhkarCategoryScreen(categoryId: 'morning'));
    final first = collection.of(AdhkarPeriod.morning).first;
    await tester.tap(find.text(first.text));
    await tester.pump(const Duration(seconds: 1));
    expect(
        container.read(adhkarCompletionsProvider).countOf(AdhkarPeriod.morning),
        1);
  });

  testWidgets('reset clears the category after confirming', (tester) async {
    final container =
        await pump(tester, const AdhkarCategoryScreen(categoryId: 'wudu'));
    final first = collection.category('wudu')!.items.first;
    await tester.tap(find.text(first.text));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('إعادة العدّ'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('إعادة'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(adhkarProgressProvider).countOf(first.id), 0);
  });

  testWidgets('A+ and A− change the text size and keep it', (tester) async {
    final container =
        await pump(tester, const AdhkarCategoryScreen(categoryId: 'travel'));
    await tester.tap(find.bySemanticsLabel('تكبير الخط'));
    await tester.pump();
    expect(container.read(adhkarFontSizeProvider),
        AdhkarProgressRepository.defaultFontSize + 2);
    await tester.tap(find.bySemanticsLabel('تصغير الخط'));
    await tester.tap(find.bySemanticsLabel('تصغير الخط'));
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('adhkar.fontSize'),
        AdhkarProgressRepository.defaultFontSize - 2);
  });

  testWidgets('favourites are empty until a dhikr is saved', (tester) async {
    final container = await pump(tester,
        const AdhkarCategoryScreen(categoryId: AdhkarCategoryScreen.favorites));
    expect(find.text('لا توجد أذكار مفضلة'), findsOneWidget);

    await pump(tester, const AdhkarCategoryScreen(categoryId: 'istikhara'),
        reuse: container);
    // The istikhara is long: its options button is below the fold. Saving
    // is in the options sheet.
    await tester.ensureVisible(find.bySemanticsLabel('خيارات الذكر'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('خيارات الذكر'));
    await settle(tester);
    await tester.tap(find.text('إضافة إلى المفضلة'));
    await tester.pump(const Duration(seconds: 3));
    expect(container.read(adhkarFavoritesProvider), {'istikhara-0'});

    await pump(tester,
        const AdhkarCategoryScreen(categoryId: AdhkarCategoryScreen.favorites),
        reuse: container);
    expect(find.text(collection.category('istikhara')!.items.single.text),
        findsOneWidget);
    // The card says which category it came from.
    expect(find.text('دعاء الاستخارة'), findsOneWidget);
  });

  testWidgets('English UI keeps the dhikr in Arabic', (tester) async {
    await pump(tester, const AdhkarCategoryScreen(categoryId: 'riding'),
        locale: 'en');
    expect(find.text('Riding'), findsWidgets);
    expect(find.text(collection.category('riding')!.items.first.text),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('routes resolve, old addresses included', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final config = container.read(routerProvider).configuration;
    expect(config.findMatch(Uri.parse('/adhkar')).fullPath, '/adhkar');
    expect(config.findMatch(Uri.parse('/adhkar/travel')).fullPath,
        '/adhkar/:category');
    expect(config.findMatch(Uri.parse('/home/bookmarks')).fullPath,
        '/home/bookmarks');
    expect(config.findMatch(Uri.parse('/bookmarks')).fullPath, '/bookmarks');
    expect(
        config.findMatch(Uri.parse('/home/adhkar')).fullPath, '/home/adhkar');
  });
}
