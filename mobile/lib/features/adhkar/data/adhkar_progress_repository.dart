import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';
import '../../wird/data/wird_repository.dart';
import '../domain/dhikr.dart';

/// Today's repetition counts, keyed by `Dhikr.id`. Adhkar are said every
/// morning and evening, so the counts start from zero each day.
class AdhkarProgress {
  const AdhkarProgress({required this.date, this.counts = const {}});

  /// `yyyy-MM-dd` of the day [counts] belong to.
  final String date;
  final Map<String, int> counts;

  int countOf(String id) => counts[id] ?? 0;

  AdhkarProgress withCount(String id, int count) {
    final next = Map<String, int>.from(counts);
    if (count <= 0) {
      next.remove(id);
    } else {
      next[id] = count;
    }
    return AdhkarProgress(date: date, counts: next);
  }
}

/// How many adhkar of each period the user has finished, all time. A dhikr
/// counts at most once a day, so resetting and saying it again the same day
/// never inflates the total.
class AdhkarCompletions {
  const AdhkarCompletions({
    this.counts = const {},
    this.date = '',
    this.countedToday = const {},
  });

  final Map<AdhkarPeriod, int> counts;

  /// `yyyy-MM-dd` that [countedToday] belongs to.
  final String date;

  /// Ids of the adhkar already counted on [date].
  final Set<String> countedToday;

  int countOf(AdhkarPeriod period) => counts[period] ?? 0;

  /// Counts [dhikr] for [day]; returns this unchanged if already counted or
  /// if it is not a morning / evening dhikr.
  AdhkarCompletions record(Dhikr dhikr, String day) {
    final period = dhikr.period;
    if (period == null) return this;
    final counted = date == day ? countedToday : const <String>{};
    if (counted.contains(dhikr.id)) return this;
    return AdhkarCompletions(
      counts: {...counts, period: countOf(period) + 1},
      date: day,
      countedToday: {...counted, dhikr.id},
    );
  }

  Map<String, dynamic> toJson() => {
        'counts': {for (final e in counts.entries) e.key.name: e.value},
        'date': date,
        'today': countedToday.toList(),
      };

  factory AdhkarCompletions.fromJson(Map<String, dynamic> json) {
    final counts = <AdhkarPeriod, int>{};
    final raw = json['counts'];
    if (raw is Map) {
      for (final p in AdhkarPeriod.values) {
        final n = raw[p.name];
        if (n is int && n > 0) counts[p] = n;
      }
    }
    final date = json['date'];
    final today = json['today'];
    return AdhkarCompletions(
      counts: counts,
      date: date is String ? date : '',
      countedToday:
          today is List ? today.whereType<String>().toSet() : const {},
    );
  }
}

/// On-device counters, favourite adhkar and text size (SharedPreferences).
class AdhkarProgressRepository {
  static const double defaultFontSize = 24;
  static const double minFontSize = 18;
  static const double maxFontSize = 36;

  AdhkarProgressRepository({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  String get today => WirdRepository.dateKey(_now());

  Future<AdhkarProgress> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.adhkarProgress);
    if (raw == null) return AdhkarProgress(date: today);
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['date'] != today) return AdhkarProgress(date: today);
      return AdhkarProgress(
        date: today,
        counts: (json['counts'] as Map<String, dynamic>).cast<String, int>(),
      );
    } catch (_) {
      return AdhkarProgress(date: today);
    }
  }

  Future<void> saveProgress(AdhkarProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.adhkarProgress,
      jsonEncode({'date': progress.date, 'counts': progress.counts}),
    );
  }

  Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(StorageKeys.adhkarFavorites) ?? const [])
        .toSet();
  }

  Future<void> saveFavorites(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(StorageKeys.adhkarFavorites, ids.toList());
  }

  Future<AdhkarCompletions> loadCompletions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.adhkarCompletions);
    if (raw == null) return const AdhkarCompletions();
    try {
      return AdhkarCompletions.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AdhkarCompletions();
    }
  }

  Future<void> saveCompletions(AdhkarCompletions completions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        StorageKeys.adhkarCompletions, jsonEncode(completions.toJson()));
  }

  Future<double> loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    final size = prefs.getDouble(StorageKeys.adhkarFontSize);
    return size == null
        ? defaultFontSize
        : size.clamp(minFontSize, maxFontSize).toDouble();
  }

  Future<void> saveFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(StorageKeys.adhkarFontSize, size);
  }
}
