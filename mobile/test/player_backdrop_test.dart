import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lahuma/core/constants/storage_keys.dart';
import 'package:lahuma/features/mp3quran/data/player_backdrop_repository.dart';
import 'package:lahuma/features/mp3quran/domain/player_backdrop.dart';
import 'package:lahuma/features/mp3quran/presentation/mp3quran_providers.dart';
import 'package:lahuma/features/mp3quran/presentation/player_backdrop_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('unknown or missing names fall back to no video', () {
    expect(PlayerBackdrop.fromName(null), PlayerBackdrop.none);
    expect(PlayerBackdrop.fromName('aurora'), PlayerBackdrop.none);
    expect(PlayerBackdrop.fromName('sea'), PlayerBackdrop.sea);
    expect(PlayerBackdrop.none.hasVideo, isFalse);
    expect(PlayerBackdrop.rain.video, 'assets/videos/backgrounds/rain.mp4');
    expect(PlayerBackdrop.rain.poster, 'assets/videos/backgrounds/rain.jpg');
  });

  test('the choice survives a restart', () async {
    final repo = PlayerBackdropRepository();
    expect(await repo.load(), PlayerBackdrop.none);
    await repo.save(PlayerBackdrop.forest);
    expect(await repo.load(), PlayerBackdrop.forest);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(playerBackdropProvider), PlayerBackdrop.none);
    await pumpEventQueue();
    expect(container.read(playerBackdropProvider), PlayerBackdrop.forest);
  });

  test('a pick made while loading is not overwritten by the stored one',
      () async {
    SharedPreferences.setMockInitialValues(
        {StorageKeys.playerBackdrop: 'flame'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(playerBackdropProvider.notifier).select(PlayerBackdrop.sea);
    await pumpEventQueue();
    expect(container.read(playerBackdropProvider), PlayerBackdrop.sea);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(StorageKeys.playerBackdrop), 'sea');
  });

  Future<ProviderContainer> pumpSheet(WidgetTester tester, String locale,
      {Size size = const Size(390, 844), double textScale = 1}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(locale),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => PlayerBackdropSheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('the picker lists all six options and applies a pick at once',
      (tester) async {
    final container = await pumpSheet(tester, 'ar');

    for (final label in [
      'بدون فيديو',
      'شعلة هادئة',
      'مطر خفيف',
      'رياح',
      'غابة',
      'بحر',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    // Arabic first: the first option sits on the right.
    expect(tester.getCenter(find.text('بدون فيديو')).dx,
        greaterThan(tester.getCenter(find.text('مطر خفيف')).dx));

    await tester.tap(find.text('بحر'));
    await tester.pumpAndSettle();
    expect(container.read(playerBackdropProvider), PlayerBackdrop.sea);
    // Live preview: the sheet stays open.
    expect(find.text('خلفية المشغّل'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('بحر')),
      matchesSemantics(isButton: true, isSelected: true, hasSelectedState: true),
    );
  });

  // A 9:16 screen leaves the sheet less height than the cards' 0.6 ratio
  // wants (600 x 1067 is the 900 x 1600 / 1.5 emulator where it overflowed).
  for (final (name, size, scale) in [
    ('a wide 9:16 screen', const Size(600, 1067), 1.0),
    ('a small phone', const Size(320, 568), 1.0),
    ('large text', const Size(390, 844), 2.0),
    ('landscape', const Size(844, 390), 1.0),
  ]) {
    testWidgets('the picker fits on $name', (tester) async {
      await pumpSheet(tester, 'ar', size: size, textScale: scale);
      expect(tester.takeException(), isNull);
      // Every card keeps the same height and shows its label.
      final heights = {
        for (final label in ['بدون فيديو', 'مطر خفيف'])
          tester
              .getSize(find
                  .ancestor(
                      of: find.text(label), matching: find.byType(Column))
                  .first)
              .height,
      };
      expect(heights, hasLength(1));
      // The last option is on screen, or one scroll away when nothing fits.
      await tester.scrollUntilVisible(find.text('بحر'), 100,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('بحر'), findsOneWidget);
    });
  }

  testWidgets('labels follow the app language', (tester) async {
    await pumpSheet(tester, 'en');
    expect(find.text('Player background'), findsOneWidget);
    expect(find.text('Gentle rain'), findsOneWidget);
    expect(find.text('No video'), findsOneWidget);
  });
}
