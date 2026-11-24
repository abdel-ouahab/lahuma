import 'hijri_date.dart';

/// What kind of occasion an [IslamicEvent] is; picks its colour and glyph.
enum IslamicEventKind {
  /// The two Eids.
  eid,

  /// A day it is recommended to fast.
  fasting,

  /// A night sought for worship.
  night,

  /// A blessed stretch of days (Ramadan, the ten days of Dhu al-Hijjah).
  season,

  /// A date marked in memory (the new year, the Prophet's ﷺ life).
  remembrance,
}

/// A yearly (or, for [whiteDays], monthly) occasion of the Hijri calendar.
///
/// Texts hold only what is well established from the Quran and the Sunnah;
/// where the date itself is disputed, [IslamicEvent.descriptionAr] says so.
enum IslamicEvent {
  hijriNewYear(
    month: 1,
    day: 1,
    kind: IslamicEventKind.remembrance,
    nameAr: 'رأس السنة الهجرية',
    nameEn: 'Islamic New Year',
    descriptionAr:
        'أول يوم من شهر الله المحرّم، أول شهور السنة الهجرية وأحد الأشهر الحُرم.',
    descriptionEn:
        'The first day of Muharram, the first month of the Hijri year and one of the four sacred months.',
    tipAr: 'بداية عام هجري جديد.',
    tipEn: 'A new Hijri year begins.',
  ),
  tasua(
    month: 1,
    day: 9,
    kind: IslamicEventKind.fasting,
    nameAr: 'يوم تاسوعاء',
    nameEn: "Tasu'a",
    descriptionAr:
        'يُستحب صيامه مع عاشوراء، لقوله ﷺ: «لئن بقيتُ إلى قابلٍ لأصومنّ التاسع» (رواه مسلم).',
    descriptionEn:
        'Fasting it with Ashura is recommended. The Prophet ﷺ said: "If I live until next year, I will fast the ninth" (Muslim).',
    tipAr: 'يُستحب صيامه مع عاشوراء.',
    tipEn: 'It is recommended to fast it with Ashura.',
  ),
  ashura(
    month: 1,
    day: 10,
    kind: IslamicEventKind.fasting,
    nameAr: 'يوم عاشوراء',
    nameEn: 'Ashura',
    descriptionAr:
        'قال ﷺ عن صيامه: «أحتسب على الله أن يكفّر السنة التي قبله» (رواه مسلم).',
    descriptionEn:
        'The Prophet ﷺ said of fasting it: "I hope that Allah will expiate through it the sins of the year before" (Muslim).',
    tipAr: 'صيامه يكفّر السنة التي قبله.',
    tipEn: 'Fasting it expiates the year before.',
    remindByDefault: true,
  ),
  mawlid(
    month: 3,
    day: 12,
    kind: IslamicEventKind.remembrance,
    nameAr: 'ذكرى المولد النبوي',
    nameEn: "The Prophet's ﷺ birth",
    descriptionAr:
        'وُلد النبي ﷺ في شهر ربيع الأول عام الفيل، والمشهور أنه الثاني عشر منه.',
    descriptionEn:
        "The Prophet ﷺ was born in Rabi' al-Awwal in the Year of the Elephant; the best-known account gives the 12th.",
    tipAr: 'أكثِر من الصلاة على النبي ﷺ.',
    tipEn: 'Send many blessings on the Prophet ﷺ.',
  ),
  israMiraj(
    month: 7,
    day: 27,
    kind: IslamicEventKind.remembrance,
    nameAr: 'ذكرى الإسراء والمعراج',
    nameEn: "Isra and Mi'raj",
    descriptionAr:
        'رحلة النبي ﷺ من المسجد الحرام إلى المسجد الأقصى ثم إلى السماء، وفيها فُرضت الصلوات الخمس. وتحديد ليلتها مختلف فيه، والمشهور أنها السابع والعشرون من رجب.',
    descriptionEn:
        "The Prophet's ﷺ night journey from Makkah to Al-Aqsa and his ascension, when the five daily prayers were made obligatory. Its exact date is disputed; the 27th of Rajab is the best known.",
    tipAr: 'ذكرى فرض الصلوات الخمس.',
    tipEn: 'When the five prayers were made obligatory.',
  ),
  midShaban(
    month: 8,
    day: 15,
    kind: IslamicEventKind.night,
    nameAr: 'النصف من شعبان',
    nameEn: "Mid-Sha'ban",
    descriptionAr:
        'شعبان شهرٌ كان النبي ﷺ يُكثر فيه الصيام، وقال عنه: «ذلك شهرٌ يغفل الناس عنه بين رجب ورمضان، وهو شهرٌ تُرفع فيه الأعمال إلى رب العالمين» (رواه النسائي).',
    descriptionEn:
        'The Prophet ﷺ fasted much in Sha\'ban and said: "It is a month people neglect, between Rajab and Ramadan, in which deeds are raised to the Lord of the worlds" (An-Nasa\'i).',
    tipAr: 'استعدّ لرمضان، فقد اقترب.',
    tipEn: 'Ramadan is near: get ready.',
  ),
  ramadan(
    month: 9,
    day: 1,
    kind: IslamicEventKind.season,
    nameAr: 'بداية شهر رمضان',
    nameEn: 'Ramadan begins',
    descriptionAr:
        '﴿شَهْرُ رَمَضَانَ الَّذِي أُنزِلَ فِيهِ الْقُرْآنُ﴾. شهر الصيام والقيام وتلاوة القرآن، ويثبت دخوله برؤية الهلال.',
    descriptionEn:
        'The month in which the Quran was revealed: the month of fasting, night prayer and recitation. It begins with the sighting of the new moon.',
    tipAr: 'والليلة أول ليلة من التراويح.',
    tipEn: 'Tarawih begins tonight.',
    remindByDefault: true,
    bySighting: true,
  ),
  lastTenNights(
    month: 9,
    day: 21,
    days: 10,
    kind: IslamicEventKind.season,
    nameAr: 'العشر الأواخر من رمضان',
    nameEn: 'Last ten nights of Ramadan',
    descriptionAr:
        'كان النبي ﷺ يجتهد فيها ما لا يجتهد في غيرها (رواه مسلم)، وفيها ليلة القدر.',
    descriptionEn:
        'The Prophet ﷺ strove in them more than at any other time (Muslim). Laylat al-Qadr is among them.',
    tipAr: 'اجتهد فيها، ففيها ليلة القدر.',
    tipEn: 'Strive in them: Laylat al-Qadr is among them.',
    remindByDefault: true,
  ),
  laylatAlQadr(
    month: 9,
    day: 27,
    kind: IslamicEventKind.night,
    nameAr: 'ليلة السابع والعشرين',
    nameEn: 'The 27th night',
    descriptionAr:
        'تُرجى ليلة القدر في أوتار العشر الأواخر، وأرجاها ليلة السابع والعشرين. ﴿لَيْلَةُ الْقَدْرِ خَيْرٌ مِّنْ أَلْفِ شَهْرٍ﴾.',
    descriptionEn:
        'Laylat al-Qadr is sought in the odd nights of the last ten, most hoped for on the 27th. "The Night of Decree is better than a thousand months."',
    tipAr: 'تُرجى فيها ليلة القدر.',
    tipEn: 'Laylat al-Qadr is hoped for tonight.',
  ),
  eidAlFitr(
    month: 10,
    day: 1,
    kind: IslamicEventKind.eid,
    nameAr: 'عيد الفطر',
    nameEn: 'Eid al-Fitr',
    descriptionAr:
        'فرحة المسلمين بإتمام الصيام. يحرم صومه، وتُخرج زكاة الفطر قبل صلاة العيد، ويُسنّ التكبير من ليلته.',
    descriptionEn:
        'The celebration of completing the fast. Fasting is forbidden on it; zakat al-fitr is given before the Eid prayer, and the takbir begins the night before.',
    tipAr: 'أخرج زكاة الفطر قبل الصلاة، وكبّر.',
    tipEn: 'Give zakat al-fitr before the prayer, and say the takbir.',
    remindByDefault: true,
    bySighting: true,
  ),
  shawwalFasting(
    month: 10,
    day: 2,
    kind: IslamicEventKind.fasting,
    nameAr: 'صيام ستٍّ من شوال',
    nameEn: 'Six days of Shawwal',
    descriptionAr:
        'قال ﷺ: «من صام رمضان ثم أتبعه ستًّا من شوال كان كصيام الدهر» (رواه مسلم). تُصام في أي أيام الشهر بعد العيد.',
    descriptionEn:
        'The Prophet ﷺ said: "Whoever fasts Ramadan and follows it with six days of Shawwal, it is as if he fasted for a lifetime" (Muslim). Any days of the month after Eid.',
    tipAr: 'يمكنك البدء بصيام الست من شوال.',
    tipEn: 'You can start fasting the six days of Shawwal.',
  ),
  dhulHijjahTen(
    month: 12,
    day: 1,
    days: 9,
    kind: IslamicEventKind.season,
    nameAr: 'العشر الأوائل من ذي الحجة',
    nameEn: 'First ten days of Dhu al-Hijjah',
    descriptionAr:
        'قال ﷺ: «ما من أيامٍ العملُ الصالح فيها أحب إلى الله من هذه الأيام» يعني العشر (رواه البخاري). يُستحب فيها الإكثار من الذكر والتكبير والصيام.',
    descriptionEn:
        'The Prophet ﷺ said: "There are no days in which righteous deeds are more beloved to Allah than these ten days" (Bukhari). Remember Allah, say the takbir and fast much in them.',
    tipAr: 'تبدأ أحب الأيام إلى الله، فأكثر فيها من الذكر.',
    tipEn: 'The days most beloved to Allah begin: remember Him much.',
    remindByDefault: true,
    bySighting: true,
  ),
  arafah(
    month: 12,
    day: 9,
    kind: IslamicEventKind.fasting,
    nameAr: 'يوم عرفة',
    nameEn: 'Day of Arafah',
    descriptionAr:
        'قال ﷺ عن صيامه: «أحتسب على الله أن يكفّر السنة التي قبله والسنة التي بعده» (رواه مسلم). وهو لغير الحاج، وخير الدعاء دعاء يوم عرفة.',
    descriptionEn:
        'The Prophet ﷺ said of fasting it: "I hope that Allah will expiate through it the year before and the year after" (Muslim). It is for those not on Hajj, and the best supplication is that of Arafah.',
    tipAr: 'صيامه يكفّر سنتين، وأكثر فيه من الدعاء.',
    tipEn: 'Fasting it expiates two years; make much dua.',
    remindByDefault: true,
  ),
  eidAlAdha(
    month: 12,
    day: 10,
    kind: IslamicEventKind.eid,
    nameAr: 'عيد الأضحى',
    nameEn: 'Eid al-Adha',
    descriptionAr:
        'يوم النحر، يُصلّى فيه العيد وتُذبح الأضاحي بعد الصلاة، ويحرم صومه.',
    descriptionEn:
        'The Day of Sacrifice: the Eid prayer, then the sacrifice. Fasting is forbidden on it.',
    tipAr: 'كبّر، وتُذبح الأضحية بعد صلاة العيد.',
    tipEn: 'Say the takbir; the sacrifice comes after the Eid prayer.',
    remindByDefault: true,
  ),
  tashreeq(
    month: 12,
    day: 11,
    days: 3,
    kind: IslamicEventKind.eid,
    nameAr: 'أيام التشريق',
    nameEn: 'Days of Tashreeq',
    descriptionAr:
        'قال ﷺ: «أيام التشريق أيام أكلٍ وشربٍ وذكرٍ لله» (رواه مسلم). يستمر فيها التكبير ويحرم صومها.',
    descriptionEn:
        'The Prophet ﷺ said: "The days of Tashreeq are days of eating, drinking and remembering Allah" (Muslim). The takbir continues and fasting is forbidden.',
    tipAr: 'أيام أكل وشرب وذكر لله.',
    tipEn: 'Days of eating, drinking and remembering Allah.',
  ),
  whiteDays(
    month: 0,
    day: 13,
    days: 3,
    kind: IslamicEventKind.fasting,
    nameAr: 'الأيام البيض',
    nameEn: 'The White Days',
    descriptionAr:
        'كان النبي ﷺ يوصي بصيام ثلاثة أيام من كل شهر، وهي الثالث عشر والرابع عشر والخامس عشر من الشهر الهجري.',
    descriptionEn:
        'The Prophet ﷺ advised fasting three days every month: the 13th, 14th and 15th of the Hijri month.',
    tipAr: 'يُستحب صيام الثالث عشر والرابع عشر والخامس عشر.',
    tipEn: 'Fasting the 13th, 14th and 15th is recommended.',
  );

