import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_settings_enum.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/khatma_notifications.dart';
import '../data/khatma_repository.dart';
import '../domain/khatma.dart';
import '../domain/khatma_planner.dart';

final khatmaRepositoryProvider = Provider((ref) => KhatmaRepository());

final khatmaNotificationsProvider = Provider(
    (ref) => KhatmaNotifications(ref.watch(localNotificationsProvider)));

/// The khatma's clock (overridden in tests).
final khatmaClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

class KhatmaState {
  const KhatmaState({
    this.loaded = false,
    this.active,
    this.history = const [],
    this.logs = const [],
    this.canUndo = false,
  });

  final bool loaded;

  /// The active or paused khatma (one at a time).
  final Khatma? active;

  /// Completed khatmas, newest first.
  final List<Khatma> history;
  final List<DailyLog> logs;

  /// The last progress update can be taken back.
  final bool canUndo;

  /// [khatmaId]'s log, newest day first.
  List<DailyLog> logsOf(String khatmaId) =>
      logs.where((l) => l.khatmaId == khatmaId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  Khatma? byId(String id) =>
      active?.id == id ? active : history.where((k) => k.id == id).firstOrNull;
}

/// What a progress update led to.
enum KhatmaProgress { unchanged, saved, completed }

class KhatmaNotifier extends StateNotifier<KhatmaState> {
  KhatmaNotifier({
    required KhatmaRepository repository,
    required KhatmaNotifications notifications,
    required DateTime Function() now,
    required bool Function() arabic,
  })  : _repository = repository,
        _notifications = notifications,
        _now = now,
        _arabic = arabic,
        super(const KhatmaState()) {
    ready = _load();
  }

  final KhatmaRepository _repository;
  final KhatmaNotifications _notifications;
  final DateTime Function() _now;
  final bool Function() _arabic;

  /// Completes once the saved khatma has been read.
  late final Future<void> ready;

  /// The state before the last progress update, for [undo].
  KhatmaState? _beforeLast;

  /// Writes go one after another, each saving the state of its time.
  Future<void> _writes = Future.value();

  DateTime get _today => dateOnly(_now());

  Future<void> _load() async {
    final active = await _repository.loadActive();
    final history = await _repository.loadHistory();
    final logs = await _repository.loadLogs();
    if (!mounted) return;
    state = KhatmaState(
      loaded: true,
      active: active == null ? null : KhatmaPlanner.startDay(active, _today),
      history: history,
      logs: logs,
    );
    if (!identical(state.active, active)) await _persist();
    await _sync();
  }

  /// A new day, or back in the app: fixes today's portion and replans the
  /// reminders.
  Future<void> refresh() async {
    await ready;
    final active = state.active;
    if (active != null) {
      final rolled = KhatmaPlanner.startDay(active, _today);
      if (!identical(rolled, active)) {
        _set(active: rolled, keepUndo: true);
        await _persist();
      }
    }
    await _sync();
  }

  /// Replans the reminders, e.g. for a new language.
  Future<void> resync() => _sync();

  Future<void> create({
    required DateTime endDate,
    required int startPage,
    required ReadingUnit displayUnit,
    required bool morningEnabled,
    required int morningMinutes,
    required bool eveningEnabled,
    required int eveningMinutes,
  }) async {
    await ready;
    final now = _now();
    _set(
      active: KhatmaPlanner.create(
        id: 'k${now.microsecondsSinceEpoch}',
        today: now,
        endDate: endDate,
        startPage: startPage,
        displayUnit: displayUnit,
        morningEnabled: morningEnabled,
        morningMinutes: morningMinutes,
        eveningEnabled: eveningEnabled,
        eveningMinutes: eveningMinutes,
      ),
    );
    await _save();
  }

  /// Edits the active khatma. A new end date replans today from where the
  /// day began; today's pages and log stay.
  Future<void> edit({
    required DateTime endDate,
    required ReadingUnit displayUnit,
    required bool morningEnabled,
    required int morningMinutes,
    required bool eveningEnabled,
    required int eveningMinutes,
  }) async {
    var k = state.active;
    if (k == null) return;
    if (daysBetween(k.endDate, endDate) != 0 &&
        k.status == KhatmaStatus.active) {
      k = KhatmaPlanner.reschedule(k, endDate, _today);
    } else if (daysBetween(k.endDate, endDate) != 0) {
      k = k.copyWith(endDate: dateOnly(endDate));
    }
    _set(
      active: k.copyWith(
        displayUnit: displayUnit,
        morningEnabled: morningEnabled,
        morningMinutes: morningMinutes,
        eveningEnabled: eveningEnabled,
        eveningMinutes: eveningMinutes,
      ),
    );
    await _save();
  }

