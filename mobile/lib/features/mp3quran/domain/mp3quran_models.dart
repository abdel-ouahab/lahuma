import 'package:equatable/equatable.dart';

/// A recitation edition (riwaya / style) of one reciter, from MP3Quran.
///
/// Moshaf ids are only unique per API response, never interchangeable with
/// reciter ids, so always look a Moshaf up inside its [Mp3Reciter].
class Mp3Moshaf extends Equatable {
  const Mp3Moshaf({
    required this.id,
    required this.name,
    required this.server,
    required this.surahNumbers,
  });

  final int id;
  final String name;

  /// Base audio URL, always normalised to end with `/`.
  final String server;

  /// Surah numbers (1–114) this edition actually has, ascending.
  final List<int> surahNumbers;

  factory Mp3Moshaf.fromJson(Map<String, dynamic> json) {
    var server = (json['server'] as String? ?? '').trim();
    if (server.isNotEmpty && !server.endsWith('/')) server = '$server/';
    return Mp3Moshaf(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String? ?? '').trim(),
      server: server,
      surahNumbers: parseSurahList(json['surah_list']),
    );
  }

  /// Parses `"1,2,3"` into a sorted, de-duplicated list of valid surah numbers.
  static List<int> parseSurahList(Object? raw) {
    if (raw is! String) return const [];
    final set = <int>{};
    for (final part in raw.split(',')) {
      final n = int.tryParse(part.trim());
      if (n != null && n >= 1 && n <= 114) set.add(n);
    }
    return (set.toList()..sort());
  }

  /// [name] split into the riwaya and the recitation style: "حفص عن عاصم -
  /// مرتل" → ("حفص عن عاصم", "مرتل"). The style is null when the API
  /// repeats the first part ("المصحف المجود - المصحف المجود") or has none.
  ({String riwaya, String? style}) get label {
    final parts = name
        .split(' - ')
        .map((p) => p.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return (riwaya: name, style: null);
    final style = parts.skip(1).join(' - ');
    return (
      riwaya: parts.first,
      style: style.isEmpty || style == parts.first ? null : style,
    );
  }

  /// Has all 114 surahs.
  bool get isComplete => surahNumbers.length == 114;

  bool hasSurah(int surah) => surahNumbers.contains(surah);

  /// Playback URL for [surah], or null when this edition has no such surah
  /// (or no server). Never builds a URL for an unvalidated surah.
  String? audioUrlFor(int surah) {
    if (server.isEmpty || !hasSurah(surah)) return null;
    return '$server${surah.toString().padLeft(3, '0')}.mp3';
  }

  @override
  List<Object?> get props => [id, name, server, surahNumbers];
}

class Mp3Reciter extends Equatable {
  const Mp3Reciter({
    required this.id,
    required this.name,
    required this.moshaf,
  });

  final int id;
  final String name;
  final List<Mp3Moshaf> moshaf;

  factory Mp3Reciter.fromJson(Map<String, dynamic> json) {
    final list = (json['moshaf'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Mp3Moshaf.fromJson)
        .toList();
    return Mp3Reciter(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String? ?? '').trim(),
      moshaf: list,
    );
  }

  Mp3Moshaf? moshafById(int id) {
    for (final m in moshaf) {
      if (m.id == id) return m;
    }
    return null;
  }

  @override
  List<Object?> get props => [id, name, moshaf];
}

class Mp3Surah extends Equatable {
  const Mp3Surah({required this.id, required this.name});

  final int id;
  final String name;

  factory Mp3Surah.fromJson(Map<String, dynamic> json) => Mp3Surah(
        id: (json['id'] as num).toInt(),
        name: (json['name'] as String? ?? '').trim(),
      );

  @override
  List<Object?> get props => [id, name];
}
