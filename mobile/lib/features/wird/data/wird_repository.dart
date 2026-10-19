import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';

/// The reader's daily wird: how many ayahs they read today against a goal,
/// and how many days in a row they have met it.
class WirdState {
  const WirdState({
    required this.date,
    required this.ayahsToday,
    required this.goal,
    required this.streak,
  });

  /// `yyyy-MM-dd` of the day [ayahsToday] belongs to.
  final String date;
  final int ayahsToday;
  final int goal;
  final int streak;

  double get fraction => goal <= 0 ? 0 : (ayahsToday / goal).clamp(0.0, 1.0);
  bool get goalReached => ayahsToday >= goal;

  WirdState copyWith({int? ayahsToday, int? goal, int? streak}) => WirdState(
        date: date,
        ayahsToday: ayahsToday ?? this.ayahsToday,
        goal: goal ?? this.goal,
        streak: streak ?? this.streak,
      );
}

class WirdRepository {
  WirdRepository({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const int defaultGoal = 20;
  static const List<int> goalOptions = [5, 10, 20, 50, 100];

  final DateTime Function() _now;

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
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

    final sameDay = prefs.getString(StorageKeys.dailyDate) == _today;
    return WirdState(
      date: _today,
      ayahsToday: sameDay ? (prefs.getInt(StorageKeys.dailyCount) ?? 0) : 0,
      goal: goal,
      streak: streak,
    );
  }

  Future<void> save(WirdState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.dailyDate, state.date);
    await prefs.setInt(StorageKeys.dailyCount, state.ayahsToday);
    await prefs.setInt(StorageKeys.dailyGoal, state.goal);
    await prefs.setInt(StorageKeys.dailyStreak, state.streak);
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
}
