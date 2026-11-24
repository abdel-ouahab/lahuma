import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_settings_enum.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/calendar_notifications.dart';
import '../data/calendar_repository.dart';
import '../domain/calendar_reminders.dart';
import '../domain/hijri_date.dart';
import '../domain/islamic_events.dart';

final calendarRepositoryProvider = Provider((ref) => CalendarRepository());

final calendarNotificationsProvider = Provider(
    (ref) => CalendarNotifications(ref.watch(localNotificationsProvider)));

/// The calendar's clock (overridden in tests).
final calendarClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

class CalendarState {
  const CalendarState({
    this.loaded = false,
    this.settings = const CalendarSettings(),
  });

  final bool loaded;
  final CalendarSettings settings;
}

/// The calendar's settings and the occasion reminders they schedule.
class CalendarNotifier extends StateNotifier<CalendarState> {
  CalendarNotifier({
    required CalendarRepository repository,
    required CalendarNotifications notifications,
    required DateTime Function() now,
    required bool Function() arabic,
    bool? ios,
  })  : _repository = repository,
        _notifications = notifications,
        _now = now,
        _arabic = arabic,
        _ios = ios ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS),
        super(const CalendarState()) {
    ready = _load();
  }

  final CalendarRepository _repository;
  final CalendarNotifications _notifications;
  final DateTime Function() _now;
  final bool Function() _arabic;
  final bool _ios;

  late final Future<void> ready;
  Future<void> _sync = Future.value();

  Future<void> _load() async {
    final settings = await _repository.load();
    if (!mounted) return;
    state = CalendarState(loaded: true, settings: settings);
    await reschedule();
  }

  Future<void> setRemindersOn(bool on) =>
      _update(state.settings.copyWith(remindersOn: on));

  Future<void> setTiming(CalendarReminderTiming timing) =>
      _update(state.settings.copyWith(timing: timing));

  /// Turns one occasion's reminder on or off; turning one on also turns
  /// the reminders on.
  Future<void> setReminded(IslamicEvent event, bool on) {
    final events = {...state.settings.events};
    on ? events.add(event) : events.remove(event);
    return _update(state.settings.copyWith(
      events: events,
      remindersOn: on ? true : null,
    ));
  }

  Future<void> setAdjustment(int days) => _update(state.settings.copyWith(
      adjustment: days.clamp(
          -CalendarSettings.maxAdjustment, CalendarSettings.maxAdjustment)));

  Future<void> _update(CalendarSettings settings) async {
    await ready;
    if (!mounted) return;
    state = CalendarState(loaded: true, settings: settings);
    await _repository.save(settings);
    await reschedule();
  }

  /// Replaces the pending reminders from today on: on launch, on resume (a
  /// new day), and after any change.
  Future<void> reschedule() {
    if (!state.loaded) return Future.value();
    return _sync = _sync.then((_) async {
      if (!mounted) return;
      final s = state.settings;
      final now = _now();
      final occurrences = s.remindersOn
          ? IslamicEventCalendar(HijriConverter(adjustment: s.adjustment))
              .between(now, now.add(CalendarReminderPlanner.horizon))
          : const <EventOccurrence>[];
      final reminders = CalendarReminderPlanner.plan(
          occurrences: occurrences, settings: s, now: now, ios: _ios);
      try {
        await _notifications.sync(reminders, arabic: _arabic());
      } catch (e) {
        debugPrint('Calendar: reminders not scheduled: $e');
      }
    });
  }
}

final calendarProvider =
    StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  final notifier = CalendarNotifier(
    repository: ref.watch(calendarRepositoryProvider),
    notifications: ref.watch(calendarNotificationsProvider),
    now: ref.watch(calendarClockProvider),
    arabic: () => ref.read(localeOptionProvider) == AppLocaleOption.arabic,
  );
  ref.listen(localeOptionProvider, (_, __) => notifier.reschedule());
  return notifier;
});

/// Gregorian ↔ Hijri with the user's adjustment.
final hijriConverterProvider = Provider((ref) => HijriConverter(
    adjustment:
        ref.watch(calendarProvider.select((s) => s.settings.adjustment))));

final islamicEventCalendarProvider =
    Provider((ref) => IslamicEventCalendar(ref.watch(hijriConverterProvider)));

/// The occasions from today for about a year, earliest first, with those
/// under way today (the white days, Tashreeq…) included.
final upcomingOccasionsProvider = Provider<List<EventOccurrence>>((ref) {
  final now = ref.watch(calendarClockProvider)();
  return ref
      .watch(islamicEventCalendarProvider)
      .between(now, now.add(const Duration(days: 365)), ongoing: true);
});
