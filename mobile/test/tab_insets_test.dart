import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lahuma/core/design/app_spacing.dart';
import 'package:lahuma/features/quran/domain/surah.dart';
import 'package:lahuma/features/quran/presentation/providers/quran_providers.dart';
import 'package:lahuma/features/quran/presentation/screens/surah_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The shell reports its floating tab bar as bottom padding. A tab's list
/// must run under the bar (so nothing is cut off above it) and pad its last
/// row clear of it.
void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  const tabBar = 96.0;

  testWidgets('the surah list scrolls under the tab bar', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final surahs = [
      for (var n = 1; n <= 20; n++)
        Surah(
          number: n,
          arabicName: 'سورة $n',
          englishName: 'Surah $n',
          englishNameTranslation: 'Surah $n',
          ayahCount: 7,
          revelationType: 'Meccan',
        ),
    ];

    await tester.pumpWidget(ProviderScope(
      overrides: [surahListProvider.overrideWith((ref) async => surahs)],
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              padding: MediaQuery.of(context).padding.copyWith(bottom: tabBar)),
          child: child!,
        ),
        home: const SurahListScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    final list = find.byType(ListView).first;
    // The list reaches the bottom of the screen, behind the bar.
    expect(tester.getBottomLeft(list).dy, 844);
    final padding =
        tester.widget<ListView>(list).padding!.resolve(TextDirection.rtl);
    expect(padding.bottom, tabBar + AppSpacing.lg);
  });
}
