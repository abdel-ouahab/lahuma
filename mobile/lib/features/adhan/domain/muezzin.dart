/// A muezzin from the bundled catalogue (MuezzinRepository). Its files are
/// downloaded from their URLs; [version] changes whenever a file does.
class Muezzin {
  const Muezzin({
    required this.id,
    required this.nameAr,
    required this.nameFr,
    required this.country,
    required this.regularUrl,
    required this.fajrUrl,
    required this.regularShortUrl,
    required this.fajrShortUrl,
    this.sortOrder = 0,
    this.version = 1,
  });

  final String id;
  final String nameAr;
  final String nameFr;

  /// ISO 3166 alpha-2.
  final String country;

  /// Full-length mp3s: the Android notification sound and the in-app player.
  final String regularUrl;

  /// With «الصلاة خير من النوم».
  final String fajrUrl;

  /// ≤ 30 s .caf / .wav, iOS notification sounds only.
  final String regularShortUrl;
  final String fajrShortUrl;
  final int sortOrder;
  final int version;

  String name(bool arabic) => arabic || nameFr.isEmpty ? nameAr : nameFr;

  String url(AdhanSoundKind kind) => switch (kind) {
        AdhanSoundKind.regular => regularUrl,
        AdhanSoundKind.fajr => fajrUrl,
        AdhanSoundKind.regularShort => regularShortUrl,
        AdhanSoundKind.fajrShort => fajrShortUrl,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameAr': nameAr,
        'nameFr': nameFr,
        'country': country,
        'regularUrl': regularUrl,
        'fajrUrl': fajrUrl,
        'regularShortUrl': regularShortUrl,
        'fajrShortUrl': fajrShortUrl,
        'sortOrder': sortOrder,
        'version': version,
      };

  factory Muezzin.fromJson(Map<String, dynamic> json) => Muezzin(
        id: json['id'] as String,
        nameAr: json['nameAr'] as String? ?? '',
        nameFr: json['nameFr'] as String? ?? '',
        country: json['country'] as String? ?? '',
        regularUrl: json['regularUrl'] as String,
        fajrUrl: json['fajrUrl'] as String,
        regularShortUrl: json['regularShortUrl'] as String? ?? '',
        fajrShortUrl: json['fajrShortUrl'] as String? ?? '',
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        version: (json['version'] as num?)?.toInt() ?? 1,
      );
}

/// The four files a muezzin has.
enum AdhanSoundKind {
  regular,
  fajr,
  regularShort,
  fajrShort;

  bool get isShort => this == regularShort || this == fajrShort;
  bool get isFajr => this == fajr || this == fajrShort;

  static AdhanSoundKind full({required bool fajr}) =>
      fajr ? AdhanSoundKind.fajr : AdhanSoundKind.regular;
  static AdhanSoundKind short({required bool fajr}) =>
      fajr ? AdhanSoundKind.fajrShort : AdhanSoundKind.regularShort;

  static AdhanSoundKind? tryParse(Object? value) {
    for (final k in values) {
      if (k.name == value) return k;
    }
    return null;
  }
}

/// A muezzin's files on this device, for one [version].
class AdhanDownload {
  const AdhanDownload({
    required this.muezzinId,
    required this.version,
    this.files = const {},
    this.androidUris = const {},
    this.iosSounds = const {},
  });

  final String muezzinId;
  final int version;

  /// Local paths of the downloaded files.
  final Map<AdhanSoundKind, String> files;

  /// Android: the `content://` URI of each full file, for channel sounds.
  final Map<AdhanSoundKind, String> androidUris;

  /// iOS: file names copied into `Library/Sounds`.
  final Map<AdhanSoundKind, String> iosSounds;

  Map<String, dynamic> toJson() => {
        'muezzinId': muezzinId,
        'version': version,
        'files': {for (final e in files.entries) e.key.name: e.value},
        'androidUris': {
          for (final e in androidUris.entries) e.key.name: e.value
        },
        'iosSounds': {for (final e in iosSounds.entries) e.key.name: e.value},
      };

  factory AdhanDownload.fromJson(Map<String, dynamic> json) {
    Map<AdhanSoundKind, String> kinds(Object? raw) => {
          if (raw is Map)
            for (final e in raw.entries)
              if (AdhanSoundKind.tryParse(e.key) != null && e.value is String)
                AdhanSoundKind.tryParse(e.key)!: e.value as String,
        };
    return AdhanDownload(
      muezzinId: json['muezzinId'] as String,
      version: (json['version'] as num).toInt(),
      files: kinds(json['files']),
      androidUris: kinds(json['androidUris']),
      iosSounds: kinds(json['iosSounds']),
    );
  }
}
