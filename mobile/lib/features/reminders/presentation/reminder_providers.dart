import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_settings_enum.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../adhan/presentation/adhan_providers.dart';
import '../../prayer_times/domain/prayer_times.dart';
import '../../prayer_times/presentation/prayer_times_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/reminder_notifications.dart';
import '../domain/reminder_plan.dart';

final reminderSettingsRepositoryProvider =
    Provider((ref) => ReminderSettingsRepository());

final reminderNotificationsProvider = Provider(
    (ref) => ReminderNotifications(ref.watch(localNotificationsProvider)));

class ReminderState {
  const ReminderState({
    this.frequency = ReminderFrequency.defaultValue,
    this.loaded = false,
  });

  final ReminderFrequency frequency;
  final bool loaded;
}

/// The adhkar and surah reminders: the chosen frequency and the rolling
/// schedule. Reschedules on launch, on resume, and when the frequency, the
/// prayer times or the language change.
class ReminderNotifier extends StateNotifier<ReminderState> {
  ReminderNotifier({
    required ReminderSettingsRepository repository,
    required ReminderNotifications notifications,
    required List<DayPrayerTimes> Function() days,
    required bool Function() arabic,
    required DateTime Function() now,
    Future<void> Function()? keepDaily,
    bool? ios,
    bool autoLoad = true,
  })  : _repository = repository,
        _notifications = notifications,
        _days = days,
        _arabic = arabic,
        _now = now,
        _keepDaily = keepDaily,
        _ios = ios ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS),
        super(const ReminderState()) {
    if (autoLoad) _ready = _load();
  }

  final ReminderSettingsRepository _repository;
  final ReminderNotifications _notifications;
  final List<DayPrayerTimes> Function() _days;
  final bool Function() _arabic;
  final DateTime Function() _now;
  final Future<void> Function()? _keepDaily;
  final bool _ios;

  Future<void>? _ready;
  Future<void> get ready => _ready ?? Future.value();
  Future<void> _sync = Future.value();

  Future<void> _load() async {
    final f = await _repository.load();
    if (!mounted) return;
    state = ReminderState(frequency: f, loaded: true);
    await reschedule();
  }

  Future<void> setFrequency(ReminderFrequency f) async {
    if (f == state.frequency) return;
    state = ReminderState(frequency: f, loaded: true);
    await _repository.save(f);
    await reschedule();
  }

  /// Today's reminders at [frequency] (every kind, sent or not), for the
  /// settings screen's day. Empty until the prayer times are known.
  List<({ReminderKind kind, DateTime at})> today() {
    final now = _now();
    for (final d in _days()) {
      if (d.date.year == now.year &&
          d.date.month == now.month &&
          d.date.day == now.day) {
        return [for (final k in ReminderKind.values) (kind: k, at: k.timeOn(d))];
      }
    }
    return const [];
  }

  Future<void> reschedule() {
    if (!state.loaded) return Future.value();
    return _sync = _sync.then((_) async {
      if (!mounted) return;
      final days = _days();
      final frequency = state.frequency;
      // No times yet: keep what is pending; the times listener reschedules.
      if (frequency != ReminderFrequency.off && days.isEmpty) return;
      final slots = ReminderPlanner.plan(
          days: days, frequency: frequency, now: _now(), ios: _ios);
      try {
        await _notifications.sync(slots, arabic: _arabic());
        // Android: the daily worker tops the week up with the app closed.
        if (slots.isNotEmpty) await _keepDaily?.call();
      } catch (e) {
        debugPrint('Reminders: scheduling failed: $e');
      }
    });
  }
}

final reminderProvider =
    StateNotifierProvider<ReminderNotifier, ReminderState>((ref) {
  final native = ref.watch(adhanAlarmPlatformProvider);
  final notifier = ReminderNotifier(
    repository: ref.watch(reminderSettingsRepositoryProvider),
    notifications: ref.watch(reminderNotificationsProvider),
    days: () => ref.read(upcomingPrayerDaysProvider),
    arabic: () => ref.read(localeOptionProvider) == AppLocaleOption.arabic,
    now: ref.watch(adhanClockProvider),
    keepDaily: native.supported ? native.ensureDaily : null,
  );
  String signature(List<DayPrayerTimes>? days) => [
        for (final d in days ?? const <DayPrayerTimes>[])
          '${d.key}:${d.fajr.millisecondsSinceEpoch}',
      ].join(',');
  ref.listen(upcomingPrayerDaysProvider, (prev, next) {
    if (signature(prev) != signature(next)) notifier.reschedule();
  });
  ref.listen(localeOptionProvider, (_, __) => notifier.reschedule());
  return notifier;
});
