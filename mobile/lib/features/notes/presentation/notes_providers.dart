import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notes_repository.dart';

final notesRepositoryProvider = Provider((ref) => NotesRepository());

class NotesNotifier extends StateNotifier<Map<String, String>> {
  NotesNotifier(this._repository) : super(const {}) {
    _load();
  }

  final NotesRepository _repository;

  Future<void> _load() async {
    state = await _repository.loadAll();
  }

  String? noteFor(int surah, int ayah) =>
      state[NotesRepository.key(surah, ayah)];

  /// Saves [text] for the ayah; an empty string removes the note.
  Future<void> setNote(int surah, int ayah, String text) async {
    final next = Map<String, String>.from(state);
    final key = NotesRepository.key(surah, ayah);
    if (text.trim().isEmpty) {
      next.remove(key);
    } else {
      next[key] = text.trim();
    }
    state = next;
    await _repository.saveAll(next);
  }
}

final notesProvider =
    StateNotifierProvider<NotesNotifier, Map<String, String>>((ref) {
  return NotesNotifier(ref.watch(notesRepositoryProvider));
});
