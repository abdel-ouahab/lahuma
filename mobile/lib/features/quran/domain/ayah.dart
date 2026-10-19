class Ayah {
  const Ayah({
    required this.numberInSurah,
    required this.text,
    this.number = 0,
  });

  /// Position inside its surah (1-based).
  final int numberInSurah;
  final String text;

  /// Position in the whole Quran (1–6236). 0 when unknown. Used to address
  /// per-ayah audio.
  final int number;

  factory Ayah.fromJson(Map<String, dynamic> json) {
    return Ayah(
      numberInSurah: json['numberInSurah'] as int,
      text: json['text'] as String,
      number: (json['number'] as int?) ?? 0,
    );
  }
}
