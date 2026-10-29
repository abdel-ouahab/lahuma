import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/dedication_repository.dart';

final dedicationRepositoryProvider = Provider((ref) => DedicationRepository());

class DedicationNotifier extends StateNotifier<Dedication> {
  DedicationNotifier(this._repository) : super(const Dedication()) {
    _load();
  }

  final DedicationRepository _repository;
  bool _loaded = false;

  Future<void> _load() async {
    state = await _repository.load();
    _loaded = true;
  }

  Future<void> set(
      {required DedicationTarget target, required String names}) async {
    state = state.copyWith(target: target, names: names.trim());
    await _repository.save(state);
  }

  Future<void> addRead(int count) async {
    if (count <= 0) return;
    if (!_loaded) await _load();
    state = state.copyWith(total: state.total + count);
    await _repository.save(state);
  }
}

final dedicationProvider =
    StateNotifierProvider<DedicationNotifier, Dedication>((ref) {
  return DedicationNotifier(ref.watch(dedicationRepositoryProvider));
});
