// Screens in the states that only appear after use: an active and a
// finished khatma, saved bookmarks, a Fajr call log, every page of the
// introduction, a recitation playing (mini player, Now Playing and its
// sheets).
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lahuma/core/constants/storage_keys.dart';
import 'package:lahuma/core/design/widgets/app_mini_player.dart';
import 'package:lahuma/core/network/api_exception.dart';
import 'package:lahuma/features/bookmarks/domain/bookmark.dart';
import 'package:lahuma/features/fajr_call/domain/call_attempt.dart';
import 'package:lahuma/features/fajr_call/domain/call_session.dart';
import 'package:lahuma/features/khatma/domain/khatma.dart';
import 'package:lahuma/features/khatma/presentation/khatma_providers.dart';
import 'package:lahuma/features/mp3quran/domain/mp3quran_models.dart';
import 'package:lahuma/features/mp3quran/presentation/mp3quran_providers.dart';
import 'package:lahuma/features/quran/presentation/providers/quran_providers.dart';
import 'package:qcf_quran/qcf_quran.dart' as qcf;

import '../helpers/fajr_call_fakes.dart';
import 'fakes.dart';
import 'harness.dart';

Future<void> _khatma(WidgetTester tester, ProviderContainer c,
    {int start = 1, int reach = 146}) async {
  final n = c.read(khatmaProvider.notifier);
  await settle(tester, n.ready);
  await settle(
      tester,
      n.create(
        endDate: fixedNow.add(const Duration(days: 29)),
        startPage: start,
        displayUnit: ReadingUnit.juz,
        morningEnabled: true,
        morningMinutes: 6 * 60 + 30,
        eveningEnabled: true,
        eveningMinutes: 21 * 60,
      ));
  await settle(tester, n.reachPage(reach));
}

Future<void> _bookmarks(WidgetTester tester, ProviderContainer c,
    {required bool any}) async {
  await tester.runAsync(() async {
    final box = Hive.box<String>(StorageKeys.bookmarksBox);
    await box.clear();
    if (!any) return;
    for (final (s, a) in const [(2, 255), (18, 10), (36, 1), (55, 13), (67, 1), (112, 1), (2, 286)]) {
      final b = Bookmark(
        surahId: s,
        ayahNumber: a,
        surahName: 'سُورَةُ ${qcf.getSurahNameArabic(s)}',
        createdAt: fixedNow.subtract(Duration(hours: s)),
      );
      await box.put(b.id, jsonEncode(b.toJson()));
    }
  });
}

final _session = CallSession(
  id: 's1',
  listId: 'l1',
  listName: 'والداي',
  firedAt: DateTime(2026, 11, 12, 5, 55),
  attempts: [
    CallAttempt(
        contact: mother,
        startedAt: DateTime(2026, 11, 12, 5, 55),
        status: CallStatus.noAnswer),
    CallAttempt(
        contact: father,
        startedAt: DateTime(2026, 11, 12, 5, 56),
        status: CallStatus.called),
    CallAttempt(
        contact: mother,
        startedAt: DateTime(2026, 11, 12, 5, 58),
        status: CallStatus.failed,
        attemptNo: 2),
  ],
);

/// A recitation that is "playing" (no audio plugin in tests).
class _Playing extends Mp3PlaybackController {
  _Playing(super.moshaf) {
    state = const Mp3PlaybackState(surah: 18, status: Mp3PlaybackStatus.ready);
  }
}

final Mp3Reciter _reciter = mp3Reciters[1];
final Mp3Moshaf _moshaf = _reciter.moshaf.first;

Future<void> _playing(WidgetTester tester, ProviderContainer c) async =>
    c.read(mp3SessionProvider.notifier).state = Mp3Session(_reciter, _moshaf);

final _playingOverrides = <Override>[
  mp3PlaybackProvider.overrideWith((ref, moshaf) => _Playing(moshaf)),
];

Future<void> _openNowPlaying(WidgetTester tester) async {
  await tester.tap(find.byType(AppMiniPlayerBar).first, warnIfMissed: false);
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> Function(WidgetTester) _fromNowPlaying(
        String tooltipAr, String tooltipEn) =>
    (tester) async {
      await _openNowPlaying(tester);
      final ar = find.byTooltip(tooltipAr);
      await tapVisible(
          tester, ar.evaluate().isNotEmpty ? ar : find.byTooltip(tooltipEn));
    };

/// No connection: every list that loads from the network shows its error.
final _offline = <Override>[
  surahListProvider
      .overrideWith((ref) => throw const ApiException(ApiException.offline)),
  surahDetailProvider.overrideWith(
      (ref, n) => throw const ApiException(ApiException.offline)),
  mp3RecitersProvider
      .overrideWith((ref) => throw const ApiException(ApiException.offline)),
];

final stateCases = <ScreenCase>[
  const ScreenCase('khatma_active', route: '/khatma', setup: _khatma),
  ScreenCase('khatma_complete',
      route: '/khatma',
      setup: (t, c) => _khatma(t, c, start: 590, reach: 604),
      routeFor: (c) => '/khatma/done/${c.read(khatmaProvider).history.first.id}'),
  const ScreenCase('khatma_edit', route: '/khatma/edit', setup: _khatma),
  ScreenCase('home_in_use',
      route: '/home',
      prefs: fajrPrefs,
      overrides: _playingOverrides,
      setup: (t, c) async {
        await _khatma(t, c);
        await _playing(t, c);
      }),
  ScreenCase('bookmarks_saved',
      route: '/home/bookmarks', setup: (t, c) => _bookmarks(t, c, any: true)),
  ScreenCase('bookmarks_empty',
      route: '/home/bookmarks', setup: (t, c) => _bookmarks(t, c, any: false)),
  ScreenCase('fajr_log_filled',
      route: '/home/fajr-call/l1/log',
      prefs: {
        ...fajrPrefs,
        StorageKeys.fajrCallSessions: jsonEncode([_session.toJson()]),
      }),
  for (var page = 2; page <= 7; page++)
    ScreenCase('onboarding_p$page',
        route: '/onboarding',
        open: (tester) async => tester
            .widget<PageView>(find.byType(PageView))
            .controller!
            .jumpToPage(page - 1)),
  ScreenCase('quran_with_mini_player',
      route: '/quran',
      overrides: _playingOverrides,
      setup: _playing),
  ScreenCase('now_playing',
      route: '/quran/mp3quran/2/20',
      overrides: _playingOverrides,
      setup: _playing,
      open: _openNowPlaying),
  ScreenCase('now_playing_surahs_sheet',
      route: '/quran/mp3quran/2/20',
      overrides: _playingOverrides,
      setup: _playing,
      hasInput: true,
      open: _fromNowPlaying('قائمة السور', 'Surah list')),
  ScreenCase('now_playing_backdrop_sheet',
      route: '/quran/mp3quran/2/20',
      overrides: _playingOverrides,
      setup: _playing,
      open: _fromNowPlaying('خلفية المشغّل', 'Player background')),
  ScreenCase('now_playing_sleep_sheet',
      route: '/quran/mp3quran/2/20',
      overrides: _playingOverrides,
      setup: _playing,
      open: _fromNowPlaying('مؤقت الإيقاف', 'Sleep timer')),
  ScreenCase('quran_offline', route: '/quran', overrides: _offline),
  ScreenCase('reader_offline', route: '/quran/18', overrides: _offline),
  ScreenCase('mp3_reciters_offline',
      route: '/quran/mp3quran', overrides: _offline),
];
