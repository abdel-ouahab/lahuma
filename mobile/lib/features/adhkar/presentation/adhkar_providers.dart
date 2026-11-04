import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/adhkar_progress_repository.dart';
import '../data/adhkar_service.dart';
import '../domain/dhikr.dart';

final adhkarServiceProvider = Provider((ref) => AdhkarService());

/// Morning + evening adhkar (cache first, then network). Invalidate to retry.
final adhkarProvider = FutureProvider<AdhkarCollection>((ref) async {
  return ref.watch(adhkarServiceProvider).load();
});

final adhkarProgressRepositoryProvider =
    Provider((ref) => AdhkarProgressRepository());

class AdhkarProgressNotifier extends StateNotifier<AdhkarProgress> {
  AdhkarProgressNotifier(this._repository)
      : super(AdhkarProgress(date: _repository.today)) {
    _load();
  }

  final AdhkarProgressRepository _repository;

  Future<void> _load() async {
    state = await _repository.loadProgress();
  }

  /// Today's state, rolled over to a fresh day when the date changed while
  /// the app stayed open.
  AdhkarProgress get _current => state.date == _repository.today
      ? state
      : AdhkarProgress(date: _repository.today);

  /// Counts one repetition of [dhikr]; stops at its required count.
  /// Returns true when this repetition completed it.
  bool increment(Dhikr dhikr) {
    final current = _current;
    final done = current.countOf(dhikr.id);
    if (done >= dhikr.count) return false;
    _set(current.withCount(dhikr.id, done + 1));
    return done + 1 == dhikr.count;
  }

  void reset(Dhikr dhikr) => _set(_current.withCount(dhikr.id, 0));

  void resetAll(Iterable<Dhikr> adhkar) {
    var next = _current;
    for (final d in adhkar) {
      next = next.withCount(d.id, 0);
    }
    _set(next);
  }

  void _set(AdhkarProgress next) {
    state = next;
    _repository.saveProgress(next);
  }
}

final adhkarProgressProvider =
    StateNotifierProvider<AdhkarProgressNotifier, AdhkarProgress>((ref) {
  return AdhkarProgressNotifier(ref.watch(adhkarProgressRepositoryProvider));
});

/// Today's progress through [period]'s adhkar: how many are finished out of
/// how many, or null while the adhkar are still loading.
final adhkarTodayProvider =
    Provider.family<({int done, int total})?, AdhkarPeriod>((ref, period) {
  final adhkar = ref.watch(adhkarProvider).valueOrNull?.of(period);
  if (adhkar == null || adhkar.isEmpty) return null;
  final progress = ref.watch(adhkarProgressProvider);
  final today = ref.watch(adhkarProgressRepositoryProvider).today;
  final done = progress.date != today
      ? 0
      : adhkar.where((d) => progress.countOf(d.id) >= d.count).length;
  return (done: done, total: adhkar.length);
});

class AdhkarFavoritesNotifier extends StateNotifier<Set<String>> {
  AdhkarFavoritesNotifier(this._repository) : super(const {}) {
    _load();
  }

  final AdhkarProgressRepository _repository;

  Future<void> _load() async {
    state = await _repository.loadFavorites();
  }

  /// Adds or removes [dhikr]; returns true when it is now a favourite.
  bool toggle(Dhikr dhikr) {
    final next = Set<String>.from(state);
    final added = next.add(dhikr.id);
    if (!added) next.remove(dhikr.id);
    state = next;
    _repository.saveFavorites(next);
    return added;
  }
}

final adhkarFavoritesProvider =
    StateNotifierProvider<AdhkarFavoritesNotifier, Set<String>>((ref) {
  return AdhkarFavoritesNotifier(ref.watch(adhkarProgressRepositoryProvider));
});

class AdhkarCompletionsNotifier extends StateNotifier<AdhkarCompletions> {
  AdhkarCompletionsNotifier(this._repository)
      : super(const AdhkarCompletions()) {
    _load();
  }

  final AdhkarProgressRepository _repository;

  /// Recorded before loading finished; replayed onto the saved state.
  final List<Dhikr> _pending = [];
  bool _loaded = false;

  Future<void> _load() async {
    var saved = await _repository.loadCompletions();
    if (!mounted) return;
    _loaded = true;
    if (_pending.isNotEmpty) {
      for (final d in _pending) {
        saved = saved.record(d, _repository.today);
      }
      _pending.clear();
      _repository.saveCompletions(saved);
    }
    state = saved;
  }

  /// Counts [dhikr] as finished today.
  void record(Dhikr dhikr) {
    final next = state.record(dhikr, _repository.today);
    if (identical(next, state)) return;
    if (!_loaded) _pending.add(dhikr);
    state = next;
    if (_loaded) _repository.saveCompletions(next);
  }
}

final adhkarCompletionsProvider =
    StateNotifierProvider<AdhkarCompletionsNotifier, AdhkarCompletions>((ref) {
  return AdhkarCompletionsNotifier(ref.watch(adhkarProgressRepositoryProvider));
});
