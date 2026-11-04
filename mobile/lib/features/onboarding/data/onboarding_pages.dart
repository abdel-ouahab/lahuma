import 'package:flutter/widgets.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/localization/tr.dart';

/// The introduction's pages, in reading order. Eight features over six
/// pages, then a short last step.
enum OnboardingPageId {
  welcome,
  readAndListen,
  khatma,
  prayer,
  fajrCall,
  remembrance,
  start,
}

/// One page's words and the tint its background leans towards. Strings are
/// Arabic and English pairs, resolved with [TrContext.tr].
@immutable
class OnboardingPage {
  const OnboardingPage({
    required this.id,
    required this.title,
    required this.body,
    required this.art,
    required this.tint,
    this.iosNote,
  });

  final OnboardingPageId id;
  final (String, String) title;
  final (String, String) body;

  /// What the illustration shows, for VoiceOver / TalkBack.
  final (String, String) art;

  /// A sky or gilding colour from the palette; washed faintly behind the
  /// page.
  final Color tint;

  /// A second line on iOS, where the feature works differently.
  final (String, String)? iosNote;

  bool get isLast => id == OnboardingPageId.start;
}

extension OnboardingText on BuildContext {
  String trPair((String, String) pair) => tr(pair.$1, pair.$2);
}

const List<OnboardingPage> onboardingPages = [
  OnboardingPage(
    id: OnboardingPageId.welcome,
    title: ('إحسان', 'Ihsan'),
    body: (
      'اجعل تلاوتك صدقةً جاريةً لوالديك؛ كلُّ آيةٍ تقرؤها تُهدى لهما.',
      'Make your recitation a lasting charity for your parents. Every ayah '
          'you read is a gift to them.',
    ),
    art: (
      'شعار إحسان داخل نجمة ذهبية، وعدّاد للآيات المُهداة للوالدين',
      'The Ihsan logo inside a gold star, with a count of ayahs gifted to '
          'your parents',
    ),
    tint: AppColors.gold,
  ),
  OnboardingPage(
    id: OnboardingPageId.readAndListen,
    title: ('اقرأ واستمع', 'Read and listen'),
    body: (
      'مصحفٌ واضح مع التفسير والترجمة، وتلاواتٌ بأصوات كبار القرّاء.',
      'A clear Mushaf with tafsir and translation, and recitations from a '
          'wide choice of reciters.',
    ),
    art: (
      'صفحة من المصحف تُتلى آيتها، وشريط تشغيل لقارئ',
      'A Mushaf page with the ayah being recited, and a reciter playing',
    ),
    tint: AppColors.accent,
  ),
  OnboardingPage(
    id: OnboardingPageId.khatma,
    title: ('ختمتك في موعدها', 'Finish your khatma'),
    body: (
      'خطّة ختمة تناسب وقتك، وورد يومي يذكّرك بلطف.',
      'A khatma plan that fits your time, with a daily wird and gentle '
          'reminders.',
    ),
    art: (
      'حلقة الأجزاء تمتلئ، وأيام الأسبوع، وأيام متتالية من الورد',
      'The juz ring filling up, the days of the week and a wird streak',
    ),
    tint: AppColors.prayerGreen,
  ),
  OnboardingPage(
    id: OnboardingPageId.prayer,
    title: ('صلاتك في وقتها', 'Pray on time'),
    body: (
      'مواقيت دقيقة حسب موقعك، وأذانٌ في وقته، وقبلةٌ أينما كنت.',
      'Accurate prayer times for where you are, the adhan on time, and the '
          'qibla wherever you go.',
    ),
    art: (
      'بطاقة المواقيت والصلاة القادمة، وبوصلة تستقر على القبلة',
      'The prayer times with the next prayer, and a compass settling on the '
          'qibla',
    ),
    tint: AppColors.tileTeal,
  ),
  OnboardingPage(
    id: OnboardingPageId.fajrCall,
    title: ('نداء الفجر', 'Fajr Call'),
    body: (
      'عند الفجر يتّصل هاتفك بمن تحب واحدًا تلو الآخر؛ لعلّ اتصالك يكون '
          'سببًا في صلاة.',
      'At Fajr your phone calls your loved ones one by one. Your call might '
          'be the reason for a prayer.',
    ),
    iosNote: (
      'على iPhone: تذكيرٌ بقائمة الاتصال، ونقرةٌ واحدة لكل اتصال.',
      'On iPhone: a reminder with your call list, one tap per call.',
    ),
    art: (
      'سماء الفجر، وهاتف يتصل، وأمي وأبي يستيقظان',
      'A dawn sky, a phone calling, and Mum and Dad waking up',
    ),
    tint: AppColors.tileOrange,
  ),
  OnboardingPage(
    id: OnboardingPageId.remembrance,
    title: ('ذكرٌ لا ينقطع', 'Keep remembering'),
    body: (
      'أذكار الصباح والمساء، وسبحةٌ تحفظ عدّك.',
      'Morning and evening adhkar, and a tasbih that keeps your count.',
    ),
    art: (
      'سبحة تنزلق حباتها حتى ثلاث وثلاثين، وبطاقة أذكار الصباح',
      'Prayer beads sliding up to thirty-three, and the morning adhkar',
    ),
    tint: AppColors.tileYellow,
  ),
  OnboardingPage(
    id: OnboardingPageId.start,
    title: ('بسم الله، لنبدأ', "Let's begin"),
    body: (
      'اختر اللغة والمظهر، ويمكنك تغييرهما لاحقًا من الإعدادات.',
      'Pick a language and look. You can change both later in Settings.',
    ),
    art: ('نجمة ذهبية', 'A gold star'),
    tint: AppColors.gold,
  ),
];
