import 'package:equatable/equatable.dart';

/// The two daily adhkar collections the app shows.
enum AdhkarPeriod {
  morning,
  evening;

  /// Category key of this period in the source dataset.
  String get sourceKey => switch (this) {
        AdhkarPeriod.morning => 'أذكار الصباح',
        AdhkarPeriod.evening => 'أذكار المساء',
      };

  static AdhkarPeriod? tryParse(String? name) {
    for (final p in values) {
      if (p.name == name) return p;
    }
    return null;
  }
}

/// One dhikr as published by the source. Nothing here is written by the app:
/// [text], [virtue] and [reference] are the dataset's own fields, only
/// trimmed of stray whitespace.
class Dhikr extends Equatable {
  const Dhikr({
    required this.period,
    required this.index,
    required this.text,
    required this.count,
    this.virtue,
    this.reference,
  });

  final AdhkarPeriod period;

  /// Position in the source list (0-based). Stable because the source URL is
  /// pinned to one commit.
  final int index;

  final String text;

  /// How many times it is said; at least 1.
  final int count;

  /// The source's `description` (its virtue / fadl), when it has one.
  final String? virtue;

  /// The source's `reference`, when it has one.
  final String? reference;

  /// Key for counters and favourites, e.g. `morning-3`.
  String get id => '${period.name}-$index';

  @override
  List<Object?> get props => [period, index, text, count, virtue, reference];
}

/// Morning and evening adhkar, in source order.
class AdhkarCollection {
  const AdhkarCollection(this._byPeriod);

  final Map<AdhkarPeriod, List<Dhikr>> _byPeriod;

  List<Dhikr> of(AdhkarPeriod period) => _byPeriod[period] ?? const [];

  Dhikr? byId(String id) {
    for (final list in _byPeriod.values) {
      for (final d in list) {
        if (d.id == id) return d;
      }
    }
    return null;
  }

  bool get isEmpty => _byPeriod.values.every((l) => l.isEmpty);
}