  /// "I reached page [page]" — forward, or back to fix a mistake.
  Future<KhatmaProgress> reachPage(int page) async {
    final k = state.active;
    if (k == null || k.status != KhatmaStatus.active) {
      return KhatmaProgress.unchanged;
    }
    final today = _today;
    final moved = KhatmaPlanner.reachPage(k, page, today);
    if (moved.lastPageRead == k.lastPageRead) return KhatmaProgress.unchanged;

    final before = state;
    final logs = KhatmaPlanner.logProgress(
      state.logs,
      khatmaId: k.id,
      today: today,
      from: k.lastPageRead,
      to: moved.lastPageRead,
    );
    if (moved.finished) {
      final done = KhatmaPlanner.complete(moved, _now());
      _set(active: null, history: [done, ...state.history], logs: logs);
    } else {
      _set(active: moved, logs: logs);
    }
    _beforeLast = before;
    state = _copy(canUndo: true);
    await _save();
    return moved.finished ? KhatmaProgress.completed : KhatmaProgress.saved;
  }

  Future<KhatmaProgress> addPages(int pages) async {
    final k = state.active;
    if (k == null) return KhatmaProgress.unchanged;
    return reachPage(k.lastPageRead + pages);
  }

  Future<KhatmaProgress> addHizb() async {
    final k = state.active;
    if (k == null) return KhatmaProgress.unchanged;
    return reachPage(KhatmaPlanner.afterOneHizb(k.lastPageRead));
  }

  /// Today's portion is read: up to its target page, logged.
  Future<KhatmaProgress> markTodayDone() async {
    final k = state.active;
    if (k == null) return KhatmaProgress.unchanged;
    final target = KhatmaPlanner.dayPlan(k, _today).targetPage;
    return reachPage(math.max(k.lastPageRead, target));
  }

  /// Takes back the last progress update (a completion included).
  Future<bool> undo() async {
    final before = _beforeLast;
    if (before == null) return false;
    _beforeLast = null;
    state = KhatmaState(
      loaded: true,
      active: before.active,
      history: before.history,
      logs: before.logs,
    );
    await _save();
    return true;
  }

  Future<void> pause() => _update((k) =>
      k.status == KhatmaStatus.active ? KhatmaPlanner.pause(k, _today) : k);

  Future<void> resume() => _update((k) =>
      k.status == KhatmaStatus.paused ? KhatmaPlanner.resume(k, _today) : k);

  /// Past the end date: [days] more days from today.
  Future<void> extend(int days) =>
      _update((k) => KhatmaPlanner.extend(k, days, _today));

  /// Past the end date: carry on with everything left as today's target.
  Future<void> keepOverdue() => _update((k) => k.copyWith(overdueKept: true));

  /// Drops the active khatma and its log.
  Future<void> delete() async {
    final k = state.active;
    if (k == null) return;
    _set(
      active: null,
      logs: state.logs.where((l) => l.khatmaId != k.id).toList(),
    );
    await _save();
  }

  /// Removes a completed khatma from the list.
  Future<void> deleteCompleted(String id) async {
    _set(
      history: state.history.where((k) => k.id != id).toList(),
      logs: state.logs.where((l) => l.khatmaId != id).toList(),
    );
    await _save();
  }

  Future<void> _update(Khatma Function(Khatma k) change) async {
    final k = state.active;
    if (k == null) return;
    _set(active: change(k));
    await _save();
  }

  static const Object _keep = Object();

  /// Sets parts of the state; any change but a progress update (which
  /// sets its own) ends the chance to undo.
  void _set({
    Object? active = _keep,
    List<Khatma>? history,
    List<DailyLog>? logs,
    bool keepUndo = false,
  }) {
    if (!keepUndo) _beforeLast = null;
    state = KhatmaState(
      loaded: true,
      active: identical(active, _keep) ? state.active : active as Khatma?,
      history: history ?? state.history,
      logs: logs ?? state.logs,
      canUndo: keepUndo && state.canUndo,
    );
  }

  KhatmaState _copy({required bool canUndo}) => KhatmaState(
        loaded: state.loaded,
        active: state.active,
        history: state.history,
        logs: state.logs,
        canUndo: canUndo,
      );

  Future<void> _save() async {
    await _persist();
    await _sync();
  }

  Future<void> _persist() {
    final snapshot = state;
    return _writes = _writes.then((_) async {
      await _repository.saveActive(snapshot.active);
      await _repository.saveHistory(snapshot.history);
      await _repository.saveLogs(snapshot.logs);
    });
  }

  Future<void> _sync() async {
    try {
      await _notifications.sync(state.active, now: _now(), arabic: _arabic());
    } catch (e) {
      // A reminder that can't be scheduled must never block the reading.
      debugPrint('Khatma reminders not scheduled: $e');
    }
  }
}

final khatmaProvider =
    StateNotifierProvider<KhatmaNotifier, KhatmaState>((ref) {
  final notifier = KhatmaNotifier(
    repository: ref.watch(khatmaRepositoryProvider),
    notifications: ref.watch(khatmaNotificationsProvider),
    now: ref.watch(khatmaClockProvider),
    arabic: () => ref.read(localeOptionProvider) == AppLocaleOption.arabic,
  );
  ref.listen(localeOptionProvider, (_, __) => notifier.resync());
  return notifier;
});
