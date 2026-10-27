import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/constants/app_settings_enum.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/fajr_call_platform.dart';
import '../data/fajr_call_repository.dart';
import '../data/fajr_notifications.dart';
import '../data/fajr_schedule.dart';
import '../domain/call_attempt.dart';
import '../domain/call_session.dart';
import '../domain/fajr_call_list.dart';
import '../domain/fajr_contact.dart';
import '../domain/prayer_settings.dart';

final fajrCallRepositoryProvider = Provider((ref) => FajrCallRepository());
final fajrCallPlatformProvider = Provider((ref) => const FajrCallPlatform());
final fajrScheduleProvider = Provider((ref) => const FajrSchedule());
final fajrNotificationsProvider = Provider(
    (ref) => FajrNotifications(ref.watch(localNotificationsProvider)));

/// Injectable clock (tests pin it).
final fajrClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class FajrCallState {
  const FajrCallState({
    this.lists = const [],
    this.sessions = const [],
    this.prayer = const PrayerSettings(),
    this.autoSupported = false,
    this.permissions = const FajrNativePermissions(),
    this.loaded = false,
  });

  final List<FajrCallList> lists;

  /// Newest first, every list.
  final List<CallSession> sessions;
  final PrayerSettings prayer;

  /// This device runs the Android call engine.
  final bool autoSupported;
  final FajrNativePermissions permissions;
  final bool loaded;

  FajrCallList? listById(String id) {
    for (final l in lists) {
      if (l.id == id) return l;
    }
    return null;
  }

  List<CallSession> sessionsOf(String listId) =>
      [for (final s in sessions) if (s.listId == listId) s];

  /// The mode a list really runs in: auto needs the engine and the call
  /// permissions, otherwise it falls back to the notification + wake list.
  FajrCallMode effectiveMode(FajrCallList list) =>
      list.mode == FajrCallMode.auto && autoSupported && permissions.canAutoCall
          ? FajrCallMode.auto
          : FajrCallMode.manual;

  FajrCallState copyWith({
    List<FajrCallList>? lists,
    List<CallSession>? sessions,
    PrayerSettings? prayer,
    bool? autoSupported,
    FajrNativePermissions? permissions,
    bool? loaded,
  }) =>
      FajrCallState(
        lists: lists ?? this.lists,
        sessions: sessions ?? this.sessions,
        prayer: prayer ?? this.prayer,
        autoSupported: autoSupported ?? this.autoSupported,
        permissions: permissions ?? this.permissions,
        loaded: loaded ?? this.loaded,
      );
}

class FajrCallNotifier extends StateNotifier<FajrCallState> {
  FajrCallNotifier({
    required FajrCallRepository repository,
    required FajrCallPlatform platform,
    required FajrNotifications notifications,
    required FajrSchedule schedule,
    required DateTime Function() now,
    required bool Function() arabic,
    bool autoLoad = true,
  })  : _repository = repository,
        _platform = platform,
        _notifications = notifications,
        _schedule = schedule,
        _now = now,
        _arabic = arabic,
        super(const FajrCallState()) {
    if (autoLoad) _ready = load();
  }

  final FajrCallRepository _repository;
  final FajrCallPlatform _platform;
  final FajrNotifications _notifications;
  final FajrSchedule _schedule;
  final DateTime Function() _now;
  final bool Function() _arabic;
  Future<void>? _ready;

  Future<void> get ready => _ready ?? Future.value();

  Future<void> load() async {
    final lists = await _repository.loadLists();
    final prayer = await _repository.loadPrayerSettings();
    final autoSupported = await _platform.isAutoCallSupported();
    final permissions = await _platform.permissions();
    final sessions =
        await _repository.upsertSessions(await _platform.takeSessions());
    if (!mounted) return;
    state = state.copyWith(
      lists: lists,
      prayer: prayer,
      sessions: sessions,
      autoSupported: autoSupported,
      permissions: permissions,
      loaded: true,
    );
    await _expireOneOffs();
    await resync();
  }

