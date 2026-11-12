import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';

/// The reader's daily wird: how many ayahs they read today against a goal,
/// how many days in a row they have met it, and what they read on the
/// days just before.
class WirdState {
  const WirdState({
    required this.date,
    required this.ayahsToday,
    required this.goal,
    required this.streak,
    this.history = const {},
  });

  /// `yyyy-MM-dd` of the day [ayahsToday] belongs to.
  final String date;
  final int ayahsToday;
  final int goal;
  final int streak;

  /// Ayahs read on earlier days, keyed by `yyyy-MM-dd` (today is
  /// [ayahsToday]). Only the last [WirdRepository.historyDays] are kept.
  final Map<String, int> history;

  double get fraction => goal <= 0 ? 0 : (ayahsToday / goal).clamp(0.0, 1.0);
  bool get goalReached => ayahsToday >= goal;
  int get remaining => (goal - ayahsToday).clamp(0, goal);

  /// Ayahs read on [day]: today's tally for today, the history otherwise.
  int countOn(DateTime day) {
    final key = WirdRepository.dateKey(day);
    return key == date ? ayahsToday : (history[key] ?? 0);
  }

  WirdState copyWith({
    int? ayahsToday,
    int? goal,
    int? streak,
    Map<String, int>? history,
  }) =>
      WirdState(
        date: date,
        ayahsToday: ayahsToday ?? this.ayahsToday,
        goal: goal ?? this.goal,
        streak: streak ?? this.streak,
        history: history ?? this.history,
      );
}

class WirdRepository {
  WirdRepository({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const int defaultGoal = 20;
  static const List<int> goalOptions = [5, 10, 20, 50, 100];

  /// Past days kept for the week strip (a week plus a margin).
  static const int historyDays = 14;

  final DateTime Function() _now;

  static String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String get _today => dateKey(_now());
  String get _yesterday => dateKey(_now().subtract(const Duration(days: 1)));

  Future<WirdState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final goal = prefs.getInt(StorageKeys.dailyGoal) ?? defaultGoal;
    var streak = prefs.getInt(StorageKeys.dailyStreak) ?? 0;
    final lastGoalDate = prefs.getString(StorageKeys.dailyLastGoalDate);

    // A streak is broken once a full day passes without meeting the goal.
    if (lastGoalDate != _today && lastGoalDate != _yesterday) streak = 0;

    final storedDate = prefs.getString(StorageKeys.dailyDate);
    final storedCount = prefs.getInt(StorageKeys.dailyCount) ?? 0;
    final sameDay = storedDate == _today;

    // The last day's tally moves into the history once the date rolls over
    // (this also back-fills installs that predate the history).
    final history = _readHistory(prefs);
    if (!sameDay && storedDate != null && storedCount > 0) {
      history[storedDate] = storedCount;
    }

    return WirdState(
      date: _today,
      ayahsToday: sameDay ? storedCount : 0,
      goal: goal,
      streak: streak,
      history: _prune(history),
    );
  }

  Future<void> save(WirdState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.dailyDate, state.date);
    await prefs.setInt(StorageKeys.dailyCount, state.ayahsToday);
    await prefs.setInt(StorageKeys.dailyGoal, state.goal);
    await prefs.setInt(StorageKeys.dailyStreak, state.streak);
    await prefs.setString(
        StorageKeys.dailyHistory, jsonEncode(_prune({...state.history})));
  }

  /// Adds [count] ayahs to today's tally and updates the streak the first
  /// time the goal is met. Rolls over to a fresh day when the date changed.
  Future<WirdState> addRead(WirdState current, int count) async {
    final prefs = await SharedPreferences.getInstance();
    var state = current.date == _today
        ? current
        : WirdState(
            date: _today,
            ayahsToday: 0,
            goal: current.goal,
            streak: current.streak,
            history: {
              ...current.history,
              if (current.date.isNotEmpty && current.ayahsToday > 0)
                current.date: current.ayahsToday,
            },
          );

    final wasReached = state.goalReached;
    state = state.copyWith(ayahsToday: state.ayahsToday + count);

    if (!wasReached && state.goalReached) {
      final last = prefs.getString(StorageKeys.dailyLastGoalDate);
      final streak = last == _yesterday ? state.streak + 1 : 1;
      state = state.copyWith(streak: streak);
      await prefs.setString(StorageKeys.dailyLastGoalDate, _today);
    }

    await save(state);
    return state;
  }

  Future<WirdState> setGoal(WirdState current, int goal) async {
    final state = current.copyWith(goal: goal);
    await save(state);
    return state;
  }

  static Map<String, int> _readHistory(SharedPreferences prefs) {
    final raw = prefs.getString(StorageKeys.dailyHistory);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in decoded.entries)
          if (e.value is int) e.key: e.value as int,
      };
    } catch (_) {
      return {};
    }
  }

  /// Keeps only the [historyDays] days before today.
  Map<String, int> _prune(Map<String, int> history) {
    final today = _now();
    final keep = {
      for (var i = 1; i <= historyDays; i++)
        dateKey(DateTime(today.year, today.month, today.day - i)),
    };
    return Map.unmodifiable(
        {for (final e in history.entries) if (keep.contains(e.key)) e.key: e.value});
  }
}
