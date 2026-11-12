import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_settings_enum.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../adhan/presentation/adhan_providers.dart';
import '../../prayer_times/domain/prayer_times.dart';
import '../../prayer_times/presentation/prayer_times_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/prayer_banner_platform.dart';

final prayerBannerSettingsRepositoryProvider =
    Provider((ref) => PrayerBannerSettingsRepository());

final prayerBannerPlatformProvider = Provider((ref) =>
    PrayerBannerPlatform(android: ref.watch(adhanAlarmPlatformProvider)));

class PrayerBannerState {
  const PrayerBannerState({this.enabled = true, this.loaded = false});

  final bool enabled;
  final bool loaded;
}

/// The prayer-times banner: in the notification shade on Android, a Live
/// Activity on iOS. Re-synced on launch, on resume, and when the switch, the
/// prayer times or the language change.
class PrayerBannerNotifier extends StateNotifier<PrayerBannerState> {
  PrayerBannerNotifier({
    required PrayerBannerSettingsRepository repository,
    required PrayerBannerPlatform platform,
    required List<DayPrayerTimes> Function() days,
    required bool Function() arabic,
    required DateTime Function() now,
    Future<bool> Function()? requestPermission,
    bool autoLoad = true,
  })  : _repository = repository,
        _platform = platform,
        _days = days,
        _arabic = arabic,
        _now = now,
        _requestPermission = requestPermission,
        super(const PrayerBannerState()) {
    if (autoLoad) _ready = _load();
  }

  final PrayerBannerSettingsRepository _repository;
  final PrayerBannerPlatform _platform;
  final List<DayPrayerTimes> Function() _days;
  final bool Function() _arabic;
  final DateTime Function() _now;
  final Future<bool> Function()? _requestPermission;

  Future<void>? _ready;
  Future<void> get ready => _ready ?? Future.value();
  Future<void> _sync = Future.value();

  bool get supported => _platform.supported;

  Future<void> _load() async {
    final enabled = await _repository.load();
    if (!mounted) return;
    state = PrayerBannerState(enabled: enabled, loaded: true);
    await refresh();
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled == state.enabled) return;
    state = PrayerBannerState(enabled: enabled, loaded: true);
    await _repository.save(enabled);
    // Android 13+: the banner is a notification and needs the permission.
    if (enabled) await _requestPermission?.call();
    await refresh();
  }

  Future<void> refresh() {
    if (!state.loaded) return Future.value();
    return _sync = _sync.then((_) async {
      if (!mounted) return;
      final days = _days();
      // No times yet: leave the banner as it is. The times listener calls
      // again once they load.
      if (state.enabled && days.isEmpty) return;
      try {
        await _platform.sync(
          enabled: state.enabled,
          days: days,
          arabic: _arabic(),
          now: _now(),
        );
      } catch (e) {
        debugPrint('Prayer banner: sync failed: $e');
      }
    });
  }
}

final prayerBannerProvider =
    StateNotifierProvider<PrayerBannerNotifier, PrayerBannerState>((ref) {
  final notifier = PrayerBannerNotifier(
    repository: ref.watch(prayerBannerSettingsRepositoryProvider),
    platform: ref.watch(prayerBannerPlatformProvider),
    days: () => ref.read(upcomingPrayerDaysProvider),
    arabic: () => ref.read(localeOptionProvider) == AppLocaleOption.arabic,
    now: ref.watch(adhanClockProvider),
    requestPermission: ref.read(localNotificationsProvider).requestPermission,
  );
  String signature(List<DayPrayerTimes>? days) => [
        for (final d in days ?? const <DayPrayerTimes>[])
          '${d.key}:${d.fajr.millisecondsSinceEpoch}',
      ].join(',');
  ref.listen(upcomingPrayerDaysProvider, (prev, next) {
    if (signature(prev) != signature(next)) notifier.refresh();
  });
  ref.listen(localeOptionProvider, (_, __) => notifier.refresh());
  return notifier;
});
