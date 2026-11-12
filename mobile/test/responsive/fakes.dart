// Realistic data for the responsive matrix: real surah names and verses
// (from qcf_quran), offline prayer times for Algiers, reciters with long
// names, a fixed clock. Nothing here touches the network or a plugin.
import 'dart:convert';

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lahuma/features/adhkar/data/adhkar_service.dart';
import 'package:lahuma/features/adhkar/presentation/adhkar_providers.dart';
import 'package:lahuma/features/quran/domain/reciter_repository.dart';
import 'package:lahuma/core/constants/storage_keys.dart';
import 'package:lahuma/features/adhan/presentation/adhan_providers.dart';
import 'package:lahuma/features/fajr_call/data/location_service.dart';
import 'package:lahuma/features/fajr_call/domain/fajr_call_list.dart';
import 'package:lahuma/features/fajr_call/presentation/fajr_call_providers.dart';
import 'package:lahuma/features/fajr_call/presentation/screens/fajr_wake_list_screen.dart';
import 'package:lahuma/core/notifications/local_notifications.dart';
import 'package:lahuma/features/khatma/data/khatma_notifications.dart';
import 'package:lahuma/features/khatma/domain/khatma.dart';
import 'package:lahuma/features/khatma/presentation/khatma_providers.dart';
import 'package:lahuma/features/mp3quran/domain/mp3quran_models.dart';
import 'package:lahuma/features/mp3quran/domain/reciter_photos.dart';
import 'package:lahuma/features/mp3quran/presentation/mp3quran_providers.dart';
import 'package:lahuma/features/prayer_times/data/prayer_times_service.dart';
import 'package:lahuma/features/prayer_times/data/reverse_geocoder.dart';
import 'package:lahuma/features/prayer_times/domain/local_prayer_times.dart';
import 'package:lahuma/features/prayer_times/domain/prayer_times.dart';
import 'package:lahuma/features/prayer_times/presentation/prayer_times_providers.dart';
import 'package:lahuma/features/prayer_times/presentation/widgets/prayer_lanterns.dart';
import 'package:lahuma/features/qibla/data/compass_source.dart';
import 'package:lahuma/features/qibla/presentation/qibla_providers.dart';
import 'package:lahuma/features/quran/domain/ayah.dart';
import 'package:lahuma/features/quran/domain/reciter.dart';
import 'package:lahuma/features/quran/domain/surah_audio.dart';
import 'package:lahuma/features/quran/presentation/providers/reciter_providers.dart';
import 'package:lahuma/features/quran/domain/surah.dart';
import 'package:lahuma/features/quran/domain/surah_detail.dart';
import 'package:lahuma/features/quran/presentation/providers/quran_providers.dart';
import 'package:qcf_quran/qcf_quran.dart' as qcf;

import '../helpers/fajr_call_fakes.dart';

/// Thursday 12 November 2026, mid-morning in Algiers.
final fixedNow = DateTime(2026, 11, 12, 10, 12);
DateTime clock() => fixedNow;

const algiersLocation =
    PrayerLocation(latitude: 36.754, longitude: 3.059, city: 'الجزائر العاصمة');

class _OfflineTimes extends PrayerTimesApiService {
  @override
  Future<DayPrayerTimes> fetch(DateTime day, double lat, double lng) async =>
      const LocalPrayerTimes().dayAt(day, algiersLocation);

  @override
  Future<List<DayPrayerTimes>> fetchRange(
          List<DateTime> days, double lat, double lng) async =>
      [for (final d in days) const LocalPrayerTimes().dayAt(d, algiersLocation)];
}

class _Here extends LocationService {
  const _Here();

  @override
  Future<({double latitude, double longitude})> currentPosition(
          {bool request = true}) async =>
      (latitude: algiersLocation.latitude, longitude: algiersLocation.longitude);

  @override
  Future<void> openSettings(LocationFailure reason) async {}
}

class _Geocoder extends ReverseGeocoder {
  const _Geocoder();

  @override
  Future<String> cityName(double lat, double lng) async => algiersLocation.city;
}

