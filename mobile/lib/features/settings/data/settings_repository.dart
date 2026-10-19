import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_settings_enum.dart';
import '../../../core/constants/storage_keys.dart';

class SettingsRepository {
  Future<AppThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(StorageKeys.themeMode);
    return AppThemeMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.themeMode, mode.name);
  }

  Future<AppLocaleOption> getLocaleOption() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(StorageKeys.localeOption);
    return AppLocaleOption.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppLocaleOption.arabic,
    );
  }

  Future<void> setLocaleOption(AppLocaleOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.localeOption, option.name);
  }

  static const double minFontSize = 20;
  static const double maxFontSize = 40;
  static const double defaultFontSize = 26;

  Future<double> getReaderFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getDouble(StorageKeys.readerFontSize) ?? defaultFontSize)
        .clamp(minFontSize, maxFontSize);
  }

  Future<void> setReaderFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(StorageKeys.readerFontSize, size);
  }

  Future<bool> getShowTranslation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.showTranslation) ?? false;
  }

  Future<void> setShowTranslation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.showTranslation, value);
  }
}
