import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/hijri_date.dart';
import '../../domain/islamic_events.dart';

const _monthsAr = [
  'محرّم',
  'صفر',
  'ربيع الأول',
  'ربيع الآخر',
  'جمادى الأولى',
  'جمادى الآخرة',
  'رجب',
  'شعبان',
  'رمضان',
  'شوّال',
  'ذو القعدة',
  'ذو الحجة',
];

const _monthsEn = [
  'Muharram',
  'Safar',
  "Rabi' al-Awwal",
  "Rabi' al-Thani",
  'Jumada al-Ula',
  'Jumada al-Akhirah',
  'Rajab',
  "Sha'ban",
  'Ramadan',
  'Shawwal',
  "Dhu al-Qa'dah",
  'Dhu al-Hijjah',
];

// The Gregorian months as the rest of the app names them (Maghrebi Arabic).
const _gregorianAr = [
  'جانفي',
  'فيفري',
  'مارس',
  'أفريل',
  'ماي',
  'جوان',
  'جويلية',
  'أوت',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

const _gregorianEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The Gregorian months a Hijri month spans: "نوفمبر – ديسمبر 2026",
/// "ديسمبر 2026 – جانفي 2027".
String gregorianSpan(BuildContext context, DateTime start, DateTime end) {
  final names = context.isArabic ? _gregorianAr : _gregorianEn;
  String year(DateTime d) => context.isArabic ? ltr('${d.year}') : '${d.year}';
  final a = names[start.month - 1];
  final b = names[end.month - 1];
  if (start.month == end.month) return '$a ${year(end)}';
  if (start.year == end.year) return '$a – $b ${year(end)}';
  return '$a ${year(start)} – $b ${year(end)}';
}

String hijriMonthName(BuildContext context, int month) =>
    context.isArabic ? _monthsAr[month - 1] : _monthsEn[month - 1];

/// "جمادى الآخرة 1448 هـ" / "Jumada al-Akhirah 1448 AH".
String formatHijriMonth(BuildContext context, HijriMonth m) => context.isArabic
    ? '${hijriMonthName(context, m.month)} ${ltr('${m.year}')} هـ'
    : '${hijriMonthName(context, m.month)} ${m.year} AH';

/// "3 جمادى الآخرة 1448 هـ" / "3 Jumada al-Akhirah 1448 AH".
String formatHijri(BuildContext context, HijriDay d) => context.isArabic
    ? '${ltr('${d.day}')} ${hijriMonthName(context, d.month)} ${ltr('${d.year}')} هـ'
    : '${d.day} ${hijriMonthName(context, d.month)} ${d.year} AH';

/// "3 جمادى الآخرة" / "3 Jumada al-Akhirah", without the year.
String formatHijriShort(BuildContext context, HijriDay d) => context.isArabic
    ? '${ltr('${d.day}')} ${hijriMonthName(context, d.month)}'
    : '${d.day} ${hijriMonthName(context, d.month)}';

/// "اليوم", "غدًا", "بعد يومين", "بعد 5 أيام", "بعد 40 يومًا".
String daysUntil(BuildContext context, int days) {
  if (!context.isArabic) {
    return switch (days) {
      <= 0 => 'Today',
      1 => 'Tomorrow',
      _ => 'In $days days',
    };
  }
  final tens = days % 100;
  return switch (days) {
    <= 0 => 'اليوم',
    1 => 'غدًا',
    2 => 'بعد يومين',
    _ when tens >= 3 && tens <= 10 => 'بعد ${ltr('$days')} أيام',
    _ => 'بعد ${ltr('$days')} يومًا',
  };
}

/// Whole days from [from] to [to], ignoring the time of day.
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

Color eventColor(IslamicEventKind kind) => switch (kind) {
      IslamicEventKind.eid => AppColors.gold,
      IslamicEventKind.fasting => AppColors.tileGreen,
      IslamicEventKind.night => AppColors.tileIndigo,
      IslamicEventKind.season => AppColors.tileOrange,
      IslamicEventKind.remembrance => AppColors.tileTeal,
    };

IconData eventIcon(IslamicEventKind kind) => switch (kind) {
      IslamicEventKind.eid => CupertinoIcons.sparkles,
      IslamicEventKind.fasting => CupertinoIcons.sun_haze_fill,
      IslamicEventKind.night => CupertinoIcons.moon_stars_fill,
      IslamicEventKind.season => CupertinoIcons.star_fill,
      IslamicEventKind.remembrance => CupertinoIcons.moon_fill,
    };

String eventKindLabel(BuildContext context, IslamicEventKind kind) =>
    switch (kind) {
      IslamicEventKind.eid => context.tr('عيد', 'Eid'),
      IslamicEventKind.fasting => context.tr('صيام مستحب', 'Recommended fast'),
      IslamicEventKind.night => context.tr('ليلة فاضلة', 'Blessed night'),
      IslamicEventKind.season => context.tr('موسم عبادة', 'Season of worship'),
      IslamicEventKind.remembrance => context.tr('ذكرى', 'Remembrance'),
    };
