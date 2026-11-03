import 'dart:math' as math;

/// Beads on the string, as on a 33-bead misbaha.
const int tasbihBeads = 33;

/// How many beads sit on the counted side after [count] taps.
///
/// The first 33 taps move beads one way; the next 33 move them back, as a
/// misbaha is turned over at the imam bead. Every tap therefore moves exactly
/// one bead, and the beads never jump.
int beadsCounted(int count) {
  if (count <= 0) return 0;
  final within = count % tasbihBeads;
  return (count ~/ tasbihBeads).isEven ? within : tasbihBeads - within;
}

/// What the beads are made of.
enum BeadMaterial {
  amber,
  wood,
  pearl;

  static BeadMaterial parse(Object? name) =>
      values.where((m) => m.name == name).firstOrNull ?? amber;
}

/// One dhikr to count: a preset or one the user added.
class TasbihDhikr {
  const TasbihDhikr({
    required this.id,
    required this.text,
    this.target,
    this.custom = false,
  });

  final String id;

  /// Arabic text, shown as written.
  final String text;

  /// Count to reach; null counts without a limit.
  final int? target;
  final bool custom;

  /// The preset's own target, or null for a custom dhikr.
  int? get defaultTarget => custom
      ? null
      : tasbihPresets.where((p) => p.id == id).firstOrNull?.target;

  TasbihDhikr withTarget(int? target) =>
      TasbihDhikr(id: id, text: text, target: target, custom: custom);

  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'target': target ?? 0};

  /// Custom adhkar only; presets are rebuilt from [tasbihPresets].
  static TasbihDhikr? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final text = json['text'];
    final target = json['target'];
    if (id is! String || text is! String || text.trim().isEmpty) return null;
    return TasbihDhikr(
      id: id,
      text: text,
      target: target is int && target > 0 ? target : null,
      custom: true,
    );
  }
}

const List<TasbihDhikr> tasbihPresets = [
  TasbihDhikr(id: 'subhan', text: 'سبحان الله', target: 33),
  TasbihDhikr(id: 'hamd', text: 'الحمد لله', target: 33),
  TasbihDhikr(id: 'takbir', text: 'الله أكبر', target: 34),
  TasbihDhikr(id: 'tahlil', text: 'لا إله إلا الله', target: 100),
  TasbihDhikr(id: 'istighfar', text: 'أستغفر الله', target: 100),
  TasbihDhikr(id: 'hawqala', text: 'لا حول ولا قوة إلا بالله', target: 100),
  TasbihDhikr(id: 'salah', text: 'اللهم صلِّ وسلم على نبينا محمد', target: 100),
];

/// Targets offered when changing a dhikr's count.
const List<int> tasbihTargetOptions = [33, 34, 99, 100, 1000];

class TasbihSettings {
  const TasbihSettings({
    this.sound = false,
    this.haptics = true,
    this.material = BeadMaterial.amber,
  });

  /// A click on every count.
  final bool sound;
  final bool haptics;
  final BeadMaterial material;

  TasbihSettings copyWith(
          {bool? sound, bool? haptics, BeadMaterial? material}) =>
      TasbihSettings(
        sound: sound ?? this.sound,
        haptics: haptics ?? this.haptics,
        material: material ?? this.material,
      );

  Map<String, dynamic> toJson() =>
      {'sound': sound, 'haptics': haptics, 'material': material.name};

  factory TasbihSettings.fromJson(Map<String, dynamic> json) => TasbihSettings(
        sound: json['sound'] == true,
        haptics: json['haptics'] != false,
        material: BeadMaterial.parse(json['material']),
      );
}

/// Today's count across all adhkar, and each dhikr's all-time count.
class TasbihStats {
  const TasbihStats({this.date = '', this.today = 0, this.totals = const {}});

  /// `yyyy-MM-dd` that [today] belongs to.
  final String date;
  final int today;

  /// All-time count per dhikr id.
  final Map<String, int> totals;

  int todayOn(String day) => date == day ? today : 0;
  int totalOf(String id) => totals[id] ?? 0;
  int get allTime => totals.values.fold(0, (a, b) => a + b);

  /// Adds [delta] (±1) to [id] on [day], starting today afresh on a new day.
  /// Never goes below zero.
  TasbihStats add(String id, int delta, String day) {
    final total = math.max(0, totalOf(id) + delta);
    final next = Map<String, int>.from(totals);
    if (total == 0) {
      next.remove(id);
    } else {
      next[id] = total;
    }
    return TasbihStats(
      date: day,
      today: math.max(0, todayOn(day) + delta),
      totals: next,
    );
  }

  TasbihStats without(String id) =>
      TasbihStats(date: date, today: today, totals: {...totals}..remove(id));

  Map<String, dynamic> toJson() =>
      {'date': date, 'today': today, 'totals': totals};

  factory TasbihStats.fromJson(Map<String, dynamic> json) {
    final totals = <String, int>{};
    final raw = json['totals'];
    if (raw is Map) {
      for (final MapEntry(:key, :value) in raw.entries) {
        if (key is String && value is int && value > 0) totals[key] = value;
      }
    }
    final date = json['date'];
    final today = json['today'];
    return TasbihStats(
      date: date is String ? date : '',
      today: today is int && today > 0 ? today : 0,
      totals: totals,
    );
  }
}

/// Everything the tasbih screen shows.
class TasbihState {
  const TasbihState({
    this.adhkar = tasbihPresets,
    this.currentId = 'subhan',
    this.counts = const {},
    this.settings = const TasbihSettings(),
    this.stats = const TasbihStats(),
    this.loaded = false,
  });

  /// Presets (with the user's targets) followed by custom adhkar.
  final List<TasbihDhikr> adhkar;
  final String currentId;

  /// Running count per dhikr id, kept until reset.
  final Map<String, int> counts;
  final TasbihSettings settings;
  final TasbihStats stats;

  /// False until the saved state has been read; taps wait for it.
  final bool loaded;

  TasbihDhikr get current =>
      adhkar.where((d) => d.id == currentId).firstOrNull ?? adhkar.first;

  int countOf(String id) => counts[id] ?? 0;
  int get count => countOf(current.id);

  bool reached(TasbihDhikr d) => d.target != null && countOf(d.id) >= d.target!;

  TasbihState copyWith({
    List<TasbihDhikr>? adhkar,
    String? currentId,
    Map<String, int>? counts,
    TasbihSettings? settings,
    TasbihStats? stats,
    bool? loaded,
  }) =>
      TasbihState(
        adhkar: adhkar ?? this.adhkar,
        currentId: currentId ?? this.currentId,
        counts: counts ?? this.counts,
        settings: settings ?? this.settings,
        stats: stats ?? this.stats,
        loaded: loaded ?? this.loaded,
      );
}
