import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../quran/mushaf/domain/mushaf_meta.dart';
import '../domain/dhikr.dart';

/// Why the adhkar could not be read. The data ships with the app, so this
/// only happens with a broken build.
enum AdhkarFailure { malformed, empty }

class AdhkarException implements Exception {
  const AdhkarException(this.failure, [this.detail]);

  final AdhkarFailure failure;

  /// Developer-facing detail; never shown to the user.
  final String? detail;

  @override
  String toString() => 'AdhkarException(${failure.name}: $detail)';
}

/// Reads the adhkar bundled in `assets/data/adhkar.json`, so they work
/// offline from the first launch.
///
/// The file is generated from Hisn al-Muslim by `tools/generate_adhkar`
/// (texts from hisnmuslim.com, the book's footnotes for references); edit
/// that script, not the JSON, to change the content. Quranic duas are stored
/// as verse ranges and their text is read from the Mushaf data.
class AdhkarService {
  AdhkarService({
    Future<String> Function()? load,
    String Function(int surah, int ayah)? verse,
  })  : _load = load ?? (() => rootBundle.loadString(asset)),
        _verse = verse ?? MushafMeta.ayahText;

  static const String asset = 'assets/data/adhkar.json';

  final Future<String> Function() _load;
  final String Function(int surah, int ayah) _verse;

  Future<AdhkarCollection> load() async => parse(await _load(), verse: _verse);

  /// Parses the dataset: `{categories: [{id, group, title, titleEn, icon,
  /// tone, items: [{text | quran: {surah, from, to}, count, fadl?,
  /// reference?, occasion?}]}]}`. Items without text are skipped.
  static AdhkarCollection parse(
    String raw, {
    required String Function(int surah, int ayah) verse,
  }) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException catch (e) {
      throw AdhkarException(AdhkarFailure.malformed, e.message);
    }
    final list = json is Map ? json['categories'] : null;
    if (list is! List) {
      throw const AdhkarException(
          AdhkarFailure.malformed, '"categories" is not a list');
    }

    final categories = <AdhkarCategory>[];
    for (final c in list) {
      if (c is! Map || c['id'] is! String) continue;
      final id = c['id'] as String;
      final rawItems = c['items'] is List ? c['items'] as List : const [];
      final items = <Dhikr>[];
      for (final item in rawItems) {
        if (item is! Map) continue;
        final dhikr = _item(id, items.length, item, verse);
        if (dhikr != null) items.add(dhikr);
      }
      categories.add(AdhkarCategory(
        id: id,
        group: AdhkarGroup.parse(c['group'] as String?),
        title: _string(c['title']) ?? id,
        titleEn: _string(c['titleEn']) ?? id,
        icon: _string(c['icon']) ?? '',
        tone: _string(c['tone']) ?? '',
        items: items,
      ));
    }

    final collection = AdhkarCollection(categories);
    if (collection.isEmpty) throw const AdhkarException(AdhkarFailure.empty);
    return collection;
  }

  static Dhikr? _item(String categoryId, int index, Map item,
      String Function(int surah, int ayah) verse) {
    final quran = item['quran'];
    final String text;
    if (quran is Map) {
      final surah = quran['surah'], from = quran['from'], to = quran['to'];
      if (surah is! int || from is! int || to is! int || to < from) {
        return null;
      }
      text = [
        for (var a = from; a <= to; a++)
          '${verse(surah, a).trim()} ﴿${arabicDigits(a)}﴾',
      ].join(' ');
    } else {
      text = _string(item['text']) ?? '';
    }
    if (text.isEmpty) return null;

    final count = item['count'];
    return Dhikr(
      categoryId: categoryId,
      index: index,
      text: text,
      count: count is int && count > 0 ? count : 1,
      virtue: _string(item['fadl']),
      reference: _string(item['reference']),
      occasion: _string(item['occasion']),
      quran: quran is Map,
    );
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    final s = value.trim();
    return s.isEmpty ? null : s;
  }

  /// 19 → ١٩, for ayah numbers.
  static String arabicDigits(int n) => '$n'
      .split('')
      .map((d) => String.fromCharCode(0x0660 + int.parse(d)))
      .join();
}
