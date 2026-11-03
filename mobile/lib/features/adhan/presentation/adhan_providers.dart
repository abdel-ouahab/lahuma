import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_settings_enum.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../prayer_times/domain/prayer_times.dart';
import '../../prayer_times/presentation/prayer_times_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/adhan_audio_store.dart';
import '../data/adhan_scheduler.dart';
import '../data/adhan_settings_repository.dart';
import '../data/muezzin_repository.dart';
import '../domain/adhan_plan.dart';
import '../domain/adhan_settings.dart';
import '../domain/muezzin.dart';

final muezzinRepositoryProvider = Provider((ref) => MuezzinRepository());
final adhanSettingsRepositoryProvider =
    Provider((ref) => AdhanSettingsRepository());
final adhanAudioStoreProvider = Provider((ref) => AdhanAudioStore());
final adhanSchedulerProvider =
    Provider((ref) => AdhanScheduler(ref.watch(localNotificationsProvider)));

/// Injectable clock (tests pin it).
final adhanClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class AdhanState {
  const AdhanState({
    this.settings = const AdhanSettings(),
    this.muezzins = const [],
    this.download,
    this.loaded = false,
    this.listLoading = false,
    this.listFailed = false,
    this.downloadingId,
    this.progress = 0,
    this.failedId,
  });

  final AdhanSettings settings;
  final List<Muezzin> muezzins;

  /// The selected muezzin's files on this device; null plays the default.
  final AdhanDownload? download;
  final bool loaded;
  final bool listLoading;

  /// The list request failed and nothing is cached.
  final bool listFailed;

  /// The muezzin being downloaded, with its 0…1 [progress].
  final String? downloadingId;
  final double progress;

  /// The muezzin whose last download failed.
  final String? failedId;

  Muezzin? get selected {
    for (final m in muezzins) {
      if (m.id == settings.muezzinId) return m;
    }
    return null;
  }

  AdhanState copyWith({
    AdhanSettings? settings,
    List<Muezzin>? muezzins,
    AdhanDownload? Function()? download,
    bool? loaded,
    bool? listLoading,
    bool? listFailed,
    String? Function()? downloadingId,
    double? progress,
    String? Function()? failedId,
  }) =>
      AdhanState(
        settings: settings ?? this.settings,
        muezzins: muezzins ?? this.muezzins,
        download: download != null ? download() : this.download,
        loaded: loaded ?? this.loaded,
        listLoading: listLoading ?? this.listLoading,
        listFailed: listFailed ?? this.listFailed,
        downloadingId:
            downloadingId != null ? downloadingId() : this.downloadingId,
        progress: progress ?? this.progress,
        failedId: failedId != null ? failedId() : this.failedId,
      );
}

