import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/storage_keys.dart';

/// The Mushaf's page colours, chosen apart from the app theme. [auto]
/// follows the app: sepia paper in light mode, dark paper in dark mode.
enum MushafTheme { auto, white, sepia, dark }

/// A bookmarked Mushaf page.
class MushafBookmark {
  const MushafBookmark({required this.page, required this.createdAt});

  final int page;
  final DateTime createdAt;

  factory MushafBookmark.fromJson(Map<String, dynamic> json) => MushafBookmark(
        page: json['page'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
      );

  Map<String, dynamic> toJson() =>
      {'page': page, 'at': createdAt.millisecondsSinceEpoch};
}

/// Last-read page and page bookmarks, kept on the device.
class MushafRepository {
  Future<int> getLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(StorageKeys.mushafLastPage) ?? 1;
  }

  Future<void> setLastPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.mushafLastPage, page);
  }

  Future<MushafTheme> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(StorageKeys.mushafTheme);
    return MushafTheme.values
        .firstWhere((t) => t.name == name, orElse: () => MushafTheme.auto);
  }

  Future<void> setTheme(MushafTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.mushafTheme, theme.name);
  }

  Future<List<MushafBookmark>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(StorageKeys.mushafBookmarks) ?? const [];
    return [
      for (final item in raw)
        MushafBookmark.fromJson(jsonDecode(item) as Map<String, dynamic>),
    ];
  }

  Future<void> setBookmarks(List<MushafBookmark> bookmarks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      StorageKeys.mushafBookmarks,
      [for (final b in bookmarks) jsonEncode(b.toJson())],
    );
  }
}
