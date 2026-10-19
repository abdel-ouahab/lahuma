import 'package:flutter/widgets.dart';

/// Inline bilingual strings: `context.tr('الرئيسية', 'Home')`.
///
/// The app's locale comes from the in-app language setting (see
/// `localeOptionProvider`), so this follows what the user picked, not the
/// device language.
extension TrContext on BuildContext {
  bool get isArabic => Localizations.localeOf(this).languageCode == 'ar';

  String tr(String ar, String en) => isArabic ? ar : en;
}
