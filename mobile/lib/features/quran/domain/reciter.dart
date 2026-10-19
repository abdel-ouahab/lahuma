import 'package:equatable/equatable.dart';
import 'surah_audio.dart';

/// Represents a Quran reciter.
class Reciter extends Equatable {
  const Reciter({
    required this.id,
    required this.name,
    required this.displayName,
    required this.audioBasePath,
    this.audioUrls = const {},
  });

  final String id;
  final String name;
  final String displayName;
  final String audioBasePath;

  /// Absolute audio URL per surah number (only surahs that were uploaded).
  final Map<int, String> audioUrls;

  /// Returns the full asset path for a given [SurahAudio].
  String audioPathForSurah(SurahAudio surah) {
    return audioUrls[surah.surahNumber] ?? '$audioBasePath${surah.fileName}';
  }

  @override
  List<Object?> get props => [id, name, displayName, audioBasePath, audioUrls];
}
