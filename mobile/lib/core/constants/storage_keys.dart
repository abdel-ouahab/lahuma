/// Keys used across SharedPreferences / Hive so they aren't
/// scattered/duplicated across features.
class StorageKeys {
  StorageKeys._();

  static const String themeMode = 'settings.themeMode';
  static const String localeOption = 'settings.locale';
  static const String readerFontSize = 'settings.readerFontSize';
  static const String showTranslation = 'settings.showTranslation';
  static const String autoScrollSpeed = 'settings.autoScrollSpeed';

  static const String lastReadSurahId = 'progress.lastSurahId';
  static const String lastReadSurahName = 'progress.lastSurahName';
  static const String lastReadAyahNumber = 'progress.lastAyahNumber';
  static const String lastReadTotalAyahs = 'progress.lastTotalAyahs';

  static const String dailyGoal = 'wird.dailyGoal';
  static const String dailyDate = 'wird.date';
  static const String dailyCount = 'wird.count';
  static const String dailyStreak = 'wird.streak';
  static const String dailyLastGoalDate = 'wird.lastGoalDate';

  static const String dedicationTarget = 'dedication.target';
  static const String dedicationNames = 'dedication.names';
  static const String dedicationTotal = 'dedication.total';

  static const String ayahNotes = 'notes.ayah';

  static const String adhkarProgress = 'adhkar.progress';
  static const String adhkarFavorites = 'adhkar.favorites';
  static const String adhkarCompletions = 'adhkar.completions';

  static const String reciterFavorites = 'mp3quran.favoriteReciters';

  static const String fajrCallLists = 'fajrCall.lists';
  static const String fajrCallSessions = 'fajrCall.sessions';
  static const String fajrCallPrayerSettings = 'fajrCall.prayerSettings';

  static const String authToken = 'auth.token';
  static const String authUser = 'auth.user';

  static const String bookmarksBox = 'bookmarks_box';
  static const String quranCacheBox = 'quran_cache_box';
  static const String adhkarCacheBox = 'adhkar_cache_box';
}
