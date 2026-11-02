import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/tasbih_repository.dart';
import '../domain/tasbih.dart';

final tasbihRepositoryProvider = Provider((ref) => TasbihRepository());

/// What a tap did, so the screen can pick its haptic and celebration.
enum TasbihTap {
  /// Still loading; nothing was counted.
  ignored,
  counted,

  /// Counted, and the beads came full circle (every 33).
  round,

  /// Counted, and this reached the dhikr's target.
  reached,
}

class TasbihNotifier extends StateNotifier<TasbihState> {
  TasbihNotifier(this._repository) : super(const TasbihState()) {
    _load();
  }

  final TasbihRepository _repository;

  // Write-behind: at most one save in flight, then one more with whatever
  // changed meanwhile, so fast tapping never queues hundreds of writes.
  TasbihState? _unsaved;
  bool _saving = false;

  Future<void> _load() async {
    final saved = await _repository.load();
    if (mounted) state = saved;
  }

  TasbihTap increment() {
    if (!state.loaded) return TasbihTap.ignored;
    final dhikr = state.current;
    final count = state.count + 1;
    _set(state.copyWith(
      counts: {...state.counts, dhikr.id: count},
      stats: state.stats.add(dhikr.id, 1, _repository.today),
    ));
    if (count == dhikr.target) return TasbihTap.reached;
    if (count % tasbihBeads == 0) return TasbihTap.round;
    return TasbihTap.counted;
  }

  /// Takes back the last count (and its stats). False when at zero.
  bool undo() {
    if (!state.loaded || state.count == 0) return false;
    final id = state.current.id;
    _set(state.copyWith(
      counts: _withCount(id, state.count - 1),
      stats: state.stats.add(id, -1, _repository.today),
    ));
    return true;
  }

  /// Back to zero. Stats keep what was said.
  void reset() => _set(state.copyWith(counts: _withCount(state.currentId, 0)));

  void select(String id) {
    if (id == state.currentId || !state.adhkar.any((d) => d.id == id)) return;
    _set(state.copyWith(currentId: id));
  }

  /// Moves to the following dhikr (wrapping round). A dhikr that reached its
  /// target starts again from zero next time.
  void next() {
    final list = state.adhkar;
    final i = list.indexWhere((d) => d.id == state.currentId);
    final following = list[(i + 1) % list.length];
    _set(state.copyWith(
      currentId: following.id,
      counts: state.reached(state.current)
          ? _withCount(state.currentId, 0)
          : null,
    ));
  }

  /// [target] null counts without a limit.
  void setTarget(String id, int? target) {
    _set(state.copyWith(adhkar: [
      for (final d in state.adhkar) d.id == id ? d.withTarget(target) : d,
    ]));
  }

  /// Adds a custom dhikr and switches to it.
  TasbihDhikr addCustom(String text, int? target) {
    final dhikr = TasbihDhikr(
      id: 'custom-${_repository.now.microsecondsSinceEpoch}',
      text: text.trim(),
      target: target,
      custom: true,
    );
    _set(state.copyWith(adhkar: [...state.adhkar, dhikr], currentId: dhikr.id));
    return dhikr;
  }

  /// Deletes a custom dhikr with its count and all-time total.
  void remove(String id) {
    final dhikr = state.adhkar.where((d) => d.id == id).firstOrNull;
    if (dhikr == null || !dhikr.custom) return;
    final adhkar = [...state.adhkar]..remove(dhikr);
    _set(state.copyWith(
      adhkar: adhkar,
      currentId: state.currentId == id ? adhkar.first.id : null,
      counts: _withCount(id, 0),
      stats: state.stats.without(id),
    ));
  }

  void updateSettings(TasbihSettings settings) {
    state = state.copyWith(settings: settings);
    _repository.saveSettings(settings);
  }

  Map<String, int> _withCount(String id, int count) {
    final next = Map<String, int>.from(state.counts);
    if (count <= 0) {
      next.remove(id);
    } else {
      next[id] = count;
    }
    return next;
  }

  void _set(TasbihState next) {
    state = next;
    _unsaved = next;
    _flush();
  }

  Future<void> _flush() async {
    if (_saving) return;
    _saving = true;
    try {
      while (_unsaved != null) {
        final snapshot = _unsaved!;
        _unsaved = null;
        await _repository.save(snapshot);
      }
    } finally {
      _saving = false;
    }
  }
}

final tasbihProvider =
    StateNotifierProvider<TasbihNotifier, TasbihState>((ref) {
  return TasbihNotifier(ref.watch(tasbihRepositoryProvider));
});

/// Tasbihat counted today, across all adhkar.
final tasbihTodayProvider = Provider<int>((ref) {
  final stats = ref.watch(tasbihProvider.select((s) => s.stats));
  return stats.todayOn(ref.watch(tasbihRepositoryProvider).today);
});