  const IslamicEvent({
    required this.month,
    required this.day,
    this.days = 1,
    required this.kind,
    required this.nameAr,
    required this.nameEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.tipAr,
    required this.tipEn,
    this.remindByDefault = false,
    this.bySighting = false,
  });

  /// 1–12, or 0 for every month ([whiteDays]).
  final int month;
  final int day;

  /// How many days it lasts, from [day].
  final int days;
  final IslamicEventKind kind;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;

  /// One line for the reminder notification.
  final String tipAr;
  final String tipEn;
  final bool remindByDefault;

  /// Its month starts with the sighting of the new moon, so the day may
  /// move from the calendar's; the reminder says so.
  final bool bySighting;

  bool get monthly => month == 0;

  /// Begins at nightfall, the evening before its first day.
  bool get startsAtNight =>
      kind == IslamicEventKind.night || this == lastTenNights;

  /// Reminded the evening before whatever the chosen time: nights, and
  /// Ramadan, whose first Tarawih is that evening.
  bool get eveningOnly => startsAtNight || this == ramadan;

  String label({required bool arabic}) => arabic ? nameAr : nameEn;
  String description({required bool arabic}) =>
      arabic ? descriptionAr : descriptionEn;
  String tip({required bool arabic}) => arabic ? tipAr : tipEn;