class _Compass extends CompassSource {
  @override
  Future<bool?> hasCompass() async => true;

  @override
  Stream<CompassReading> readings() =>
      Stream.value(const CompassReading(heading: 72, accuracy: 10));

  @override
  Future<double> declination(double latitude, double longitude) async => 1.2;
}

String _arabicName(int n) => 'سُورَةُ ${qcf.getSurahNameArabic(n)}';

final surahs = <Surah>[
  for (var n = 1; n <= 114; n++)
    Surah(
      number: n,
      arabicName: _arabicName(n),
      englishName: qcf.getSurahName(n),
      englishNameTranslation: qcf.getSurahNameEnglish(n),
      ayahCount: qcf.getVerseCount(n),
      revelationType: qcf.getPlaceOfRevelation(n) == 'Makkah' ? 'Meccan' : 'Medinan',
    ),
];

SurahDetail surahDetail(int n) {
  final count = qcf.getVerseCount(n);
  var global = 0;
  for (var i = 1; i < n; i++) {
    global += qcf.getVerseCount(i);
  }
  return SurahDetail(
    number: n,
    arabicName: _arabicName(n),
    englishName: qcf.getSurahName(n),
    englishNameTranslation: qcf.getSurahNameEnglish(n),
    revelationType: qcf.getPlaceOfRevelation(n) == 'Makkah' ? 'Meccan' : 'Medinan',
    ayahs: [
      for (var v = 1; v <= count; v++)
        Ayah(numberInSurah: v, text: qcf.getVerse(n, v), number: global + v),
    ],
  );
}

const _longTranslation =
    'Indeed, those who have believed and those who were Jews or Christians or '
    'Sabeans [before Prophet Muhammad] - those [among them] who believed in '
    'Allah and the Last Day and did righteousness - will have their reward '
    'with their Lord, and no fear will there be concerning them, nor will '
    'they grieve.';

const _longTafsir =
    'إن المؤمنين من هذه الأمة، الذين صدَّقوا بالله ورسله، وعملوا بشرعه، '
    'والذين كانوا قبل بعثة محمد صلى الله عليه وسلم من الأمم السالفة من اليهود '
    'والنصارى والصابئين، من آمن منهم بالله إيمانًا صادقًا خالصًا، وباليوم الآخر '
    'وعمل عملا صالحًا، فلهم ثوابهم عند ربهم.';

/// Reciters as mp3quran lists them, longest names included.
final mp3Reciters = <Mp3Reciter>[
  for (final (id, name) in const [
    (1, 'مشاري بن راشد العفاسي'),
    (2, 'عبد الرحمن بن عبد العزيز السديس'),
    (3, 'محمود خليل الحصري'),
    (4, 'عبد الباسط محمد عبد الصمد'),
    (5, 'أبو بكر الشاطري'),
    (6, 'محمد صديق المنشاوي'),
    (7, 'سعد بن سعيد الغامدي'),
    (8, 'ماهر بن حمد المعيقلي'),
    (9, 'ياسر بن راشد الدوسري'),
    (10, 'فارس عباد'),
  ])
    Mp3Reciter(
      id: id,
      name: name,
      moshaf: [
        Mp3Moshaf(
          id: id * 10,
          name: 'حفص عن عاصم - مرتل',
          server: 'https://server$id.mp3quran.net/reciter/',
          surahNumbers: [for (var n = 1; n <= 114; n++) n],
        ),
        if (id.isOdd)
          Mp3Moshaf(
            id: id * 10 + 1,
            name: 'ورش عن نافع من طريق أبي بكر الأصبهاني - مجود',
            server: 'https://server$id.mp3quran.net/warsh/',
            surahNumbers: [for (var n = 1; n <= 30; n++) n],
          ),
      ],
    ),
];

