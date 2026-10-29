import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mushaf_repository.dart';

final mushafRepositoryProvider = Provider((ref) => MushafRepository());

class MushafState {
  const MushafState({
    this.loaded = false,
    this.lastPage = 1,
    this.bookmarks = const [],
    this.theme = MushafTheme.auto,
  });

  final bool loaded;
  final int lastPage;

  /// Newest first.
  final List<MushafBookmark> bookmarks;

  final MushafTheme theme;

  bool isBookmarked(int page) => bookmarks.any((b) => b.page == page);

  MushafState copyWith({
    bool? loaded,
    int? lastPage,
    List<MushafBookmark>? bookmarks,
    MushafTheme? theme,
  }) =>
      MushafState(
        loaded: loaded ?? this.loaded,
        lastPage: lastPage ?? this.lastPage,
        bookmarks: bookmarks ?? this.bookmarks,
        theme: theme ?? this.theme,
      );
}

class MushafNotifier extends StateNotifier<MushafState> {
  MushafNotifier(this._repository) : super(const MushafState()) {
    _load();
  }

  final MushafRepository _repository;

  Future<void> _load() async {
    final lastPage = await _repository.getLastPage();
    final bookmarks = await _repository.getBookmarks()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final theme = await _repository.getTheme();
    if (!mounted) return;
    state = state.copyWith(
        loaded: true, lastPage: lastPage, bookmarks: bookmarks, theme: theme);
  }

  Future<void> setTheme(MushafTheme theme) async {
    state = state.copyWith(theme: theme);
    await _repository.setTheme(theme);
  }

  Future<void> setLastPage(int page) async {
    if (page == state.lastPage) return;
    state = state.copyWith(lastPage: page);
    await _repository.setLastPage(page);
  }

  /// Returns true when the page is bookmarked afterwards.
  Future<bool> toggleBookmark(int page) async {
    final added = !state.isBookmarked(page);
    final bookmarks = added
        ? [
            MushafBookmark(page: page, createdAt: DateTime.now()),
            ...state.bookmarks
          ]
        : [
            for (final b in state.bookmarks)
              if (b.page != page) b
          ];
    state = state.copyWith(bookmarks: bookmarks);
    await _repository.setBookmarks(bookmarks);
    return added;
  }

  Future<void> removeBookmark(int page) async {
    if (state.isBookmarked(page)) await toggleBookmark(page);
  }
}

final mushafProvider = StateNotifierProvider<MushafNotifier, MushafState>(
    (ref) => MushafNotifier(ref.watch(mushafRepositoryProvider)));
