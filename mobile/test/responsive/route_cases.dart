// Every route of the app, as it opens.
import 'fakes.dart';
import 'harness.dart';

/// Screens outside the tab bar.
final outsideShellCases = <ScreenCase>[
  const ScreenCase('splash', route: '/', settleFrames: 4),
  const ScreenCase('onboarding', route: '/onboarding'),
  const ScreenCase('surah_reader', route: '/quran/2'),
  const ScreenCase('mushaf', route: '/mushaf?page=3'),
  const ScreenCase('mushaf_index', route: '/mushaf/index'),
  const ScreenCase('tasbih', route: '/tasbih'),
  const ScreenCase('khatma', route: '/khatma'),
  const ScreenCase('khatma_setup', route: '/khatma/setup'),
  const ScreenCase('qibla', route: '/qibla'),
  ScreenCase('fajr_wake_list', route: '/fajr-call/wake/l1', prefs: fajrPrefs),
  const ScreenCase('adhan_player', route: '/adhan/play?prayer=maghrib'),
  const ScreenCase('account', route: '/account', hasInput: true),
];

/// Screens inside the tab shell (tab bar and mini player around them).
final shellCases = <ScreenCase>[
  const ScreenCase('home', route: '/home'),
  const ScreenCase('bookmarks', route: '/home/bookmarks'),
  ScreenCase('fajr_lists', route: '/home/fajr-call', prefs: fajrPrefs),
  ScreenCase('fajr_edit', route: '/home/fajr-call/l1', prefs: fajrPrefs),
  ScreenCase('fajr_new', route: '/home/fajr-call/new', prefs: fajrPrefs),
  ScreenCase('fajr_permissions',
      route: '/home/fajr-call/permissions', prefs: fajrPrefs),
  ScreenCase('fajr_log', route: '/home/fajr-call/l1/log', prefs: fajrPrefs),
  const ScreenCase('quran_surahs', route: '/quran', hasInput: true),
  const ScreenCase('quran_juz', route: '/quran?tab=1'),
  const ScreenCase('quran_listen', route: '/quran?tab=2', hasInput: true),
  const ScreenCase('mp3_reciters', route: '/quran/mp3quran', hasInput: true),
  const ScreenCase('mp3_player', route: '/quran/mp3quran/1/10'),
  const ScreenCase('reciter_player', route: '/quran/reciters/r1'),
  const ScreenCase('adhkar', route: '/adhkar'),
  const ScreenCase('adhkar_category', route: '/adhkar/morning'),
  const ScreenCase('settings', route: '/settings'),
  const ScreenCase('adhan_settings', route: '/settings/adhan'),
  const ScreenCase('adhan_reliability', route: '/settings/adhan/reliability'),
  const ScreenCase('reminders', route: '/settings/reminders'),
];
