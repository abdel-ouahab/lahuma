import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lahuma/core/constants/storage_keys.dart';
import 'package:lahuma/core/design/app_theme.dart';
import 'package:lahuma/features/quran/mushaf/presentation/mushaf_providers.dart';
import 'package:lahuma/features/quran/mushaf/presentation/screens/mushaf_index_screen.dart';
import 'package:lahuma/features/quran/mushaf/presentation/screens/mushaf_screen.dart';
import 'package:lahuma/features/quran/mushaf/presentation/widgets/mushaf_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;

  GoRouter mushafRouter() => GoRouter(
        initialLocation: MushafScreen.path,
        routes: [
          GoRoute(
            path: MushafScreen.path,
            builder: (context, state) => MushafScreen(
              initialPage:
                  int.tryParse(state.uri.queryParameters['page'] ?? ''),
            ),
            routes: [
              GoRoute(
                path: 'index',
                builder: (context, state) => MushafIndexScreen(
                  currentPage:
                      int.tryParse(state.uri.queryParameters['page'] ?? ''),
                ),
              ),
            ],
          ),
        ],
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    String locale = 'ar',
    ThemeMode mode = ThemeMode.light,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
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
        scrollBehavior: AppTheme.scrollBehavior,
        routerConfig: mushafRouter(),
      ),
    ));
    await settle(tester);
  }

  ScrollPhysics? pagePhysics(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).physics;

  Future<void> doubleTap(WidgetTester tester) async {
    final center = tester.getCenter(find.byType(PageView));
    await tester.tapAt(center);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(center);
    await settle(tester);
  }

  setUp(() =>
      SharedPreferences.setMockInitialValues({StorageKeys.mushafLastPage: 50}));

  for (final locale in ['ar', 'en']) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('reopens on the last page · $locale · ${mode.name}',
          (tester) async {
        await pump(tester, locale: locale, mode: mode);
        expect(find.text(locale == 'ar' ? 'سورة آل عمران' : 'Al Imran'),
            findsOneWidget);
        expect(find.text(locale == 'ar' ? 'صفحة 50 من 604' : 'Page 50 of 604'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('swipes in Arabic order and saves the page', (tester) async {
    await pump(tester);
    // RTL: the next page comes in from the left, so the finger moves right.
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1500);
    await settle(tester);
    expect(find.text('صفحة 51 من 604'), findsOneWidget);
    expect(container.read(mushafProvider).lastPage, 51);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(StorageKeys.mushafLastPage), 51);
  });

  testWidgets('a tap on the page toggles the overlay', (tester) async {
    await pump(tester);
    double opacity() => tester
        .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
        .opacity;
    expect(opacity(), 1);
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await settle(tester);
    expect(opacity(), 0);
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await settle(tester);
    expect(opacity(), 1);
  });

  testWidgets('double tap zooms, locks swiping, and zooms back out',
      (tester) async {
    await pump(tester);
    expect(pagePhysics(tester), isNull);
    await doubleTap(tester);
    expect(pagePhysics(tester), isA<NeverScrollableScrollPhysics>());
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1500);
    await settle(tester);
    expect(find.text('صفحة 50 من 604'), findsOneWidget);
    await doubleTap(tester);
    expect(pagePhysics(tester), isNull);
  });

  testWidgets('a zoomed page pans up and down, not only sideways',
      (tester) async {
    await pump(tester);
    final page = find.byKey(const ValueKey(50));
    // At 1x the page's text list takes vertical drags (scrolls tall pages).
    expect(
        tester
            .stateList<ScrollableState>(
                find.descendant(of: page, matching: find.byType(Scrollable)))
            .map((s) => s.position.physics.allowUserScrolling),
        contains(isTrue));

    await doubleTap(tester);
    Matrix4 transform() => tester
        .widget<InteractiveViewer>(
            find.descendant(of: page, matching: find.byType(InteractiveViewer)))
        .transformationController!
        .value;
    final before = transform().getTranslation().y;
    await tester.drag(find.byType(PageView), const Offset(0, -150));
    await settle(tester);
    expect(transform().getTranslation().y, lessThan(before - 50));
  });

  testWidgets('the appearance button switches the page theme and saves it',
      (tester) async {
    await pump(tester); // app in light mode: automatic → sepia paper
    Color paper() => tester
        .widget<Material>(find
            .ancestor(
                of: find.byType(PageView), matching: find.byType(Material))
            .first)
        .color!;
    expect(paper(), MushafThemes.paper.pageBackgroundColor);

    await tester.tap(find.bySemanticsLabel('مظهر المصحف'));
    await settle(tester);
    await tester.tap(find.text('داكن'));
    await settle(tester);
    expect(paper(), MushafThemes.night.pageBackgroundColor);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(StorageKeys.mushafTheme), 'dark');

    await tester.tap(find.bySemanticsLabel('مظهر المصحف'));
    await settle(tester);
    await tester.tap(find.text('أبيض'));
    await settle(tester);
    expect(paper(), MushafThemes.white.pageBackgroundColor);
  });

  testWidgets('go to page accepts Arabic-Indic digits', (tester) async {
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('الانتقال إلى صفحة'));
    await settle(tester);
    await tester.enterText(find.byType(CupertinoTextField), '٣٠٠');
    await tester.tap(find.text('انتقال'));
    await settle(tester);
    expect(find.text('صفحة 300 من 604'), findsOneWidget);
  });

  testWidgets('bookmarks the page and lists it in the index', (tester) async {
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('إضافة علامة'));
    await settle(tester);
    expect(container.read(mushafProvider).isBookmarked(50), isTrue);

    await tester.tap(find.bySemanticsLabel('الفهرس'));
    await settle(tester);
    await tester.tap(find.text('العلامات'));
    await settle(tester);
    expect(find.text('صفحة 50'), findsOneWidget);
  });

  testWidgets('the index jumps to a surah and a juz\'', (tester) async {
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('الفهرس'));
    await settle(tester);
    await tester.tap(find.text('البقرة'));
    await settle(tester);
    expect(find.text('صفحة 2 من 604'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('الفهرس'));
    await settle(tester);
    await tester.tap(find.text('الأجزاء'));
    await settle(tester);
    await tester.tap(find.text('الجزء 2'));
    await settle(tester);
    expect(find.text('صفحة 22 من 604'), findsOneWidget);
  });

  testWidgets('long-pressing an ayah opens its sheet', (tester) async {
    await pump(tester);
    await tester.longPressAt(ayahCenter(tester, page: 50, index: 2));
    await settle(tester);
    expect(find.text('نسخ نص الآية'), findsOneWidget);
    expect(find.text('سورة آل عمران · الآية 3'), findsOneWidget);
  });
}

