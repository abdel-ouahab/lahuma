import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';

/// Who the reader is dedicating their recitation to.
enum DedicationTarget { parents, father, mother, other }

class Dedication {
  const Dedication({
    this.target = DedicationTarget.parents,
    this.names = '',
    this.total = 0,
  });

  final DedicationTarget target;

  /// Optional free text: the names of the people the reward is for.
  final String names;

  /// Ayahs read since the dedication began.
  final int total;

  Dedication copyWith({DedicationTarget? target, String? names, int? total}) =>
      Dedication(
        target: target ?? this.target,
        names: names ?? this.names,
        total: total ?? this.total,
      );
}

class DedicationRepository {
  Future<Dedication> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(StorageKeys.dedicationTarget);
    return Dedication(
      target: DedicationTarget.values.firstWhere(
        (t) => t.name == name,
        orElse: () => DedicationTarget.parents,
      ),
      names: prefs.getString(StorageKeys.dedicationNames) ?? '',
      total: prefs.getInt(StorageKeys.dedicationTotal) ?? 0,
    );
  }

  Future<void> save(Dedication d) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.dedicationTarget, d.target.name);
    await prefs.setString(StorageKeys.dedicationNames, d.names);
    await prefs.setInt(StorageKeys.dedicationTotal, d.total);
  }
}
