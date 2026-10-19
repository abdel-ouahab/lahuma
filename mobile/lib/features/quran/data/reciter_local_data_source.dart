import '../../../core/network/api_client.dart';
import '../domain/reciter.dart';
import '../domain/surah_audio.dart';

/// Loads reciters from the backend (`GET /reciters`) and maps every reciter's
/// uploaded audio onto the full list of 114 surahs.
class ReciterLocalDataSource {
  ReciterLocalDataSource(this._client);

  final ApiClient _client;

  /// Origin of the backend (without the `/api` suffix), used to resolve the
  /// relative `/audio/...` URLs returned by the API.
  String get _origin {
    final base = _client.dio.options.baseUrl;
    return base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
  }

  Future<List<Reciter>> fetchReciters() async {
    final res = await _client.dio.get('/reciters');
    final list = (res.data['reciters'] as List).cast<Map<String, dynamic>>();
    // The API returns newest first; show oldest first so the order is stable.
    return list.reversed.map(_toReciter).toList();
  }

  Reciter _toReciter(Map<String, dynamic> json) {
    final urls = <int, String>{};
    for (final s in (json['surahs'] as List).cast<Map<String, dynamic>>()) {
      final url = s['audioUrl'] as String?;
      if (url != null) urls[s['surahNumber'] as int] = '$_origin$url';
    }
    final name = json['name'] as String;
    final nameAr = json['nameAr'] as String?;
    return Reciter(
      id: json['id'] as String,
      name: name,
      displayName: (nameAr != null && nameAr.isNotEmpty) ? nameAr : name,
      audioBasePath: '',
      audioUrls: urls,
    );
  }

  /// Returns all 114 surahs for [reciter]; those without an uploaded audio
  /// file are flagged unavailable.
  Future<List<SurahAudio>> fetchAvailableSurahs(Reciter reciter) async {
    return [
      for (final s in _all114Surahs)
        SurahAudio(
          surahNumber: s.surahNumber,
          surahName: s.surahName,
          surahArabicName: s.surahArabicName,
          isAvailable: reciter.audioUrls.containsKey(s.surahNumber),
        ),
    ];
  }

