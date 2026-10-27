import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lahuma/core/audio/audio_focus.dart';
import 'package:lahuma/core/design/app_theme.dart';
import 'package:lahuma/features/quran/presentation/providers/ayah_audio_provider.dart';
import 'package:lahuma/features/quran/presentation/widgets/ayah_mini_player.dart';

/// Stands in for one of the app's players.
class _FakePlayer {
  int stops = 0;
  Future<void> stop() async => stops++;
}

/// Ayah notifier that starts out "playing" without touching just_audio.
class _PlayingAyahAudio extends AyahAudioNotifier {
  _PlayingAyahAudio(super.ref, AyahPlayback playback) {
    state = playback;
  }
}

const _playback = AyahPlayback(
  surah: 36,
  surahName: 'سُورَةُ يسٓ',
  totalAyahs: 83,
  ayah: 5,
  playing: true,
);

void main() {
  group('AudioFocus', () {
    late AudioFocus focus;
    late _FakePlayer ayah, reciter, mp3;

    setUp(() {
      focus = AudioFocus();
      ayah = _FakePlayer();
      reciter = _FakePlayer();
      mp3 = _FakePlayer();
      focus
        ..register(ayah, ayah.stop)
        ..register(reciter, reciter.stop)
        ..register(mp3, mp3.stop);
    });

    test('claiming stops every other player, never the claimant', () async {
      for (final owner in [ayah, reciter, mp3]) {
        final before = {for (final p in [ayah, reciter, mp3]) p: p.stops};
        await focus.claim(owner);
        for (final p in [ayah, reciter, mp3]) {
          expect(p.stops - before[p]!, identical(p, owner) ? 0 : 1);
        }
      }
    });

    test('stopAll stops every player', () async {
      await focus.stopAll();
      expect([ayah.stops, reciter.stops, mp3.stops], [1, 1, 1]);
    });

    test('an unregistered player is left alone', () async {
      focus.unregister(mp3);
      await focus.claim(ayah);
      expect(mp3.stops, 0);
      expect(reciter.stops, 1);
    });

    test('a player that fails to stop does not block the others', () async {
      focus.register(Object(), () async => throw StateError('boom'));
      await focus.claim(ayah);
      expect([reciter.stops, mp3.stops], [1, 1]);
    });

    test('a stop that unregisters players mid-claim is safe', () async {
      focus.register(reciter, () async {
        reciter.stops++;
        focus.unregister(mp3);
      });
      await focus.claim(ayah);
      expect(reciter.stops, 1);
    });
  });

  test('the ayah player registers itself and stops with the others', () async {
    final container = ProviderContainer(overrides: [
      ayahAudioProvider.overrideWith((ref) => _PlayingAyahAudio(ref, _playback)),
    ]);
    addTearDown(container.dispose);

    expect(container.read(ayahAudioProvider), isNotNull);
    final other = _FakePlayer();
    container.read(audioFocusProvider).register(other, other.stop);

    await container.read(audioFocusProvider).stopAll();
    expect(container.read(ayahAudioProvider), isNull);
    expect(other.stops, 1);
  });

  group('AyahMiniPlayer', () {
    setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

    Future<ProviderContainer> pump(WidgetTester tester) async {
      final container = ProviderContainer(overrides: [
        ayahAudioProvider
            .overrideWith((ref) => _PlayingAyahAudio(ref, _playback)),
      ]);
      addTearDown(container.dispose);
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: AyahMiniPlayer(),
            ),
          ),
        ),
        GoRoute(
          path: '/quran/:number',
          builder: (_, state) => Text(
              'reader ${state.pathParameters['number']} '
              '${state.uri.queryParameters['ayah']}'),
        ),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('en'),
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
      return container;
    }

    testWidgets('shows the surah and ayah being recited', (tester) async {
      await pump(tester);
      expect(find.text('سُورَةُ يسٓ'), findsOneWidget);
      expect(find.text('Ayah 5 · Mishary Alafasy'), findsOneWidget);
      expect(find.bySemanticsLabel('Pause'), findsOneWidget);
    });

    testWidgets('tapping it reopens the reader at that ayah', (tester) async {
      await pump(tester);
      await tester.tap(find.text('سُورَةُ يسٓ'));
      await tester.pumpAndSettle();
      expect(find.text('reader 36 5'), findsOneWidget);
    });

    testWidgets('the close button stops the recitation', (tester) async {
      final container = await pump(tester);
      await tester.tap(find.bySemanticsLabel('Stop'));
      await tester.pump();
      expect(container.read(ayahAudioProvider), isNull);
      expect(find.text('سُورَةُ يسٓ'), findsNothing);
    });
  });
}
