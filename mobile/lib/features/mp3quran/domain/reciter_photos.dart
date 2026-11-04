import '../../../core/utils/arabic_text.dart';

/// Reciter portraits, looked up by Arabic name.
///
/// MP3Quran has no photos, so they come from Quran.com, which only has a
/// handful. The two catalogues spell names differently ("عبد الباسط عبد
/// الصمد" / "عبدالباسط عبدالصمد", "مشاري راشد العفاسي" / "مشاري العفاسي",
/// a leading "شيخ"), so names are compared as [nameKey]s: first the whole
/// name, then first and last name only when that pair is unambiguous.
class ReciterPhotos {
  ReciterPhotos(Map<String, String> urlByName) {
    final firstLast = <String, String?>{};
    for (final entry in urlByName.entries) {
      final tokens = nameTokens(entry.key);
      if (tokens.isEmpty) continue;
      _byName[tokens.join()] = entry.value;
      if (tokens.length < 2) continue;
      final key = '${tokens.first}|${tokens.last}';
      // Two different photos for the same pair: trust neither.
      firstLast[key] =
          firstLast.containsKey(key) && firstLast[key] != entry.value
              ? null
              : entry.value;
    }
    firstLast.forEach((key, url) {
      if (url != null) _byFirstLast[key] = url;
    });
  }

  static final empty = ReciterPhotos(const {});

  final _byName = <String, String>{};
  final _byFirstLast = <String, String>{};

  bool get isEmpty => _byName.isEmpty;

  String? urlFor(String name) {
    final tokens = nameTokens(name);
    if (tokens.isEmpty) return null;
    return _byName[tokens.join()] ??
        (tokens.length < 2
            ? null
            : _byFirstLast['${tokens.first}|${tokens.last}']);
  }

  /// Normalised name parts, without honorifics, with "عبد" / "أبو" joined
  /// to the word they belong to.
  static List<String> nameTokens(String name) {
    final words = normalizeArabic(name)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !_honorifics.contains(w))
        .toList();
    final out = <String>[];
    for (var i = 0; i < words.length; i++) {
      if (_prefixes.contains(words[i]) && i + 1 < words.length) {
        out.add('${words[i]}${words[++i]}');
      } else {
        out.add(words[i]);
      }
    }
    return out;
  }

  static const _honorifics = {'شيخ', 'الشيخ', 'القارئ'};
  static const _prefixes = {'عبد', 'ابو'};
}
