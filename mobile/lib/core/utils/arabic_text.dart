/// Harakat, superscript alef, Quranic annotation marks (e.g. the sukun form
/// `ۡ` in the Uthmani text) and tatweel.
final RegExp _marks = RegExp('[ً-ٰٟۖ-ۭـ]');

/// Strips diacritics and Quranic marks and unifies alef / yaa / taa-marbuta
/// forms, so that searching "احمد" matches "أحمد" and "السجدة" matches
/// "السَّجۡدَةِ".
String normalizeArabic(String s) {
  return s
      .replaceAll(_marks, '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .toLowerCase()
      .trim();
}

/// Turns Arabic-Indic digits (٠–٩) into Western ones.
String westernDigits(String s) => s.replaceAllMapped(
      RegExp('[٠-٩]'),
      (m) => '${m[0]!.codeUnitAt(0) - 0x0660}',
    );