/// Global centre of the [index]-th (0-based) ayah span on [page]:
/// the page's glyphs are test-font squares, so aim at a real glyph box.
Offset ayahCenter(WidgetTester tester,
    {required int page, required int index}) {
  final texts = find.descendant(
      of: find.byKey(ValueKey(page)), matching: find.byType(RichText));
  final element = texts.evaluate().firstWhere((e) {
    var tappable = false;
    (e.widget as RichText).text.visitChildren((s) {
      if (s is TextSpan && s.recognizer != null) tappable = true;
      return !tappable;
    });
    return tappable && (e.renderObject! as RenderBox).hasSize;
  });
  final paragraph = element.renderObject! as RenderParagraph;
  var offset = 0;
  var seen = 0;
  TextSelection? range;
  paragraph.text.visitChildren((s) {
    if (s is TextSpan) {
      final length = s.text?.length ?? 0;
      if (s.recognizer != null && seen++ == index) {
        range =
            TextSelection(baseOffset: offset, extentOffset: offset + length);
        return false;
      }
      offset += length;
    } else {
      offset += 1; // a WidgetSpan is one placeholder character
    }
    return true;
  });
  final box = paragraph.getBoxesForSelection(range!).first.toRect();
  return paragraph.localToGlobal(box.center);
}
