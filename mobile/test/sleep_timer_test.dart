import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lahuma/core/audio/sleep_timer.dart';
import 'package:lahuma/features/mp3quran/presentation/sleep_timer_sheet.dart';

/// A timer on [async]'s fake clock, recording what it asks of the player.
({SleepTimer timer, List<double> fades, List<int> expiries}) _timer(
    FakeAsync async) {
  final start = DateTime(2026, 11, 5, 23);
  final fades = <double>[];
  final expiries = <int>[];
  final timer = SleepTimer(
    onFade: fades.add,
    onExpire: () => expiries.add(1),
    now: () => start.add(async.elapsed),
  );
  return (timer: timer, fades: fades, expiries: expiries);
}

void main() {
  group('SleepTimer', () {
    test('counts down against the clock and expires once', () {
      fakeAsync((async) {
        final t = _timer(async);
        t.timer.start(const Duration(minutes: 15));
        expect(t.timer.isActive, isTrue);
        expect(t.timer.chosen, const Duration(minutes: 15));
        expect(t.timer.remaining, const Duration(minutes: 15));

        async.elapse(const Duration(minutes: 5, milliseconds: 400));
        expect(t.timer.remaining, const Duration(minutes: 9, seconds: 60));
        expect(t.fades, isEmpty);
        expect(t.expiries, isEmpty);

        async.elapse(const Duration(minutes: 10));
        expect(t.expiries, [1]);
        expect(t.timer.isActive, isFalse);
        expect(t.timer.remaining, isNull);

        async.elapse(const Duration(minutes: 30));
        expect(t.expiries, [1]);
      });
    });

    test('fades out over the last seconds and ends silent', () {
      fakeAsync((async) {
        final t = _timer(async);
        t.timer.start(const Duration(seconds: 20));
        async.elapse(const Duration(seconds: 11));
        expect(t.fades, isEmpty);

        async.elapse(const Duration(seconds: 5));
        expect(t.fades, isNotEmpty);
        // Steadily quieter, never louder.
        for (var i = 1; i < t.fades.length; i++) {
          expect(t.fades[i], lessThanOrEqualTo(t.fades[i - 1]));
        }
        expect(t.fades.last, inInclusiveRange(0.4, 0.6));

        async.elapse(const Duration(seconds: 5));
        expect(t.expiries, [1]);
        // Left at silence: the player restores the volume after pausing.
        expect(t.fades.last, 0);
      });
    });

    test('turning it off mid-fade restores the volume', () {
      fakeAsync((async) {
        final t = _timer(async);
        t.timer.start(const Duration(seconds: 10));
        async.elapse(const Duration(seconds: 6));
        expect(t.fades.last, lessThan(1));

        t.timer.cancel();
        expect(t.fades.last, 1);
        expect(t.timer.isActive, isFalse);
        async.elapse(const Duration(minutes: 1));
        expect(t.expiries, isEmpty);
      });
    });

    test('a new length replaces the running one', () {
      fakeAsync((async) {
        final t = _timer(async);
        t.timer.start(const Duration(minutes: 5));
        async.elapse(const Duration(minutes: 4));
        t.timer.start(const Duration(minutes: 30));
        async.elapse(const Duration(minutes: 5));
        expect(t.expiries, isEmpty);
        expect(t.timer.remaining, const Duration(minutes: 25));
        expect(t.timer.chosen, const Duration(minutes: 30));
      });
    });

    test('end of track stops at the next completion only', () {
      fakeAsync((async) {
        final t = _timer(async);
        var notified = 0;
        t.timer.addListener(() => notified++);
        expect(t.timer.takeEndOfTrack(), isFalse);

        t.timer.startEndOfTrack();
        expect(t.timer.isActive, isTrue);
        expect(t.timer.endOfTrack, isTrue);
        expect(t.timer.remaining, isNull);

        expect(t.timer.takeEndOfTrack(), isTrue);
        expect(t.timer.isActive, isFalse);
        expect(t.timer.takeEndOfTrack(), isFalse);
        expect(notified, 2);
      });
    });

    test('a countdown replaces end of track, and the other way round', () {
      fakeAsync((async) {
        final t = _timer(async);
        t.timer.startEndOfTrack();
        t.timer.start(const Duration(minutes: 10));
        expect(t.timer.endOfTrack, isFalse);
        t.timer.startEndOfTrack();
        expect(t.timer.remaining, isNull);
        async.elapse(const Duration(minutes: 20));
        expect(t.expiries, isEmpty);
      });
    });
  });

  test('time left reads m:ss, and h:mm:ss from an hour', () {
    expect(formatSleepRemaining(const Duration(minutes: 9, seconds: 5)),
        '9:05');
    expect(formatSleepRemaining(const Duration(minutes: 60)), '1:00:00');
    expect(formatSleepRemaining(Duration.zero), '0:00');
  });

  group('SleepTimerSheet', () {
    setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

    Future<SleepTimer> pumpSheet(WidgetTester tester, String lang,
        {SleepTimer? timer, Size size = const Size(390, 844)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final t = timer ??
          SleepTimer(onFade: (_) {}, onExpire: () {});
      addTearDown(t.dispose);
      await tester.pumpWidget(MaterialApp(
        locale: Locale(lang),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => SleepTimerSheet.show(context, t),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return t;
    }

    testWidgets('a length starts the timer and closes the sheet',
        (tester) async {
      final timer = await pumpSheet(tester, 'ar');
      expect(find.text('مؤقت الإيقاف'), findsOneWidget);
      for (final m in SleepTimerSheet.lengths) {
        expect(find.bySemanticsLabel('$m دقيقة'), findsOneWidget);
      }
      expect(find.text('إيقاف المؤقت'), findsNothing);

      await tester.tap(find.bySemanticsLabel('15 دقيقة'));
      await tester.pumpAndSettle();
      expect(find.text('مؤقت الإيقاف'), findsNothing);
      expect(timer.chosen, const Duration(minutes: 15));
      timer.cancel();
    });

    testWidgets('while running it shows the time left and turns off',
        (tester) async {
      final timer = SleepTimer(onFade: (_) {}, onExpire: () {})
        ..start(const Duration(minutes: 30));
      await pumpSheet(tester, 'en', timer: timer);

      expect(find.textContaining('Playback pauses in 30:00'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('30 minutes')),
        matchesSemantics(
            isButton: true, isSelected: true, hasSelectedState: true,
            hasTapAction: true),
      );

      await tester.tap(find.text('Turn off timer'));
      await tester.pumpAndSettle();
      expect(timer.isActive, isFalse);
      expect(find.text('Sleep timer'), findsNothing);
    });

    testWidgets('end of surah', (tester) async {
      final timer = await pumpSheet(tester, 'en');
      await tester.tap(find.bySemanticsLabel('End of surah'));
      await tester.pumpAndSettle();
      expect(timer.endOfTrack, isTrue);
    });

    for (final (name, size) in [
      ('a small phone', const Size(320, 568)),
      ('landscape', const Size(844, 390)),
    ]) {
      testWidgets('fits on $name', (tester) async {
        final timer = SleepTimer(onFade: (_) {}, onExpire: () {})
          ..startEndOfTrack();
        await pumpSheet(tester, 'ar', timer: timer, size: size);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('إيقاف المؤقت'), 100,
            scrollable: find.byType(Scrollable).last);
        expect(find.text('إيقاف المؤقت'), findsOneWidget);
      });
    }
  });
}
