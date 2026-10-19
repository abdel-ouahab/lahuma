class Bookmark {
  const Bookmark({
    required this.surahId,
    required this.ayahNumber,
    required this.surahName,
    required this.createdAt,
  });

  final int surahId;
  final int ayahNumber;
  final String surahName;
  final DateTime createdAt;

  String get id => '$surahId-$ayahNumber';

  Map<String, dynamic> toJson() => {
        'surahId': surahId,
        'ayahNumber': ayahNumber,
        'surahName': surahName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        surahId: json['surahId'] as int,
        ayahNumber: json['ayahNumber'] as int,
        surahName: json['surahName'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
