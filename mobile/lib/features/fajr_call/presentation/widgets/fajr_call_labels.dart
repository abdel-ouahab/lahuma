import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/call_attempt.dart';
import '../../domain/fajr_call_list.dart';
import '../../domain/fajr_contact.dart';

/// Clock time: "4:36 ص" / "4:36 AM". Digits stay LTR inside Arabic text.
String formatClock(BuildContext context, DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final hm = '$h:${t.minute.toString().padLeft(2, '0')}';
  return context.isArabic
      ? '${ltr(hm)} ${t.hour < 12 ? 'ص' : 'م'}'
      : '$hm ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "اليوم" / "غدًا" / the weekday, relative to [now].
String relativeDay(BuildContext context, DateTime t, DateTime now) {
  final day = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return context.tr('اليوم', 'Today');
  if (diff == 1) return context.tr('غدًا', 'Tomorrow');
  if (diff == -1) return context.tr('أمس', 'Yesterday');
  if (diff > 1 && diff < 7) return weekdayName(context, t.weekday);
  return formatDate(context, t);
}

String formatDate(BuildContext context, DateTime t) => context.isArabic
    ? '${ltr('${t.day}')} ${_monthsAr[t.month - 1]} ${ltr('${t.year}')}'
    : '${t.day} ${_monthsEn[t.month - 1]} ${t.year}';

/// "غدًا 4:36 ص".
String formatFire(BuildContext context, DateTime t, DateTime now) =>
    '${relativeDay(context, t, now)} ${formatClock(context, t)}';

String weekdayName(BuildContext context, int weekday) =>
    context.isArabic ? _weekdaysAr[weekday - 1] : _weekdaysEn[weekday - 1];

String weekdayShort(BuildContext context, int weekday) => context.isArabic
    ? _weekdaysAr[weekday - 1].replaceFirst('ال', '')
    : _weekdaysEn[weekday - 1].substring(0, 3);

/// Week order for the weekday chips: Saturday first in Arabic, as on
/// calendars in Algeria and the Gulf; Monday first in English.
List<int> weekOrder(BuildContext context) => context.isArabic
    ? const [6, 7, 1, 2, 3, 4, 5]
    : const [1, 2, 3, 4, 5, 6, 7];

String seconds(BuildContext context, int s) =>
    context.tr('${ltr('$s')} ث', '$s s');

String minutesOffset(BuildContext context, int m) {
  if (m == 0) return context.tr('عند الأذان', 'At the adhan');
  final n = m.abs();
  return m > 0
      ? context.tr('بعد ${ltr('$n')} د', '$n min after')
      : context.tr('قبل ${ltr('$n')} د', '$n min before');
}

String peopleCount(BuildContext context, int n) => context.isArabic
    ? switch (n) {
        0 => 'لا أحد بعد',
        1 => 'شخص واحد',
        2 => 'شخصان',
        < 11 => '${ltr('$n')} أشخاص',
        _ => '${ltr('$n')} شخصًا',
      }
    : n == 1
        ? '1 person'
        : '$n people';

String relationLabel(BuildContext context, ContactRelation? r) => switch (r) {
      ContactRelation.father => context.tr('الأب', 'Father'),
      ContactRelation.mother => context.tr('الأم', 'Mother'),
      ContactRelation.sibling => context.tr('أخ / أخت', 'Sibling'),
      ContactRelation.spouse => context.tr('الزوج / الزوجة', 'Spouse'),
      ContactRelation.child => context.tr('ابن / ابنة', 'Child'),
      ContactRelation.friend => context.tr('صديق', 'Friend'),
      ContactRelation.other || null => context.tr('آخر', 'Other'),
    };

IconData relationIcon(ContactRelation? r) => switch (r) {
      ContactRelation.father ||
      ContactRelation.mother =>
        CupertinoIcons.heart_fill,
      ContactRelation.sibling => CupertinoIcons.person_2_fill,
      ContactRelation.spouse => CupertinoIcons.person_crop_circle_fill,
      ContactRelation.child => CupertinoIcons.smiley_fill,
      ContactRelation.friend => CupertinoIcons.hand_raised_fill,
      ContactRelation.other || null => CupertinoIcons.person_fill,
    };

Color relationColor(ContactRelation? r) => switch (r) {
      ContactRelation.father || ContactRelation.mother => AppColors.tilePink,
      ContactRelation.sibling => AppColors.tilePurple,
      ContactRelation.spouse => AppColors.tileRed,
      ContactRelation.child => AppColors.tileOrange,
      ContactRelation.friend => AppColors.tileBlue,
      ContactRelation.other || null => AppColors.tileIndigo,
    };

String statusLabel(BuildContext context, CallStatus s) => switch (s) {
      CallStatus.answered => context.tr('ردّ', 'Answered'),
      CallStatus.noAnswer => context.tr('لم يردّ', 'No answer'),
      CallStatus.failed => context.tr('تعذّر الاتصال', 'Failed'),
      CallStatus.called => context.tr('انتهت المكالمة', 'Call ended'),
      CallStatus.markedAwake => context.tr('استيقظ', 'Awake'),
    };

IconData statusIcon(CallStatus s) => switch (s) {
      CallStatus.answered => CupertinoIcons.phone_fill_arrow_up_right,
      CallStatus.noAnswer => CupertinoIcons.phone_down_fill,
      CallStatus.failed => CupertinoIcons.exclamationmark_circle_fill,
      CallStatus.called => CupertinoIcons.phone_fill,
      CallStatus.markedAwake => CupertinoIcons.checkmark_circle_fill,
    };

Color statusColor(CallStatus s) => switch (s) {
      CallStatus.answered || CallStatus.markedAwake => AppColors.success,
      CallStatus.noAnswer => AppColors.warning,
      CallStatus.failed => AppColors.destructive,
      CallStatus.called => AppColors.tileBlue,
    };

String modeLabel(BuildContext context, FajrCallMode m) => switch (m) {
      FajrCallMode.auto => context.tr('اتصال تلقائي', 'Automatic calls'),
      FajrCallMode.manual => context.tr('تنبيه وقائمة', 'Reminder & list'),
    };

const _weekdaysAr = [
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];
const _weekdaysEn = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _monthsAr = [
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
const _monthsEn = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
