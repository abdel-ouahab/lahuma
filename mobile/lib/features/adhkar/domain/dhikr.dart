import 'package:equatable/equatable.dart';

/// The two daily collections Home follows. Each is the category of the same
/// [name] in the dataset.
enum AdhkarPeriod {
  morning,
  evening;

  String get categoryId => name;

  static AdhkarPeriod? tryParse(String? name) {
    for (final p in values) {
      if (p.name == name) return p;
    }
    return null;
  }
}

/// How the categories are grouped on the Adhkar screen, in this order.
enum AdhkarGroup {
  day,
  places,
  travel,
  duas;

  static AdhkarGroup parse(String? name) =>
      values.where((g) => g.name == name).firstOrNull ?? AdhkarGroup.duas;
}

/// One dhikr or dua as published in the dataset (`assets/data/adhkar.json`,
/// built from Hisn al-Muslim by `tools/generate_adhkar`). The app never
/// writes any of [text], [virtue] or [reference] itself.
class Dhikr extends Equatable {
  const Dhikr({
    required this.categoryId,
    required this.index,
    required this.text,
    required this.count,
    this.virtue,
    this.reference,
    this.occasion,
    this.quran = false,
  });

  final String categoryId;

  /// Position in its category (0-based).
  final int index;

  final String text;

  /// How many times it is said; at least 1.
  final int count;

  /// The book's statement of its virtue (fadl), when it gives one.
  final String? virtue;

  /// Where it is narrated, as the book cites it.
  final String? reference;

  /// The Hisn al-Muslim chapter it comes from, for categories that gather
  /// several (e.g. "دعاء دخول القرية أو البلدة" under travel).
  final String? occasion;

  /// Verses of the Quran, read from the app's Mushaf text.
  final bool quran;

  /// Key for counters and favourites, e.g. `morning-3`.
  String get id => '$categoryId-$index';

  /// The daily collection it belongs to, if any.
  AdhkarPeriod? get period => AdhkarPeriod.tryParse(categoryId);

  @override
  List<Object?> get props =>
      [categoryId, index, text, count, virtue, reference, occasion, quran];
}

class AdhkarCategory extends Equatable {
  const AdhkarCategory({
    required this.id,
    required this.group,
    required this.title,
    required this.titleEn,
    required this.icon,
    required this.tone,
    required this.items,
  });

  final String id;
  final AdhkarGroup group;
  final String title;
  final String titleEn;

  /// Glyph name from the dataset, mapped to an icon by the UI.
  final String icon;

  /// Tile colour name from the dataset (`yellow`, `indigo`, …).
  final String tone;
  final List<Dhikr> items;

  @override
  List<Object?> get props => [id, group, title, titleEn, icon, tone, items];
}

/// Every category, in dataset order.
class AdhkarCollection {
  const AdhkarCollection(this.categories);

  final List<AdhkarCategory> categories;

  AdhkarCategory? category(String id) =>
      categories.where((c) => c.id == id).firstOrNull;

  List<Dhikr> of(AdhkarPeriod period) =>
      category(period.categoryId)?.items ?? const [];

  Dhikr? byId(String id) {
    for (final c in categories) {
      for (final d in c.items) {
        if (d.id == id) return d;
      }
    }
    return null;
  }

  bool get isEmpty => categories.every((c) => c.items.isEmpty);
}