  /// Whether it falls in [month] at all; the white days skip Dhu al-Hijjah,
  /// where the 13th is a day of Tashreeq, on which fasting is forbidden.
  bool inMonth(int month) => monthly ? month != 12 : this.month == month;

  /// Whether [d] is one of its days.
  bool covers(HijriDay d) =>
      inMonth(d.month) && d.day >= day && d.day < day + days;

  static Set<IslamicEvent> get defaultReminders =>
      {for (final e in values) if (e.remindByDefault) e};

  static IslamicEvent? byName(String name) {
    for (final e in values) {
      if (e.name == name) return e;
    }
    return null;
  }
}

/// One dated occurrence of an [IslamicEvent].
class EventOccurrence {
  const EventOccurrence({
    required this.event,
    required this.hijri,
    required this.date,
  });

  final IslamicEvent event;

  /// Its first day.
  final HijriDay hijri;

  /// [hijri] in the Gregorian calendar, at midnight.
  final DateTime date;

  /// Its last day, in the Gregorian calendar.
  DateTime get lastDate => date.add(Duration(days: event.days - 1));
}

/// Dates the occasions with a [HijriConverter].
class IslamicEventCalendar {
  const IslamicEventCalendar(this.converter);

  final HijriConverter converter;

  /// The occasions covering [day].
  List<IslamicEvent> on(HijriDay day) => [
        for (final e in IslamicEvent.values)
          if (e.covers(day)) e,
      ];

