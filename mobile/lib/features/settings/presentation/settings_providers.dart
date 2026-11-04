import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_settings_enum.dart';
import '../data/settings_repository.dart';

final settingsRepositoryProvider = Provider((ref) => SettingsRepository());

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier(this._repository) : super(AppThemeMode.system) {
    ready = _load();
  }

  final SettingsRepository _repository;

  /// Completes once the saved mode is in [state].
  late final Future<void> ready;

  Future<void> _load() async {
    state = await _repository.getThemeMode();
  }

  Future<void> update(AppThemeMode mode) async {
    state = mode;
    await _repository.setThemeMode(mode);
  }
}

class LocaleNotifier extends StateNotifier<AppLocaleOption> {
  LocaleNotifier(this._repository) : super(AppLocaleOption.arabic) {
    ready = _load();
  }

  final SettingsRepository _repository;

  /// Completes once the saved language is in [state].
  late final Future<void> ready;

  Future<void> _load() async {
    state = await _repository.getLocaleOption();
  }

  Future<void> update(AppLocaleOption option) async {
    state = option;
    await _repository.setLocaleOption(option);
  }
}

class ReaderFontSizeNotifier extends StateNotifier<double> {
  ReaderFontSizeNotifier(this._repository)
      : super(SettingsRepository.defaultFontSize) {
    _load();
  }

  final SettingsRepository _repository;

  Future<void> _load() async {
    state = await _repository.getReaderFontSize();
  }

  Future<void> update(double size) async {
    state = size;
    await _repository.setReaderFontSize(size);
  }
}

class ShowTranslationNotifier extends StateNotifier<bool> {
  ShowTranslationNotifier(this._repository) : super(false) {
    _load();
  }

  final SettingsRepository _repository;

  Future<void> _load() async {
    state = await _repository.getShowTranslation();
  }

  Future<void> update(bool value) async {
    state = value;
    await _repository.setShowTranslation(value);
  }
}

class AutoScrollSpeedNotifier extends StateNotifier<int> {
  AutoScrollSpeedNotifier(this._repository)
      : super(SettingsRepository.defaultAutoScrollSpeed) {
    _load();
  }

  final SettingsRepository _repository;

  Future<void> _load() async {
    state = await _repository.getAutoScrollSpeed();
  }

  Future<void> update(int speed) async {
    state = speed.clamp(SettingsRepository.minAutoScrollSpeed,
        SettingsRepository.maxAutoScrollSpeed);
    await _repository.setAutoScrollSpeed(state);
  }
}

final readerFontSizeProvider =
    StateNotifierProvider<ReaderFontSizeNotifier, double>((ref) {
  return ReaderFontSizeNotifier(ref.watch(settingsRepositoryProvider));
});

final showTranslationProvider =
    StateNotifierProvider<ShowTranslationNotifier, bool>((ref) {
  return ShowTranslationNotifier(ref.watch(settingsRepositoryProvider));
});

final autoScrollSpeedProvider =
    StateNotifierProvider<AutoScrollSpeedNotifier, int>((ref) {
  return AutoScrollSpeedNotifier(ref.watch(settingsRepositoryProvider));
});

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(settingsRepositoryProvider));
});

final localeOptionProvider =
    StateNotifierProvider<LocaleNotifier, AppLocaleOption>((ref) {
  return LocaleNotifier(ref.watch(settingsRepositoryProvider));
});
