import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lahuma/core/design/app_theme.dart';
import 'package:lahuma/core/design/design.dart' show AppIconTile;
import 'package:lahuma/features/home/presentation/home_sidebar.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<GoRouter> pump(WidgetTester tester, {String locale = 'ar'}) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Widget page(GoRouterState state) =>
        CupertinoPageScaffold(child: Center(child: Text('at ${state.uri}')));
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, _) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () => HomeSidebar.show(context),
                child: const Text('open'),
              ),
            ),
          ),
          routes: [
            GoRoute(path: 'bookmarks', builder: (_, s) => page(s)),
            GoRoute(path: 'fajr-call', builder: (_, s) => page(s)),
          ],
        ),
        for (final path in ['/quran', '/mushaf', '/qibla', '/tasbih', '/adhkar'])
          GoRoute(path: path, builder: (_, s) => page(s)),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
      locale: Locale(locale),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: AppTheme.builder,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return router;
  }

  const places = [
    ('القرآن الكريم', '/quran'),
    ('الاستماع', '/quran?tab=2'),
    ('المصحف الشريف', '/mushaf'),
    ('القبلة', '/qibla'),
    ('نداء الفجر', '/home/fajr-call'),
    ('الأذكار', '/adhkar'),
    ('التسبيح', '/tasbih'),
    ('العلامات', '/home/bookmarks'),
  ];

  testWidgets('lists the seven places in order', (tester) async {
    await pump(tester);
    final tops = [
      for (final (label, _) in places) tester.getTopLeft(find.text(label)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
  });

  for (final (label, location) in places) {
    testWidgets('$label opens $location', (tester) async {
      await pump(tester);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(label), findsNothing);
      expect(find.text('at $location'), findsOneWidget);
    });
  }

  testWidgets('a swipe towards its edge closes it', (tester) async {
    await pump(tester);
    // RTL: the panel sits on the right and is swiped back to the right.
    await tester.drag(find.text('القبلة'), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(find.text('القبلة'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a short swipe leaves it open', (tester) async {
    await pump(tester);
    await tester.timedDrag(find.text('القبلة'), const Offset(40, 0),
        const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('القبلة'), findsOneWidget);
  });

  testWidgets('a tap outside closes it', (tester) async {
    await pump(tester);
    // The panel is on the right in RTL; the left edge is the dimmed page.
    await tester.tapAt(const Offset(10, 400));
    await tester.pumpAndSettle();
    expect(find.text('القبلة'), findsNothing);
  });

  testWidgets('opens from the right in RTL', (tester) async {
    await pump(tester);
    expect(
        tester.getCenter(find.byType(AppIconTile).first).dx, greaterThan(195));
  });

  testWidgets('opens from the left in LTR', (tester) async {
    await pump(tester, locale: 'en');
    expect(tester.getCenter(find.byType(AppIconTile).first).dx, lessThan(195));
    await tester.drag(find.text('Qibla'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.text('Qibla'), findsNothing);
  });
}
