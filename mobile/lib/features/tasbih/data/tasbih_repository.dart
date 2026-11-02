import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';
import '../../wird/data/wird_repository.dart';
import '../domain/tasbih.dart';

/// On-device tasbih: the chosen dhikr, running counts, custom adhkar, preset
/// target changes, settings and stats (SharedPreferences).
class TasbihRepository {
  TasbihRepository({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  String get today => WirdRepository.dateKey(_now());

  DateTime get now => _now();

  Future<TasbihState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _decode(prefs.getString(StorageKeys.tasbihState));

    final targets = json['targets'];
    final adhkar = [
      for (final p in tasbihPresets)
        targets is Map && targets[p.id] is int
            ? p.withTarget(_target(targets[p.id] as int))
            : p,
      if (json['custom'] case final List custom)
        ...custom.map(TasbihDhikr.fromJson).nonNulls,
    ];

    final counts = <String, int>{};
    if (json['counts'] case final Map raw) {
      for (final MapEntry(:key, :value) in raw.entries) {
        if (key is String && value is int && value > 0) counts[key] = value;
      }
    }

    final current = json['current'];
    return TasbihState(
      adhkar: adhkar,
      currentId: adhkar.any((d) => d.id == current)
          ? current as String
          : adhkar.first.id,
      counts: counts,
      settings: TasbihSettings.fromJson(
          _decode(prefs.getString(StorageKeys.tasbihSettings))),
      stats:
          TasbihStats.fromJson(_decode(prefs.getString(StorageKeys.tasbihStats))),
      loaded: true,
    );
  }

  /// Saves the dhikr list, choice and counts, and the stats.
  Future<void> save(TasbihState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.tasbihState,
      jsonEncode({
        'current': state.currentId,
        'counts': state.counts,
        'targets': {
          for (final d in state.adhkar)
            if (!d.custom && d.target != d.defaultTarget) d.id: d.target ?? 0,
        },
        'custom': [
          for (final d in state.adhkar)
            if (d.custom) d.toJson(),
        ],
      }),
    );
    await prefs.setString(
        StorageKeys.tasbihStats, jsonEncode(state.stats.toJson()));
  }

  Future<void> saveSettings(TasbihSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        StorageKeys.tasbihSettings, jsonEncode(settings.toJson()));
  }

  static int? _target(int stored) => stored > 0 ? stored : null;

  static Map<String, dynamic> _decode(String? raw) {
    if (raw == null) return const {};
    try {
      final json = jsonDecode(raw);
      return json is Map<String, dynamic> ? json : const {};
    } catch (_) {
      return const {};
    }
  }
}
