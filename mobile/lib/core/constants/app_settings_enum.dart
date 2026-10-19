enum AppThemeMode { light, dark, system }

enum AppLocaleOption { arabic, english }

extension AppLocaleOptionX on AppLocaleOption {
  String get languageCode => this == AppLocaleOption.arabic ? 'ar' : 'en';
}
