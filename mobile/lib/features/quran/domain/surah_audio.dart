import 'package:equatable/equatable.dart';

/// Maps a Surah number to its audio filename for a given reciter.
class SurahAudio extends Equatable {
  const SurahAudio({
    required this.surahNumber,
    required this.surahName,
    required this.surahArabicName,
    this.customFileName,
    this.isAvailable = true,
  });

  final int surahNumber;

  /// English transliteration, e.g. "Al-Fatiha"
  final String surahName;

  /// Arabic name, e.g. "الفاتحة"
  final String surahArabicName;

  /// Optional custom audio filename (e.g. "001 copy.mp3")
  final String? customFileName;

  /// False when the reciter has no audio uploaded for this surah.
  final bool isAvailable;

  /// Returns the audio filename, defaulting to 3-digit zero-padded "001.mp3"
  String get fileName {
    if (customFileName != null && customFileName!.isNotEmpty) {
      return customFileName!;
    }
    final padded = surahNumber.toString().padLeft(3, '0');
    return '$padded.mp3';
  }

  @override
  List<Object?> get props =>
      [surahNumber, surahName, surahArabicName, customFileName, isAvailable];
}
