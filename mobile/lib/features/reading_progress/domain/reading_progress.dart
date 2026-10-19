class ReadingProgress {
  const ReadingProgress({
    required this.surahId,
    required this.surahName,
    required this.ayahNumber,
    this.totalAyahs = 0,
  });

  final int surahId;
  final String surahName;
  final int ayahNumber;

  /// Ayah count of the surah (0 when unknown, e.g. data saved by an older
  /// app version).
  final int totalAyahs;

  /// How far through the surah the reader is, 0–100. Null when unknown.
  double? get percent {
    if (totalAyahs <= 0) return null;
    return (ayahNumber / totalAyahs * 100).clamp(0, 100).toDouble();
  }
}
