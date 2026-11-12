import '../domain/muezzin.dart';

/// The muezzins, bundled with the app: no backend involved.
///
/// The full adhans download straight from the Kiwifu/adhan-mp3 repository,
/// pinned to one commit so a file can never change under a [Muezzin.version].
/// That repository has no ≤ 30 s clips, so the iOS notification sounds ship
/// in `assets/audio/adhan/` (`asset:` URLs, copied by AdhanAudioStore).
///
/// The ids are the ones the backend used, so a saved choice stays selected.
class MuezzinRepository {
  MuezzinRepository();

  Future<List<Muezzin>> cached() async => catalogue;

  Future<List<Muezzin>> refresh() async => catalogue;

  static const _source = 'https://raw.githubusercontent.com/Kiwifu/adhan-mp3/'
      'b9180a2bb769f74cff8e378ef2cc7aaf8db5cd5b/';

  static String _file(String name) => '$_source${Uri.encodeComponent(name)}';

  static Muezzin _muezzin({
    required String id,
    required String slug,
    required String nameAr,
    required String nameFr,
    required String country,
    required String regular,
    required String fajr,
    required int sortOrder,
    required int version,
  }) =>
      Muezzin(
        id: id,
        nameAr: nameAr,
        nameFr: nameFr,
        country: country,
        regularUrl: _file(regular),
        fajrUrl: _file(fajr),
        regularShortUrl: 'asset:assets/audio/adhan/${slug}_regular_short.caf',
        fajrShortUrl: 'asset:assets/audio/adhan/${slug}_fajr_short.caf',
        sortOrder: sortOrder,
        version: version,
      );

  /// In display order.
  static final List<Muezzin> catalogue = List.unmodifiable([
    _muezzin(
      id: '00000000-0000-4000-8000-000000000003',
      slug: 'algeria',
      nameAr: 'أذان الجزائر',
      nameFr: "Adhan d'Algérie",
      country: 'DZ',
      regular: 'Riad_Al_Djazairi_-_Algeria_(رياض_الجزائري_-_الجزائر).mp3',
      fajr: 'Adhan_Fajr_Algeria_(أذان_الفجر_الجزائر).mp3',
      sortOrder: 0,
      version: 2,
    ),
    _muezzin(
      id: '00000000-0000-4000-8000-000000000004',
      slug: 'alafasy',
      nameAr: 'مشاري راشد العفاسي',
      nameFr: 'Mishary Rashid Alafasy',
      country: 'KW',
      regular:
          'Mishary_Rashid_Alafasy_1_-_Kuwait_(مشاري_راشد_العفاسي_-_الكويت).mp3',
      fajr:
          'Mishary_Rashid_Alafasy_3_-_Fajr_Kuwait_(مشاري_راشد_العفاسي_-_فجر_الكويت).mp3',
      sortOrder: 1,
      version: 1,
    ),
    _muezzin(
      id: '00000000-0000-4000-8000-000000000001',
      slug: 'makkah',
      nameAr: 'أذان الحرم المكي',
      nameFr: 'Adhan de La Mecque',
      country: 'SA',
      regular:
          'Ali_Ibn_Ahmad_Mala_1_-_Al_Haram_Al_Maki_(علي_بن_أحمد_ملا_-_الحرم_المكي).mp3',
      fajr: 'Adhan_Fajr_Al_Haram_Al_Maki_(أذان_الفجر_الحرم_المكي).mp3',
      sortOrder: 2,
      version: 2,
    ),
    _muezzin(
      id: '00000000-0000-4000-8000-000000000002',
      slug: 'madinah',
      nameAr: 'أذان المسجد النبوي',
      nameFr: 'Adhan de Médine',
      country: 'SA',
      regular:
          'Adhan_Al_Haram_Al_Madani_-_Al_Madinah_1_(أذان_الحرم_المدني_-_المدينة_المنورة).mp3',
      fajr: 'Adhan_Fajr_Al_Haram_Al_Madani_(أذان_الفجر_الحرم_المدني).mp3',
      sortOrder: 3,
      version: 2,
    ),
    _muezzin(
      id: '00000000-0000-4000-8000-000000000005',
      slug: 'abdulbasit',
      nameAr: 'عبد الباسط عبد الصمد',
      nameFr: 'Abdulbasit Abdusamad',
      country: 'EG',
      regular: 'Abdulbasit_Abdusamad_1_-_Egypt_(عبد_الباسط_عبد_الصمد_-_مصر).mp3',
      fajr:
          'Abdulbasit_Abdusamad_7_-_Fajr_Egypt_(عبد_الباسط_عبد_الصمد_-_فجر_مصر).mp3',
      sortOrder: 4,
      version: 1,
    ),
  ]);
}
