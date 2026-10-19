import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/bookmarks_repository.dart';
import '../domain/bookmark.dart';

final bookmarksRepositoryProvider = Provider((ref) => BookmarksRepository());

class BookmarksNotifier extends StateNotifier<List<Bookmark>> {
  BookmarksNotifier(this._repository) : super(_repository.getAll());

  final BookmarksRepository _repository;

  Future<void> add(Bookmark bookmark) async {
    await _repository.add(bookmark);
    state = _repository.getAll();
  }

  Future<void> remove(int surahId, int ayahNumber) async {
    await _repository.remove(surahId, ayahNumber);
    state = _repository.getAll();
  }

  bool isBookmarked(int surahId, int ayahNumber) =>
      _repository.isBookmarked(surahId, ayahNumber);
}

final bookmarksProvider = StateNotifierProvider<BookmarksNotifier, List<Bookmark>>((ref) {
  return BookmarksNotifier(ref.watch(bookmarksRepositoryProvider));
});
