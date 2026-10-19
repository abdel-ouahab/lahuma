import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/constants/storage_keys.dart';
import '../domain/bookmark.dart';

/// Local-only bookmarks for the MVP (Hive box of JSON strings, keyed by
/// "surahId-ayahNumber"). Cloud sync is a Phase 3 feature.
class BookmarksRepository {
  Box<String> get _box => Hive.box<String>(StorageKeys.bookmarksBox);

  List<Bookmark> getAll() {
    return _box.values
        .map((raw) => Bookmark.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  bool isBookmarked(int surahId, int ayahNumber) {
    return _box.containsKey('$surahId-$ayahNumber');
  }

  Future<void> add(Bookmark bookmark) async {
    await _box.put(bookmark.id, jsonEncode(bookmark.toJson()));
  }

  Future<void> remove(int surahId, int ayahNumber) async {
    await _box.delete('$surahId-$ayahNumber');
  }
}
