import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lahuma/core/constants/app_settings_enum.dart';
import 'package:lahuma/core/constants/storage_keys.dart';
import 'package:lahuma/core/design/app_theme.dart';
import 'package:lahuma/core/router/app_router.dart';
import 'package:lahuma/features/fajr_call/data/fajr_call_platform.dart';
import 'package:lahuma/features/fajr_call/domain/call_attempt.dart';
import 'package:lahuma/features/fajr_call/domain/call_session.dart';
import 'package:lahuma/features/fajr_call/presentation/fajr_call_providers.dart';
import 'package:lahuma/features/fajr_call/presentation/screens/fajr_call_edit_screen.dart';
import 'package:lahuma/features/fajr_call/presentation/screens/fajr_call_lists_screen.dart';
import 'package:lahuma/features/fajr_call/presentation/screens/fajr_call_log_screen.dart';
import 'package:lahuma/features/fajr_call/presentation/screens/fajr_call_permissions_screen.dart';
import 'package:lahuma/features/fajr_call/presentation/screens/fajr_wake_list_screen.dart';
import 'package:lahuma/features/settings/presentation/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'helpers/fajr_call_fakes.dart';

final clock = DateTime(2026, 11, 15, 1);

final session = CallSession(
  id: 's1',
  listId: 'l1',
  listName: 'والداي',
  firedAt: DateTime(2026, 11, 14, 5, 55),
  attempts: [
    CallAttempt(
        contact: mother,
        startedAt: DateTime(2026, 11, 14, 5, 55),
        status: CallStatus.noAnswer),
    CallAttempt(
        contact: father,
        startedAt: DateTime(2026, 11, 14, 5, 56),
        status: CallStatus.called),
    CallAttempt(
        contact: mother,
        startedAt: DateTime(2026, 11, 14, 5, 58),
        status: CallStatus.failed,
        attemptNo: 2),
  ],
);