  /// On app resume: picks up sessions the engine wrote, permission changes
  /// made in system settings, and reschedules (Fajr moves every day).
  Future<void> refresh() async {
    await ready;
    final incoming = await _platform.takeSessions();
    final permissions = await _platform.permissions();
    final sessions = incoming.isEmpty
        ? state.sessions
        : await _repository.upsertSessions(incoming);
    if (!mounted) return;
    state = state.copyWith(sessions: sessions, permissions: permissions);
    await _expireOneOffs();
    await resync();
  }

  Future<void> refreshPermissions() async {
    final permissions = await _platform.permissions();
    if (!mounted) return;
    state = state.copyWith(permissions: permissions);
    await resync();
  }

  Future<void> requestCallPermissions() async {
    final permissions = await _platform.requestCallPermissions();
    if (!mounted) return;
    state = state.copyWith(permissions: permissions);
    await resync();
  }

  /// Adds or replaces [list]. Arms a one-off list when it is switched on.
  Future<void> saveList(FajrCallList list) async {
    await ready;
    final armed = list.enabled && !list.repeatDaily
        ? list.copyWith(armedAt: list.armedAt ?? _now())
        : list;
    final exists = state.lists.any((l) => l.id == list.id);
    final lists = exists
        ? [for (final l in state.lists) l.id == list.id ? armed : l]
        : [...state.lists, armed];
    await _setLists(lists);
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final list = state.listById(id);
    if (list == null) return;
    // Re-arming a one-off list starts from now.
    await saveList(FajrCallList.fromJson({
      ...list.toJson(),
      'enabled': enabled,
    }..remove('armedAt')));
  }

  Future<void> deleteList(String id) async {
    await _setLists([for (final l in state.lists) if (l.id != id) l]);
  }

  Future<void> setPrayerSettings(PrayerSettings prayer) async {
    await _repository.savePrayerSettings(prayer);
    state = state.copyWith(prayer: prayer);
    await resync();
  }

  /// The wake-list session for [list] fired at [at] (manual mode), or a
  /// fresh one if nothing was recorded yet.
  CallSession wakeSession(FajrCallList list, DateTime at) {
    final id = manualSessionId(list.id, at);
    for (final s in state.sessions) {
      if (s.id == id) return s;
    }
    return CallSession(
      id: id,
      listId: list.id,
      listName: list.name,
      firedAt: at,
      mode: FajrCallMode.manual,
    );
  }

  static String manualSessionId(String listId, DateTime at) =>
      'm_${listId}_${at.millisecondsSinceEpoch}';

  /// Logs a call placed from the wake list.
  Future<void> logManualCall(CallSession session, FajrContact contact) async {
    final now = _now();
    final previous =
        session.attempts.where((a) => a.contact.id == contact.id && a.status.isCall);
    await _upsertSession(session.copyWith(attempts: [
      ...session.attempts,
      CallAttempt(
        contact: contact,
        startedAt: now,
        status: CallStatus.called,
        attemptNo: previous.length + 1,
      ),
    ]));
  }

  Future<void> markAwake(CallSession session, FajrContact contact,
      {required bool awake}) async {
    await _upsertSession(session.markAwake(contact, _now(), awake: awake));
  }

  /// Clears the log of one list, or of every list when [listId] is null.
  Future<void> clearLog({String? listId}) async {
    final kept = listId == null
        ? <CallSession>[]
        : [for (final s in state.sessions) if (s.listId != listId) s];
    await _repository.saveSessions(kept);
    state = state.copyWith(sessions: kept);
  }

  /// "Test now": runs an auto list immediately on Android.
  Future<bool> runNow(FajrCallList list) =>
      _platform.runNow(list, nativeStrings(_arabic()));

  Future<void> _upsertSession(CallSession session) async {
    final sessions = await _repository.upsertSessions([session]);
    if (!mounted) return;
    state = state.copyWith(sessions: sessions);
  }

  Future<void> _setLists(List<FajrCallList> lists) async {
    await _repository.saveLists(lists);
    if (!mounted) return;
    state = state.copyWith(lists: lists);
    await resync();
  }

