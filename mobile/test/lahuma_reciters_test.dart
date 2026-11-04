import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lahuma/core/design/app_theme.dart';
import 'package:lahuma/features/quran/domain/reciter.dart';
import 'package:lahuma/features/quran/presentation/providers/reciter_providers.dart';
import 'package:lahuma/features/quran/presentation/widgets/lahuma_reciters_section.dart';

Reciter _reciter(
        String id, String name, String nameAr, Map<int, String> urls) =>
    Reciter(
      id: id,
      name: name,
      displayName: nameAr,
      audioBasePath: '',
      audioUrls: urls,
    );

void main() {
  final ajmi = _reciter('a', 'Ahmed Al-Ajmi', 'أحمد العجمي',
      {1: 'http://x/audio/a/001.mp3', 2: 'http://x/audio/a/002.mp3'});
  final empty = _reciter('b', 'No audio yet', 'بلا تلاوات', const {});
  final husary = _reciter('c', 'Mahmoud Al-Husary', 'محمود خليل الحُصَري',
      {112: 'http://x/audio/c/112.mp3'});

  test('only reciters with uploaded audio are listed', () {
    expect(playableReciters([ajmi, empty, husary], ''), [ajmi, husary]);
  });

  test('search matches Arabic without hamza or diacritics, and Latin', () {
    final all = [ajmi, empty, husary];
    expect(playableReciters(all, 'احمد'), [ajmi]);
    expect(playableReciters(all, 'الحصري'), [husary]);
    expect(playableReciters(all, 'husary'), [husary]);
    expect(playableReciters(all, 'بلا'), isEmpty);
  });

  testWidgets('the section lists reciters and opens their player',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: ListView(children: [
            LahumaRecitersSection(reciters: [ajmi, husary]),
          ]),
        ),
      ),
      GoRoute(
        path: '/quran/reciters/:id',
        builder: (_, state) => Text('player ${state.pathParameters['id']}'),
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: AppTheme.builder,
        routerConfig: router,
      ),
    ));
    await tester.pump();

    expect(find.text('قرّاء إحسان'), findsOneWidget);
    expect(find.text('أحمد العجمي'), findsOneWidget);
    expect(find.text('2 سورة'), findsOneWidget);

    await tester.tap(find.text('محمود خليل الحُصَري'));
    await tester.pumpAndSettle();
    expect(find.text('player c'), findsOneWidget);
  });
}