  static const List<SurahAudio> _all114Surahs = [
    SurahAudio(
        surahNumber: 1, surahName: 'Al-Fatiha', surahArabicName: 'الفاتحة'),
    SurahAudio(
        surahNumber: 2, surahName: 'Al-Baqarah', surahArabicName: 'البقرة'),
    SurahAudio(
        surahNumber: 3, surahName: 'Ali \'Imran', surahArabicName: 'آل عمران'),
    SurahAudio(surahNumber: 4, surahName: 'An-Nisa', surahArabicName: 'النساء'),
    SurahAudio(
        surahNumber: 5, surahName: 'Al-Ma\'idah', surahArabicName: 'المائدة'),
    SurahAudio(
        surahNumber: 6, surahName: 'Al-An\'am', surahArabicName: 'الأنعام'),
    SurahAudio(
        surahNumber: 7, surahName: 'Al-A\'raf', surahArabicName: 'الأعراف'),
    SurahAudio(
        surahNumber: 8, surahName: 'Al-Anfal', surahArabicName: 'الأنفال'),
    SurahAudio(
        surahNumber: 9, surahName: 'At-Tawbah', surahArabicName: 'التوبة'),
    SurahAudio(surahNumber: 10, surahName: 'Yunus', surahArabicName: 'يونس'),
    SurahAudio(surahNumber: 11, surahName: 'Hud', surahArabicName: 'هود'),
    SurahAudio(surahNumber: 12, surahName: 'Yusuf', surahArabicName: 'يوسف'),
    SurahAudio(
        surahNumber: 13, surahName: 'Ar-Ra\'d', surahArabicName: 'الرعد'),
    SurahAudio(
        surahNumber: 14, surahName: 'Ibrahim', surahArabicName: 'إبراهيم'),
    SurahAudio(surahNumber: 15, surahName: 'Al-Hijr', surahArabicName: 'الحجر'),
    SurahAudio(surahNumber: 16, surahName: 'An-Nahl', surahArabicName: 'النحل'),
    SurahAudio(
        surahNumber: 17, surahName: 'Al-Isra', surahArabicName: 'الإسراء'),
    SurahAudio(surahNumber: 18, surahName: 'Al-Kahf', surahArabicName: 'الكهف'),
    SurahAudio(surahNumber: 19, surahName: 'Maryam', surahArabicName: 'مريم'),
    SurahAudio(surahNumber: 20, surahName: 'Taha', surahArabicName: 'طه'),
    SurahAudio(
        surahNumber: 21, surahName: 'Al-Anbiya', surahArabicName: 'الأنبياء'),
    SurahAudio(surahNumber: 22, surahName: 'Al-Hajj', surahArabicName: 'الحج'),
    SurahAudio(
        surahNumber: 23,
        surahName: 'Al-Mu\'minun',
        surahArabicName: 'المؤمنون'),
    SurahAudio(surahNumber: 24, surahName: 'An-Nur', surahArabicName: 'النور'),
    SurahAudio(
        surahNumber: 25, surahName: 'Al-Furqan', surahArabicName: 'الفرقان'),
    SurahAudio(
        surahNumber: 26, surahName: 'Ash-Shu\'ara', surahArabicName: 'الشعراء'),
    SurahAudio(surahNumber: 27, surahName: 'An-Naml', surahArabicName: 'النمل'),
    SurahAudio(
        surahNumber: 28, surahName: 'Al-Qasas', surahArabicName: 'القصص'),
    SurahAudio(
        surahNumber: 29, surahName: 'Al-Ankabut', surahArabicName: 'العنكبوت'),
    SurahAudio(surahNumber: 30, surahName: 'Ar-Rum', surahArabicName: 'الروم'),
    SurahAudio(surahNumber: 31, surahName: 'Luqman', surahArabicName: 'لقمان'),
    SurahAudio(
        surahNumber: 32, surahName: 'As-Sajdah', surahArabicName: 'السجدة'),
    SurahAudio(
        surahNumber: 33, surahName: 'Al-Ahzab', surahArabicName: 'الأحزاب'),
    SurahAudio(surahNumber: 34, surahName: 'Saba', surahArabicName: 'سبأ'),
    SurahAudio(surahNumber: 35, surahName: 'Fatir', surahArabicName: 'فاطر'),
    SurahAudio(surahNumber: 36, surahName: 'Ya-Sin', surahArabicName: 'يس'),
    SurahAudio(
        surahNumber: 37, surahName: 'As-Saffat', surahArabicName: 'الصافات'),
    SurahAudio(surahNumber: 38, surahName: 'Sad', surahArabicName: 'ص'),
    SurahAudio(
        surahNumber: 39, surahName: 'Az-Zumar', surahArabicName: 'الزمر'),
    SurahAudio(surahNumber: 40, surahName: 'Ghafir', surahArabicName: 'غافر'),
    SurahAudio(surahNumber: 41, surahName: 'Fussilat', surahArabicName: 'فصلت'),
    SurahAudio(
        surahNumber: 42, surahName: 'Ash-Shura', surahArabicName: 'الشورى'),
    SurahAudio(
        surahNumber: 43, surahName: 'Az-Zukhruf', surahArabicName: 'الزخرف'),
    SurahAudio(
        surahNumber: 44, surahName: 'Ad-Dukhan', surahArabicName: 'الدخان'),
    SurahAudio(
        surahNumber: 45, surahName: 'Al-Jathiyah', surahArabicName: 'الجاثية'),
    SurahAudio(
        surahNumber: 46, surahName: 'Al-Ahqaf', surahArabicName: 'الأحقاف'),
    SurahAudio(surahNumber: 47, surahName: 'Muhammad', surahArabicName: 'محمد'),
    SurahAudio(surahNumber: 48, surahName: 'Al-Fath', surahArabicName: 'الفتح'),
    SurahAudio(
        surahNumber: 49, surahName: 'Al-Hujurat', surahArabicName: 'الحجرات'),
    SurahAudio(surahNumber: 50, surahName: 'Qaf', surahArabicName: 'ق'),
    SurahAudio(
        surahNumber: 51,
        surahName: 'Adh-Dhariyat',
        surahArabicName: 'الذاريات'),
    SurahAudio(surahNumber: 52, surahName: 'At-Tur', surahArabicName: 'الطور'),
    SurahAudio(surahNumber: 53, surahName: 'An-Najm', surahArabicName: 'النجم'),
    SurahAudio(
        surahNumber: 54, surahName: 'Al-Qamar', surahArabicName: 'القمر'),
    SurahAudio(
        surahNumber: 55, surahName: 'Ar-Rahman', surahArabicName: 'الرحمن'),
    SurahAudio(
        surahNumber: 56, surahName: 'Al-Waqi\'ah', surahArabicName: 'الواقعة'),
    SurahAudio(
        surahNumber: 57, surahName: 'Al-Hadid', surahArabicName: 'الحديد'),
    SurahAudio(
        surahNumber: 58, surahName: 'Al-Mujadila', surahArabicName: 'المجادلة'),
    SurahAudio(
        surahNumber: 59, surahName: 'Al-Hashr', surahArabicName: 'الحشر'),
    SurahAudio(
        surahNumber: 60,
        surahName: 'Al-Mumtahanah',
        surahArabicName: 'الممتحنة'),
    SurahAudio(surahNumber: 61, surahName: 'As-Saff', surahArabicName: 'الصف'),
    SurahAudio(
        surahNumber: 62, surahName: 'Al-Jumu\'ah', surahArabicName: 'الجمعة'),
    SurahAudio(
        surahNumber: 63,
        surahName: 'Al-Munafiqun',
        surahArabicName: 'المنافقون'),
    SurahAudio(
        surahNumber: 64, surahName: 'At-Taghabun', surahArabicName: 'التغابن'),
    SurahAudio(
        surahNumber: 65, surahName: 'At-Talaq', surahArabicName: 'الطلاق'),
    SurahAudio(
        surahNumber: 66, surahName: 'At-Tahrim', surahArabicName: 'التحريم'),
    SurahAudio(surahNumber: 67, surahName: 'Al-Mulk', surahArabicName: 'الملك'),
    SurahAudio(
        surahNumber: 68, surahName: 'Al-Qalam', surahArabicName: 'القلم'),
    SurahAudio(
        surahNumber: 69, surahName: 'Al-Haqqah', surahArabicName: 'الحاقة'),
    SurahAudio(
        surahNumber: 70, surahName: 'Al-Ma\'arij', surahArabicName: 'المعارج'),
    SurahAudio(surahNumber: 71, surahName: 'Nuh', surahArabicName: 'نوح'),
    SurahAudio(surahNumber: 72, surahName: 'Al-Jinn', surahArabicName: 'الجن'),
    SurahAudio(
        surahNumber: 73, surahName: 'Al-Muzzammil', surahArabicName: 'المزمل'),
    SurahAudio(
        surahNumber: 74,
        surahName: 'Al-Muddaththir',
        surahArabicName: 'المدثر'),
    SurahAudio(
        surahNumber: 75, surahName: 'Al-Qiyamah', surahArabicName: 'القيامة'),
    SurahAudio(
        surahNumber: 76, surahName: 'Al-Insan', surahArabicName: 'الإنسان'),
    SurahAudio(
        surahNumber: 77, surahName: 'Al-Mursalat', surahArabicName: 'المرسلات'),
    SurahAudio(surahNumber: 78, surahName: 'An-Naba', surahArabicName: 'النبأ'),
    SurahAudio(
        surahNumber: 79, surahName: 'An-Nazi\'at', surahArabicName: 'النازعات'),
    SurahAudio(surahNumber: 80, surahName: '\'Abasa', surahArabicName: 'عبس'),
    SurahAudio(
        surahNumber: 81, surahName: 'At-Takwir', surahArabicName: 'التكوير'),
    SurahAudio(
        surahNumber: 82, surahName: 'Al-Infitar', surahArabicName: 'الانفطار'),
    SurahAudio(
        surahNumber: 83,
        surahName: 'Al-Mutaffifin',
        surahArabicName: 'المطففين'),
    SurahAudio(
        surahNumber: 84, surahName: 'Al-Inshiqaq', surahArabicName: 'الانشقاق'),
    SurahAudio(
        surahNumber: 85, surahName: 'Al-Burooj', surahArabicName: 'البروج'),
    SurahAudio(
        surahNumber: 86, surahName: 'At-Tariq', surahArabicName: 'الطارق'),
    SurahAudio(
        surahNumber: 87, surahName: 'Al-A\'la', surahArabicName: 'الأعلى'),
    SurahAudio(
        surahNumber: 88, surahName: 'Al-Ghashiyah', surahArabicName: 'الغاشية'),
    SurahAudio(surahNumber: 89, surahName: 'Al-Fajr', surahArabicName: 'الفجر'),
    SurahAudio(
        surahNumber: 90, surahName: 'Al-Balad', surahArabicName: 'البلد'),
    SurahAudio(
        surahNumber: 91, surahName: 'Ash-Shams', surahArabicName: 'الشمس'),
    SurahAudio(surahNumber: 92, surahName: 'Al-Layl', surahArabicName: 'الليل'),
    SurahAudio(surahNumber: 93, surahName: 'Ad-Duha', surahArabicName: 'الضحى'),
    SurahAudio(
        surahNumber: 94, surahName: 'Ash-Sharh', surahArabicName: 'الشرح'),
    SurahAudio(surahNumber: 95, surahName: 'At-Tin', surahArabicName: 'التين'),
    SurahAudio(
        surahNumber: 96, surahName: 'Al-\'Alaq', surahArabicName: 'العلق'),
    SurahAudio(surahNumber: 97, surahName: 'Al-Qadr', surahArabicName: 'القدر'),
    SurahAudio(
        surahNumber: 98, surahName: 'Al-Bayyinah', surahArabicName: 'البينة'),
    SurahAudio(
        surahNumber: 99, surahName: 'Az-Zalzalah', surahArabicName: 'الزلزلة'),
    SurahAudio(
        surahNumber: 100,
        surahName: 'Al-\'Adiyat',
        surahArabicName: 'العاديات'),
    SurahAudio(
        surahNumber: 101, surahName: 'Al-Qari\'ah', surahArabicName: 'القارعة'),
    SurahAudio(
        surahNumber: 102, surahName: 'At-Takathur', surahArabicName: 'التكاثر'),
    SurahAudio(
        surahNumber: 103, surahName: 'Al-\'Asr', surahArabicName: 'العصر'),
    SurahAudio(
        surahNumber: 104, surahName: 'Al-Humazah', surahArabicName: 'الهمزة'),
    SurahAudio(surahNumber: 105, surahName: 'Al-Fil', surahArabicName: 'الفيل'),
    SurahAudio(surahNumber: 106, surahName: 'Quraysh', surahArabicName: 'قريش'),
    SurahAudio(
        surahNumber: 107, surahName: 'Al-Ma\'un', surahArabicName: 'الماعون'),
    SurahAudio(
        surahNumber: 108, surahName: 'Al-Kawthar', surahArabicName: 'الكوثر'),
    SurahAudio(
        surahNumber: 109, surahName: 'Al-Kafirun', surahArabicName: 'الكافرون'),
    SurahAudio(
        surahNumber: 110, surahName: 'An-Nasr', surahArabicName: 'النصر'),
    SurahAudio(
        surahNumber: 111, surahName: 'Al-Masad', surahArabicName: 'المسد'),
    SurahAudio(
        surahNumber: 112, surahName: 'Al-Ikhlas', surahArabicName: 'الإخلاص'),
    SurahAudio(
        surahNumber: 113, surahName: 'Al-Falaq', surahArabicName: 'الفلق'),
    SurahAudio(surahNumber: 114, surahName: 'An-Nas', surahArabicName: 'الناس'),
  ];
}