  /// Switches off one-off lists whose single occurrence has passed.
  Future<void> _expireOneOffs() async {
    final now = _now();
    bool expired(FajrCallList l) =>
        l.enabled &&
        !l.repeatDaily &&
        l.armedAt != null &&
        // Without a location a Fajr list has no times at all; that is not
        // the same as having run.
        (l.startMode == FajrStartMode.fixed || state.prayer.hasLocation) &&
        _schedule.nextFireTimes(l, state.prayer, from: now).isEmpty;
    if (!state.lists.any(expired)) return;
    final lists = [
      for (final l in state.lists) expired(l) ? l.copyWith(enabled: false) : l,
    ];
    await _repository.saveLists(lists);
    if (mounted) state = state.copyWith(lists: lists);
  }

  /// Pushes the current schedule to the native engine (auto lists) and to
  /// the notification layer (manual lists). Called after every change and
  /// on resume, because Fajr moves every day.
  Future<void> resync() async {
    final now = _now();
    final arabic = _arabic();
    final auto = <({FajrCallList list, List<DateTime> fireTimes})>[];
    final manual = <({FajrCallList list, List<tz.TZDateTime> times})>[];
    for (final list in state.lists) {
      if (!list.enabled || list.contacts.isEmpty) continue;
      final times = _schedule.nextFireTimes(list, state.prayer, from: now);
      if (times.isEmpty) continue;
      if (state.effectiveMode(list) == FajrCallMode.auto) {
        auto.add((list: list, fireTimes: times));
      } else {
        manual.add((list: list, times: times));
      }
    }
    try {
      if (state.autoSupported) {
        await _platform.sync(lists: auto, strings: nativeStrings(arabic));
      }
      await _notifications.sync(manual, arabic: arabic);
    } catch (e) {
      // Scheduling must never break the UI; the next resume retries.
      debugPrint('Fajr Call resync failed: $e');
    }
  }

  static FajrNativeStrings nativeStrings(bool arabic) => arabic
      ? const FajrNativeStrings(
          channelName: 'نداء الفجر',
          title: 'نداء الفجر',
          callingTemplate: 'جارٍ الاتصال بـ %s…',
          waitingText: 'بين اتصالين…',
          stopLabel: 'إيقاف',
          doneText: 'انتهى نداء الفجر. افتح السجل لترى من أجاب.',
        )
      : const FajrNativeStrings(
          channelName: 'Fajr Call',
          title: 'Fajr Call',
          callingTemplate: 'Calling %s…',
          waitingText: 'Between calls…',
          stopLabel: 'Stop',
          doneText: 'Fajr Call finished. Open the log to see the results.',
        );
}

final fajrCallProvider =
    StateNotifierProvider<FajrCallNotifier, FajrCallState>((ref) {
  return FajrCallNotifier(
    repository: ref.watch(fajrCallRepositoryProvider),
    platform: ref.watch(fajrCallPlatformProvider),
    notifications: ref.watch(fajrNotificationsProvider),
    schedule: ref.watch(fajrScheduleProvider),
    now: ref.watch(fajrClockProvider),
    arabic: () => ref.read(localeOptionProvider).languageCode == 'ar',
  );
});

/// Next fire time of a list, or null when it has none (disabled, no
/// location yet, or a one-off that already ran).
final fajrNextFireProvider =
    Provider.family<tz.TZDateTime?, String>((ref, listId) {
  final state = ref.watch(fajrCallProvider);
  final list = state.listById(listId);
  if (list == null || !list.enabled) return null;
  return ref.watch(fajrScheduleProvider).next(list, state.prayer,
      from: ref.watch(fajrClockProvider)());
});

/// The earliest upcoming fire among enabled lists, for the Home card.
final fajrUpcomingProvider =
    Provider<({FajrCallList list, tz.TZDateTime at})?>((ref) {
  final state = ref.watch(fajrCallProvider);
  ({FajrCallList list, tz.TZDateTime at})? best;
  for (final l in state.lists) {
    if (!l.enabled || l.contacts.isEmpty) continue;
    final at = ref.watch(fajrNextFireProvider(l.id));
    if (at != null && (best == null || at.isBefore(best.at))) {
      best = (list: l, at: at);
    }
  }
  return best;
});
