import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants/app_settings_enum.dart';
import 'core/constants/storage_keys.dart';
import 'core/notifications/local_notifications.dart';
import 'core/notifications/notification_providers.dart';
import 'core/router/app_router.dart';
import 'core/design/app_theme.dart';
import 'features/adhan/background/adhan_background.dart';
import 'features/adhan/data/adhan_scheduler.dart';
import 'features/adhan/presentation/adhan_foreground.dart';
import 'features/adhan/presentation/adhan_providers.dart';
import 'features/fajr_call/data/fajr_call_platform.dart';
import 'features/fajr_call/presentation/fajr_call_providers.dart';
import 'features/khatma/presentation/khatma_providers.dart';
import 'features/settings/presentation/settings_providers.dart';

/// Android's background engine (`AdhanWorker.kt`) starts here, with no UI:
/// it reschedules the adhan after a reboot, an update, a clock change, and
/// once a day.
@pragma('vm:entry-point')
Future<void> adhanBackgroundMain() => runAdhanBackground();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppTheme.applySystemChrome();

  await Hive.initFlutter();
  await Hive.openBox<String>(StorageKeys.bookmarksBox);
  await Hive.openBox<String>(StorageKeys.quranCacheBox);

  // Timezone + notification plugin; permissions are asked later, in context.
  final notifications = LocalNotifications();
  await notifications.init();
  // A Fajr Call engine notification (results / fallback) launched the app.
  final engineRoute = await const FajrCallPlatform().takeLaunchRoute();
  if (engineRoute != null) notifications.setLaunchRoute(engineRoute);

  runApp(ProviderScope(
    overrides: [localNotificationsProvider.overrideWithValue(notifications)],
    child: const LahumaApp(),
  ));
}

class LahumaApp extends ConsumerStatefulWidget {
  const LahumaApp({super.key});

  @override
  ConsumerState<LahumaApp> createState() => _LahumaAppState();
}

class _LahumaAppState extends ConsumerState<LahumaApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Loads the Fajr lists and reschedules them: Fajr moves every day, so
    // every launch refreshes the upcoming times.
    ref.read(fajrCallProvider);
    // Loads the adhan settings and tops up the rolling week of adhans.
    ref.read(adhanProvider);
    // Loads the khatma, fixes today's portion and replans its reminders.
    ref.read(khatmaProvider);
    // The adhan plays in the app at prayer time, only while it is open.
    ref.read(adhanForegroundProvider).setActive(true);
    ref.read(fajrCallPlatformProvider).setHandlers(
          onRoute: (route) => ref.read(routerProvider).push(route),
          onSessionsChanged: () =>
              ref.read(fajrCallProvider.notifier).refresh(),
        );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Picks up results the Android call engine wrote while we were away.
      ref.read(fajrCallProvider.notifier).refresh();
      // Back from the exact-alarm settings, or a day later: reschedule.
      ref.read(adhanProvider.notifier).reschedule();
      // A new day, or progress changed elsewhere: today's portion and the
      // reminder texts follow.
      ref.read(khatmaProvider.notifier).refresh();
      ref.invalidate(adhanPermissionsProvider);
    }
    // Visible (even behind the notification shade): the adhan may play.
    ref.read(adhanForegroundProvider).setActive(
        state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final localeOption = ref.watch(localeOptionProvider);

    // ThemeProvider snapshots the app for the circular theme reveal (see
    // ThemeModeSwitcher); the themes themselves still come from MaterialApp.
    return ThemeProvider(
      initTheme: AppTheme.light,
      child: MaterialApp.router(
        title: 'لهما',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: switch (themeMode) {
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
          AppThemeMode.system => ThemeMode.system,
        },
        // The reveal is the transition; a cross-fade under it would smear.
        themeAnimationDuration: Duration.zero,
        locale: Locale(localeOption.languageCode),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
        builder: (context, child) => ThemeSwitchingArea(
          // The area re-themes its child with the switcher's last theme;
          // MaterialApp's resolved theme wins so system/startup changes hold.
          child: Theme(
            data: Theme.of(context),
            child: NotificationTapListener(
              notifications: ref.read(localNotificationsProvider),
              onRoute: (route) {
                // The adhan's notification while its player is already
                // open: leave it playing.
                final here = router.routerDelegate.currentConfiguration.uri;
                if (route.startsWith(AdhanScheduler.playRoute) &&
                    here.path == AdhanScheduler.playRoute) {
                  return;
                }
                router.push(route);
              },
              child: Builder(
                builder: (context) => AppTheme.builder(context, child),
              ),
            ),
          ),
        ),
        scrollBehavior: AppTheme.scrollBehavior,
      ),
    );
  }
}