/// The app's Fajr Call routes on a bare Home, so screens can navigate.
GoRouter fajrRouter(String initial) => GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const SizedBox(),
          routes: [
            GoRoute(
              path: 'fajr-call',
              builder: (_, __) => const FajrCallListsScreen(),
              routes: [
                GoRoute(
                    path: 'new',
                    builder: (_, __) => const FajrCallEditScreen()),
                GoRoute(
                  path: 'permissions',
                  builder: (_, s) => FajrCallPermissionsScreen(
                      firstRun: s.uri.queryParameters['first'] == '1'),
                ),
                GoRoute(
                  path: ':id',
                  builder: (_, s) =>
                      FajrCallEditScreen(listId: s.pathParameters['id']),
                  routes: [
                    GoRoute(
                      path: 'log',
                      builder: (_, s) =>
                          FajrCallLogScreen(listId: s.pathParameters['id']!),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/fajr-call/wake/:id',
          builder: (_, s) => FajrWakeListScreen(
            listId: s.pathParameters['id']!,
            firedAt: DateTime(2026, 11, 15, 5, 56),
          ),
        ),
      ],
    );

void main() {
  late FakeFajrPlatform platform;
  late List<String> dialled;

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Algiers'));
  });

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    platform = FakeFajrPlatform();
    dialled = [];
  });

  void seed({bool lists = true, bool sessions = false, bool location = true}) {
    SharedPreferences.setMockInitialValues({
      if (lists) StorageKeys.fajrCallLists: jsonEncode([parentsList.toJson()]),
      if (sessions)
        StorageKeys.fajrCallSessions: jsonEncode([session.toJson()]),
      if (location)
        StorageKeys.fajrCallPrayerSettings: jsonEncode(algiers.toJson()),
    });
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<GoRouter> pump(
    WidgetTester tester,
    String location, {
    String locale = 'ar',
    ThemeMode mode = ThemeMode.light,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = fajrRouter(location);
    final container = ProviderContainer(overrides: [
      fajrCallPlatformProvider.overrideWithValue(platform),
      fajrNotificationsProvider.overrideWithValue(FakeFajrNotifications()),
      fajrClockProvider.overrideWithValue(() => clock),
      dialerProvider.overrideWithValue((phone) async {
        dialled.add(phone);
        return true;
      }),
    ]);
    addTearDown(container.dispose);
    // The notifier reads the app language for notification texts.
    await container.read(localeOptionProvider.notifier).update(
        locale == 'ar' ? AppLocaleOption.arabic : AppLocaleOption.english);
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: AppTheme.builder(context, child),
        ),
        scrollBehavior: AppTheme.scrollBehavior,
        routerConfig: router,
      ),
    ));
    await settle(tester);
    return router;
  }

  Future<void> scrollThrough(WidgetTester tester) async {
    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 6; i++) {
      await tester.drag(list, const Offset(0, -400));
      await settle(tester);
    }
  }

  for (final locale in ['ar', 'en']) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('lists, editor and log render · $locale · ${mode.name}',
          (tester) async {
        seed(sessions: true);
        final router =
            await pump(tester, '/home/fajr-call', locale: locale, mode: mode);
        expect(find.text('والداي'), findsOneWidget);
        // Fajr in Algiers on 15 Nov 2026 is 05:56: "today" at 01:00.
        expect(find.textContaining(locale == 'ar' ? 'اليوم' : 'Today'),
            findsOneWidget);

        router.push('/home/fajr-call/l1');
        await settle(tester);
        expect(find.text('أمي'), findsOneWidget);
        await scrollThrough(tester);

        router.push('/home/fajr-call/l1/log');
        await settle(tester);
        expect(
            find.text(locale == 'ar' ? 'استيقظوا' : 'Woke up'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('screens survive 1.6× text in Arabic', (tester) async {
    seed(sessions: true);
    platform.supported = true;
    final router = await pump(tester, '/home/fajr-call', textScale: 1.6);
    expect(tester.takeException(), isNull);
    router.push('/home/fajr-call/l1');
    await settle(tester);
    await scrollThrough(tester);
    expect(tester.takeException(), isNull);
    router.push('/home/fajr-call/l1/log');
    await settle(tester);
    await scrollThrough(tester);
    expect(tester.takeException(), isNull);
    router.push('/fajr-call/wake/l1');
    await settle(tester);
    expect(tester.takeException(), isNull);
    router.push('/home/fajr-call/permissions');
    await settle(tester);
    await scrollThrough(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state creates the first list for one\'s parents',
      (tester) async {
    seed(lists: false);
    await pump(tester, '/home/fajr-call');
    expect(find.text('أيقظ والديك للفجر'), findsOneWidget);
    await tester.tap(find.text('جهّز أول قائمة'));
    await settle(tester);
    expect(find.text('قائمة جديدة'), findsOneWidget); // nav title
    final name = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(name.controller.text, 'والداي');
  });

  testWidgets('add a person by number, save, then see the permissions intro',
      (tester) async {
    seed(lists: false);
    await pump(tester, '/home/fajr-call/new');

    await tester.scrollUntilVisible(find.text('إدخال رقم'), 300,
        scrollable: find.byType(Scrollable).first);
    await settle(tester);
    await tester.tap(find.text('إدخال رقم'));
    await settle(tester);
    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(fields.evaluate().length - 2), 'أمي');
    await tester.enterText(fields.last, '0551 23 45 67');
    await tester.tap(find.text('حفظ'));
    await settle(tester);
    expect(find.text('أمي'), findsOneWidget);

    await tester.tap(find.text('حفظ القائمة'));
    await settle(tester);
    expect(find.text('الأذونات'), findsOneWidget);
    expect(find.text('الإشعارات'), findsOneWidget);
  });

  testWidgets('switching to a fixed time shows the time row', (tester) async {
    seed();
    await pump(tester, '/home/fajr-call/l1', locale: 'en');
    expect(find.text('Fajr today'), findsOneWidget);
    await tester.tap(find.text('Fixed time'));
    await settle(tester);
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('Fajr today'), findsNothing);
  });

  testWidgets('location comes from Settings: no method, sheet only if unset',
      (tester) async {
    seed();
    await pump(tester, '/home/fajr-call', locale: 'en');
    expect(find.text('Location & method'), findsNothing);

    seed(location: false);
    await pump(tester, '/home/fajr-call/l1', locale: 'en');
    await tester.tap(find.text('Set your location in Settings'));
    await settle(tester);
    expect(find.text('Your location'), findsOneWidget);
    expect(find.text('Use my current location'), findsOneWidget);
    expect(find.text('Calculation method'), findsNothing);
  });

  testWidgets('log: ticking someone counts them as awake', (tester) async {
    final semantics = tester.ensureSemantics();
    seed(sessions: true);
    await pump(tester, '/home/fajr-call/l1/log', locale: 'en');
    expect(find.bySemanticsLabel('Woke up: 0 of 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Calls: 3'), findsOneWidget);
    expect(find.text('Awake?'), findsNWidgets(2));
    // One call only "ended", so the log explains what that means.
    expect(find.textContaining('picked up or declined'), findsOneWidget);
    expect(find.textContaining('0/2 awake'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('أبي is awake'));
    await settle(tester);
    expect(find.bySemanticsLabel('Woke up: 1 of 2'), findsOneWidget);
    expect(find.textContaining('1/2 awake'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('wake list calls with tel: and logs ticks', (tester) async {
    final semantics = tester.ensureSemantics();
    seed();
    await pump(tester, '/fajr-call/wake/l1');
    expect(find.text('حان وقت الفجر'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('اتصل بـ أمي'));
    await settle(tester);
    expect(dialled, ['+213551234567']);
    expect(find.text('اتصلت به'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('أمي استيقظ'));
    await tester.tap(find.bySemanticsLabel('أبي استيقظ'));
    await settle(tester);
    expect(find.textContaining('استيقظوا جميعًا'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('auto mode with the engine offers "Test now" after a confirm',
      (tester) async {
    seed();
    platform
      ..supported = true
      ..perms = const FajrNativePermissions(callPhone: true, phoneState: true);
    await pump(tester, '/home/fajr-call/l1', locale: 'en');
    // ListView builds lazily: scroll until the row exists.
    await tester.scrollUntilVisible(find.text('Test now'), 300,
        scrollable: find.byType(Scrollable).first);
    await settle(tester);
    await tester.tap(find.text('Test now'));
    await settle(tester);
    expect(find.text('Place real calls now?'), findsOneWidget);
    await tester.tap(find.text('Call now'));
    await settle(tester);
    expect(platform.ran.single.id, 'l1');
  });

  test('router: Fajr Call paths resolve, and "new" is not an id', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final config = container.read(routerProvider).configuration;
    expect(config.findMatch(Uri.parse('/home/fajr-call')).fullPath,
        '/home/fajr-call');
    expect(config.findMatch(Uri.parse('/home/fajr-call/new')).fullPath,
        '/home/fajr-call/new');
    expect(config.findMatch(Uri.parse('/home/fajr-call/permissions')).fullPath,
        '/home/fajr-call/permissions');
    expect(config.findMatch(Uri.parse('/home/fajr-call/l1')).fullPath,
        '/home/fajr-call/:id');
    expect(config.findMatch(Uri.parse('/home/fajr-call/l1/log')).fullPath,
        '/home/fajr-call/:id/log');
    expect(config.findMatch(Uri.parse('/fajr-call/wake/l1?at=1')).fullPath,
        '/fajr-call/wake/:id');
  });
}