  /// Occurrences whose first day is from [from] (a date) to [to],
  /// earliest first. Occasions already under way on [from] are included
  /// when [ongoing] is set.
  List<EventOccurrence> between(
    DateTime from,
    DateTime to, {
    bool ongoing = false,
  }) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    final result = <EventOccurrence>[];
    var month = () {
      final h = converter.fromGregorian(start);
      return HijriMonth(h.year, h.month).previous;
    }();
    while (true) {
      if (!converter.inRange(month)) {
        if (month.year > HijriConverter.maxYear) break;
        month = month.next;
        continue;
      }
      final first =
          converter.toGregorian(HijriDay(month.year, month.month, 1));
      if (first.isAfter(end)) break;
      for (final e in IslamicEvent.values) {
        if (!e.inMonth(month.month)) continue;
        final h = HijriDay(month.year, month.month, e.day);
        final date = converter.toGregorian(h);
        final o = EventOccurrence(event: e, hijri: h, date: date);
        final starts = !date.isBefore(start) && !date.isAfter(end);
        final under = ongoing &&
            date.isBefore(start) &&
            !o.lastDate.isBefore(start);
        if (starts || under) result.add(o);
      }
      month = month.next;
    }
    result.sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.event.index.compareTo(b.event.index);
    });
    return result;
  }
}
