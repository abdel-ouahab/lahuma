import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants/app_settings_enum.dart';
import 'core/constants/storage_keys.dart';
import 'core/router/app_router.dart';
import 'core/design/app_theme.dart';
import 'features/settings/presentation/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox<String>(StorageKeys.bookmarksBox);
  await Hive.openBox<String>(StorageKeys.quranCacheBox);

  runApp(const ProviderScope(child: LahumaApp()));
}

class LahumaApp extends ConsumerWidget {
  const LahumaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final localeOption = ref.watch(localeOptionProvider);

    return MaterialApp.router(
      title: 'لهما',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (themeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      },
      locale: Locale(localeOption.languageCode),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: AppTheme.builder,
      scrollBehavior: AppTheme.scrollBehavior,
    );
  }
}
