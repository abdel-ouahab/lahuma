class Surah {
  const Surah({
    required this.number,
    required this.arabicName,
    required this.englishName,
    required this.englishNameTranslation,
    required this.ayahCount,
    required this.revelationType,
  });

  final int number;
  final String arabicName;
  final String englishName;
  final String englishNameTranslation;
  final int ayahCount;

  /// 'Meccan' or 'Medinan' — from API `revelationType` field.
  final String revelationType;

  /// Localized revelation type label in Arabic.
  String get revelationTypeArabic =>
      revelationType.toLowerCase() == 'meccan' ? 'مكية' : 'مدنية';

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      number: json['number'] as int,
      arabicName: json['name'] as String,
      englishName: json['englishName'] as String,
      englishNameTranslation: (json['englishNameTranslation'] as String?) ?? '',
      ayahCount: json['numberOfAyahs'] as int,
      revelationType: (json['revelationType'] as String?) ?? 'Meccan',
    );
  }
}