/// Adhan settings, the muezzin list, downloads and the rolling schedule.
///
/// Reschedules on launch, after a download, and whenever the settings, the
/// prayer times (location) or the app language change.
class AdhanNotifier extends StateNotifier<AdhanState> {
  AdhanNotifier({
    required MuezzinRepository muezzins,
    required AdhanSettingsRepository repository,
    required AdhanAudioStore store,
    required AdhanScheduler scheduler,
    required List<DayPrayerTimes> Function() days,
    required bool Function() arabic,
    required DateTime Function() now,
    bool? ios,
    bool autoLoad = true,
  })  : _muezzins = muezzins,
        _repository = repository,
        _store = store,
        _scheduler = scheduler,
        _days = days,
        _arabic = arabic,
        _now = now,
        _ios = ios ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS),
        super(const AdhanState()) {
    if (autoLoad) _ready = load();
  }

  final MuezzinRepository _muezzins;
  final AdhanSettingsRepository _repository;
  final AdhanAudioStore _store;
  final AdhanScheduler _scheduler;
  final List<DayPrayerTimes> Function() _days;
  final bool Function() _arabic;
  final DateTime Function() _now;
  final bool _ios;

  Future<void>? _ready;
  Future<void> get ready => _ready ?? Future.value();

  /// Serialises reschedules so two syncs never interleave.
  Future<void> _sync = Future.value();

  Future<void> load() async {
    final settings = await _repository.loadSettings();
    var download = await _repository.loadDownload();
    final cached = await _muezzins.cached();
    // Files gone (cleared storage, restored backup): back to the default.
    if (download != null &&
        (download.muezzinId != settings.muezzinId ||
            !_store.isComplete(download))) {
      download = null;
      await _repository.saveDownload(null);
    }
    if (download != null) {
      download = await _store.republish(download);
      await _repository.saveDownload(download);
    }
    if (!mounted) return;
    state = state.copyWith(
      settings: settings,
      muezzins: cached,
      download: () => download,
      loaded: true,
    );
    await reschedule();
    await refreshList();
  }

  /// Refetches the muezzin list; downloads the selected one again when its
  /// version changed.
  Future<void> refreshList() async {
    if (state.listLoading) return;
    state = state.copyWith(listLoading: true, listFailed: false);
    try {
      final list = await _muezzins.refresh();
      if (!mounted) return;
      state = state.copyWith(muezzins: list, listLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
          listLoading: false, listFailed: state.muezzins.isEmpty);
      return;
    }
    final m = state.selected;
    final d = state.download;
    if (m != null && (d == null || d.version != m.version)) {
      await select(m);
    }
  }

  /// Downloads [m] and makes it the adhan. On failure the previous choice
  /// (or the bundled default) stays.
  Future<bool> select(Muezzin m) async {
    if (state.downloadingId != null) return false;
    state = state.copyWith(
        downloadingId: () => m.id, progress: 0, failedId: () => null);
    final AdhanDownload download;
    try {
      download = await _store.download(m, onProgress: (p) {
        if (mounted) state = state.copyWith(progress: p);
      });
    } catch (e) {
      debugPrint('Adhan: download failed: $e');
      if (mounted) {
        state = state.copyWith(downloadingId: () => null, failedId: () => m.id);
      }
      return false;
    }
    final settings = state.settings.copyWith(muezzinId: m.id);
    await _repository.saveDownload(download);
    await _repository.saveSettings(settings);
    await _store.deleteExcept(download);
    if (!mounted) return true;
    state = state.copyWith(
      settings: settings,
      download: () => download,
      downloadingId: () => null,
      progress: 1,
    );
    await reschedule();
    return true;
  }

  /// Back to the bundled adhan; deletes the downloaded files.
  Future<void> useDefault() async {
    final s = state.settings;
    final settings = AdhanSettings(
      enabled: s.enabled,
      prayers: s.prayers,
      reminderMinutes: s.reminderMinutes,
    );
    await _repository.saveSettings(settings);
    await _repository.saveDownload(null);
    await _store.deleteExcept(null);
    if (!mounted) return;
    state = state.copyWith(
        settings: settings, download: () => null, failedId: () => null);
    await reschedule();
  }

  Future<void> setEnabled(bool on) =>
      _update(state.settings.copyWith(enabled: on));

  Future<void> setPrayer(PrayerKind prayer, bool on) {
    final prayers = {...state.settings.prayers};
    on ? prayers.add(prayer) : prayers.remove(prayer);
    return _update(state.settings.copyWith(prayers: prayers));
  }

  Future<void> setReminder(int minutes) =>
      _update(state.settings.copyWith(reminderMinutes: minutes));

  Future<void> _update(AdhanSettings settings) async {
    if (settings == state.settings) return;
    state = state.copyWith(settings: settings);
    await _repository.saveSettings(settings);
    await reschedule();
  }

  /// Rebuilds the pending (silent) notifications for the next week.
  Future<void> reschedule() {
    if (!state.loaded) return Future.value();
    return _sync = _sync.then((_) async {
      if (!mounted) return;
      final s = state;
      final days = _days();
      // No times yet (they load after the settings at launch): keep what is
      // pending instead of cancelling it; the times listener reschedules.
      if (s.settings.enabled && days.isEmpty) return;
      final slots = AdhanPlanner.plan(
        days: days,
        settings: s.settings,
        now: _now(),
        ios: _ios,
      );
      try {
        await _scheduler.sync(
          slots,
          muezzinName: s.selected?.name(_arabic()),
          arabic: _arabic(),
        );
      } catch (e) {
        debugPrint('Adhan: scheduling failed: $e');
      }
    });
  }

  /// "Test the adhan": [prayer]'s notification with id [id] after [delay].
  Future<void> notifyTest(int id, PrayerKind prayer, Duration delay) =>
      _scheduler.scheduleTest(
        id,
        prayer,
        _now().add(delay),
        muezzinName: state.selected?.name(_arabic()),
        arabic: _arabic(),
      );

  /// The adhans (no reminders) from [from] on that the settings allow;
  /// what the app plays itself while it is open.
  List<AdhanSlot> adhansFrom(DateTime from) {
    if (!state.loaded) return const [];
    return [
      for (final s in AdhanPlanner.plan(
        days: _days(),
        settings: state.settings,
        now: from,
        ios: false,
      ))
        if (!s.reminder) s,
    ];
  }
}

/// What can stop the prayer-time notification from arriving on time.
class AdhanPermissions {
  const AdhanPermissions({this.notifications = true, this.exact = true});

  final bool notifications;

  /// Android 12+: exact alarms. Without them the notification can be an
  /// hour late.
  final bool exact;

  bool get ok => notifications && exact;
}

/// Checked on the settings screen; re-read when the app resumes (back from
/// a settings page).
final adhanPermissionsProvider =
    FutureProvider.autoDispose<AdhanPermissions>((ref) async {
  final n = ref.watch(localNotificationsProvider);
  return AdhanPermissions(
    notifications: await n.areEnabled(),
    exact: await n.canScheduleExact(),
  );
});

final adhanProvider = StateNotifierProvider<AdhanNotifier, AdhanState>((ref) {
  final notifier = AdhanNotifier(
    muezzins: ref.watch(muezzinRepositoryProvider),
    repository: ref.watch(adhanSettingsRepositoryProvider),
    store: ref.watch(adhanAudioStoreProvider),
    scheduler: ref.watch(adhanSchedulerProvider),
    days: () => ref.read(upcomingPrayerDaysProvider),
    arabic: () => ref.read(localeOptionProvider) == AppLocaleOption.arabic,
    now: ref.watch(adhanClockProvider),
  );
  // New times (another day fetched, the location moved) or a new language.
  // The list is rebuilt on every publish, so compare what it holds.
  String signature(List<DayPrayerTimes>? days) => [
        for (final d in days ?? const <DayPrayerTimes>[])
          '${d.key}:${d.fajr.millisecondsSinceEpoch}:'
              '${d[PrayerKind.isha].millisecondsSinceEpoch}',
      ].join(',');
  ref.listen(upcomingPrayerDaysProvider, (prev, next) {
    if (signature(prev) != signature(next)) notifier.reschedule();
  });
  ref.listen(localeOptionProvider, (_, __) => notifier.reschedule());
  return notifier;
});
