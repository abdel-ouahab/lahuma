import 'ayah.dart';

class SurahDetail {
  const SurahDetail({
    required this.number,
    required this.arabicName,
    required this.englishName,
    required this.englishNameTranslation,
    required this.ayahs,
    required this.revelationType,
  });

  final int number;
  final String arabicName;
  final String englishName;
  final String englishNameTranslation;
  final List<Ayah> ayahs;

  /// 'Meccan' or 'Medinan'
  final String revelationType;

  int get numberOfAyahs => ayahs.length;

  /// Localized revelation type label in Arabic.
  String get revelationTypeArabic =>
      revelationType.toLowerCase() == 'meccan' ? 'مكية' : 'مدنية';

  factory SurahDetail.fromJson(Map<String, dynamic> json) {
    final number = json['number'] as int;
    return SurahDetail(
      number: number,
      arabicName: json['name'] as String,
      englishName: json['englishName'] as String,
      englishNameTranslation: (json['englishNameTranslation'] as String?) ?? '',
      revelationType: (json['revelationType'] as String?) ?? 'Meccan',
      ayahs: (json['ayahs'] as List)
          .map((e) => Ayah.fromJson(e as Map<String, dynamic>))
          .map((a) => _withoutBasmala(number, a))
          .toList(),
    );
  }

  /// The API prepends the Basmala to ayah 1 of every surah except Al-Fatiha
  /// (where it *is* ayah 1) and At-Tawbah. The reader draws the Basmala as
  /// its own line, so drop the four leading words here to avoid repeating it.
  static Ayah _withoutBasmala(int surah, Ayah ayah) {
    if (ayah.numberInSurah != 1 || surah == 1 || surah == 9) return ayah;
    final words = ayah.text.trim().split(RegExp(r'\s+'));
    final bare = words.first.replaceAll(RegExp(r'[ً-ٰٟۖ-ۭ]'), '');
    if (words.length <= 4 || !bare.startsWith('بسم')) return ayah;
    return Ayah(
      numberInSurah: ayah.numberInSurah,
      number: ayah.number,
      text: words.sublist(4).join(' '),
    );
  }
}
