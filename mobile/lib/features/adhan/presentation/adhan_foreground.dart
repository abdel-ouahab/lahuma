import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/app_router.dart';
import '../../prayer_times/domain/prayer_times.dart';
import '../../prayer_times/presentation/prayer_times_providers.dart';
import '../data/adhan_scheduler.dart';
import '../domain/adhan_plan.dart';
import '../domain/adhan_settings.dart';
import 'adhan_providers.dart';

/// Plays the adhan through the app's own player when a prayer time comes
/// while the app is open.
///
/// Only while [active] (the app in the foreground): one timer for the next
/// adhan, re-armed whenever the app comes back, the settings or the times
/// change. In the background or closed nothing plays; the silent
/// notification is all the user gets, and a tap opens the player.
///
/// Each adhan plays once: the last played id is kept (ids grow with time),
/// so coming back to the app, or the notification's tap, doesn't play it
/// again.
class AdhanForeground {
  AdhanForeground({
    required List<AdhanSlot> Function(DateTime from) adhans,
    required DateTime Function() now,
    required void Function(AdhanSlot slot) onAdhan,
    required Future<int?> Function() loadLastPlayed,
    required Future<void> Function(int id) saveLastPlayed,
    Timer Function(Duration, void Function())? timer,
  })  : _adhans = adhans,
        _now = now,
        _onAdhan = onAdhan,
        _saveLastPlayed = saveLastPlayed,
        _timer = timer ?? Timer.new {
    _lastPlayed = loadLastPlayed().then((id) => _last = id ?? _last);
  }

  final List<AdhanSlot> Function(DateTime from) _adhans;
  final DateTime Function() _now;
  final void Function(AdhanSlot slot) _onAdhan;
  final Future<void> Function(int id) _saveLastPlayed;
  final Timer Function(Duration, void Function()) _timer;

  /// An adhan still plays when the app comes back this soon after its time.
  static const Duration grace = Duration(minutes: 1);

  /// How long "Test the adhan" waits.
  static const Duration testDelay = Duration(seconds: 10);

  late final Future<void> _lastPlayed;
  int _last = 0;
  bool _active = false;
  Timer? _next;
  final List<AdhanSlot> _tests = [];

  /// Bumped by every [refresh], so only the latest one arms the timer.
  int _generation = 0;

  bool get active => _active;

  /// Ids of the test adhans, one per prayer; above the planner's range.
  static int testIdFor(PrayerKind prayer) =>
      AdhanPlanner.maxId + adhanPrayers.indexOf(prayer);

  /// The app came to the foreground ([on]) or left it.
  void setActive(bool on) {
    if (on == _active) return;
    _active = on;
    // Leaving the app drops a pending test: it only plays while open.
    if (!on) _tests.clear();
    refresh();
  }

  /// Re-reads the schedule (settings, times or the clock changed).
  Future<void> refresh() async {
    _next?.cancel();
    _next = null;
    final generation = ++_generation;
    if (!_active) return;
    await _lastPlayed;
    if (!_active || generation != _generation) return;
    final now = _now();
    final slots = [
      ..._adhans(now.subtract(grace)).where((s) => s.id > _last),
      ..._tests,
    ]..sort((a, b) => a.at.compareTo(b.at));
    final due = slots.where((s) => !s.at.isAfter(now)).toList();
    if (due.isNotEmpty) {
      // Two due at once (a test on top of a prayer): the latest wins.
      await _play(due.last, due);
      return refresh();
    }
    if (slots.isEmpty) return;
    _next = _timer(slots.first.at.difference(now), refresh);
  }

  /// "Test the adhan": [prayer]'s adhan in [testDelay], if the app is still
  /// open then.
  void test(PrayerKind prayer) {
    _tests
      ..removeWhere((s) => s.prayer == prayer)
      ..add(AdhanSlot(
          id: testIdFor(prayer), at: _now().add(testDelay), prayer: prayer));
    refresh();
  }

  Future<void> _play(AdhanSlot slot, List<AdhanSlot> due) async {
    for (final s in due) {
      _tests.remove(s);
      if (AdhanPlanner.isAdhanId(s.id) && s.id > _last) _last = s.id;
    }
    await _saveLastPlayed(_last);
    debugPrint('Adhan: playing $slot in the app');
    _onAdhan(slot);
  }

  void dispose() {
    _next?.cancel();
    _next = null;
    _active = false;
  }
}

final adhanForegroundProvider = Provider<AdhanForeground>((ref) {
  final repository = ref.watch(adhanSettingsRepositoryProvider);
  final foreground = AdhanForeground(
    adhans: (from) => ref.read(adhanProvider.notifier).adhansFrom(from),
    now: ref.watch(adhanClockProvider),
    loadLastPlayed: repository.loadLastPlayed,
    saveLastPlayed: repository.saveLastPlayed,
    onAdhan: (slot) {
      final router = ref.read(routerProvider);
      // Already on the player (opened from the notification): it plays.
      final path = router.routerDelegate.currentConfiguration.uri.path;
      if (path == AdhanScheduler.playRoute) return;
      router.push(AdhanScheduler.playRouteFor(slot.prayer));
    },
  );
  ref.listen(adhanProvider.select((s) => (s.loaded, s.settings)),
      (_, __) => foreground.refresh());
  ref.listen(upcomingPrayerDaysProvider, (_, __) => foreground.refresh());
  ref.onDispose(foreground.dispose);
  return foreground;
});
