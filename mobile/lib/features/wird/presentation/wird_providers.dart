import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/wird_repository.dart';

final wirdRepositoryProvider = Provider((ref) => WirdRepository());

class WirdNotifier extends StateNotifier<WirdState> {
  WirdNotifier(this._repository)
      : super(const WirdState(
          date: '',
          ayahsToday: 0,
          goal: WirdRepository.defaultGoal,
          streak: 0,
        )) {
    _load();
  }

  final WirdRepository _repository;
  bool _loaded = false;

  Future<void> _load() async {
    state = await _repository.load();
    _loaded = true;
  }

  Future<void> addRead(int count) async {
    if (count <= 0) return;
    if (!_loaded) await _load();
    state = await _repository.addRead(state, count);
  }

  Future<void> setGoal(int goal) async {
    state = await _repository.setGoal(state, goal);
  }
}

final wirdProvider = StateNotifierProvider<WirdNotifier, WirdState>((ref) {
  return WirdNotifier(ref.watch(wirdRepositoryProvider));
});