/// The app's own reciters (uploaded through the admin).
final lahumaReciters = <Reciter>[
  for (final (id, en, ar) in const [
    ('r1', 'Ahmed bin Ali Al-Ajmi', 'أحمد بن علي العجمي'),
    ('r2', 'Abdul Rahman Al-Sudais', 'عبد الرحمن بن عبد العزيز السديس'),
    ('r3', 'Mishary Rashid Alafasy', 'مشاري بن راشد العفاسي'),
  ])
    Reciter(
      id: id,
      name: en,
      displayName: ar,
      audioBasePath: '',
      audioUrls: {for (var n = 1; n <= 114; n += 3) n: 'https://example.invalid/$id/$n.mp3'},
    ),
];

List<SurahAudio> reciterSurahs(Reciter r) => [
      for (var n = 1; n <= 114; n++)
        SurahAudio(
          surahNumber: n,
          surahName: qcf.getSurahName(n),
          surahArabicName: qcf.getSurahNameArabic(n),
          isAvailable: r.audioUrls.containsKey(n),
        ),
    ];

/// Khatma reminders go nowhere (the notification plugin isn't there).
class _SilentKhatmaNotifications extends KhatmaNotifications {
  _SilentKhatmaNotifications() : super(LocalNotifications());

  @override
  Future<void> sync(Khatma? khatma,
      {required DateTime now, required bool arabic}) async {}
}

class _Reciters implements ReciterRepository {
  @override
  Future<List<Reciter>> getReciters() async => lahumaReciters;

  @override
  Future<List<SurahAudio>> getAvailableSurahs(Reciter reciter) async =>
      reciterSurahs(reciter);
}

/// Lists, contacts and a prayer place for the Fajr Call screens.
Map<String, Object> get fajrPrefs => {
      StorageKeys.fajrCallLists: jsonEncode([
        parentsList.toJson(),
        const FajrCallList(
          id: 'l2',
          name: 'الإخوة والأخوات وأبناء العمومة',
          enabled: false,
          contacts: [mother],
        ).toJson(),
      ]),
      StorageKeys.fajrCallPrayerSettings: jsonEncode(algiers.toJson()),
    };

/// Overrides every screen gets.
List<Override> get baseOverrides => [
      prayerClockProvider.overrideWithValue(clock),
      adhanClockProvider.overrideWithValue(clock),
      fajrClockProvider.overrideWithValue(clock),
      khatmaClockProvider.overrideWithValue(clock),
      khatmaNotificationsProvider
          .overrideWithValue(_SilentKhatmaNotifications()),
      prayerTimesApiProvider.overrideWithValue(_OfflineTimes()),
      prayerLocationServiceProvider.overrideWithValue(const _Here()),
      reverseGeocoderProvider.overrideWithValue(const _Geocoder()),
      screenGravityProvider.overrideWithValue(const Stream.empty()),
      compassSourceProvider.overrideWithValue(_Compass()),
      fajrCallPlatformProvider.overrideWithValue(FakeFajrPlatform()),
      fajrNotificationsProvider.overrideWithValue(FakeFajrNotifications()),
      dialerProvider.overrideWithValue((_) async => true),
      surahListProvider.overrideWith((ref) async => surahs),
      surahDetailProvider.overrideWith((ref, n) async => surahDetail(n)),
      translationProvider.overrideWith((ref, n) async => {
            for (var v = 1; v <= qcf.getVerseCount(n); v++) v: _longTranslation,
          }),
      tafsirProvider.overrideWith((ref, n) async => {
            for (var v = 1; v <= qcf.getVerseCount(n); v++) v: _longTafsir,
          }),
      mp3RecitersProvider.overrideWith((ref) async => mp3Reciters),
      mp3SuwarProvider.overrideWith(
          (ref) async => {for (var n = 1; n <= 114; n++) n: qcf.getSurahNameArabic(n)}),
      reciterPhotosProvider.overrideWith((ref) async => ReciterPhotos.empty),
      reciterListProvider.overrideWith((ref) async => lahumaReciters),
      reciterRepositoryProvider.overrideWithValue(_Reciters()),
      adhkarServiceProvider.overrideWithValue(AdhkarService(
          load: () async => File(AdhkarService.asset).readAsStringSync())),
      surahsForReciterProvider.overrideWith((ref, r) async => reciterSurahs(r)),
    ];
