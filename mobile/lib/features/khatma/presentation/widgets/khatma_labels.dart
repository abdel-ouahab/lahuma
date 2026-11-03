import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../fajr_call/presentation/widgets/fajr_call_labels.dart';
import '../../domain/khatma.dart';
import '../../domain/khatma_planner.dart';
import '../../domain/khatma_text.dart';
import '../../domain/quran_pages.dart';

/// "20 صفحة" / "20 pages".
String pagesLabel(BuildContext context, int n) =>
    KhatmaText.pages(n, arabic: context.isArabic);

String daysLabel(BuildContext context, int n) =>
    KhatmaText.days(n, arabic: context.isArabic);

/// [pages] in the khatma's display unit: "جزء واحد", "1½ juz", "20 صفحة".
String amountLabel(BuildContext context, int pages, ReadingUnit unit) =>
    KhatmaText.amount(pages, unit, arabic: context.isArabic);

/// "20 صفحة (جزء واحد)" for juz' / hizb units, just pages otherwise.
String amountWithPages(BuildContext context, int pages, ReadingUnit unit) {
  final p = pagesLabel(context, pages);
  return unit == ReadingUnit.pages
      ? p
      : '$p (${amountLabel(context, pages, unit)})';
}

/// "صفحة 142 (الأنعام)".
String pageLabel(BuildContext context, int page) =>
    KhatmaText.page(page, arabic: context.isArabic);

/// "صفحة 142 · الأنعام · الجزء 8".
String pagePlace(BuildContext context, int page) {
  final p = page.clamp(1, QuranPages.total);
  final surah = QuranPages.surahName(p, arabic: context.isArabic);
  final juz = QuranPages.juzAt(p);
  return context.tr(
      'صفحة $p · $surah · الجزء $juz', 'Page $p · $surah · Juz $juz');
}

String unitName(BuildContext context, ReadingUnit unit) => switch (unit) {
      ReadingUnit.pages => context.tr('صفحات', 'Pages'),
      ReadingUnit.juz => context.tr('أجزاء', 'Juz'),
      ReadingUnit.hizb => context.tr('أحزاب', 'Hizb'),
    };

/// "7:00 ص" for minutes after midnight.
String minutesLabel(BuildContext context, int minutes) =>
    formatClock(context, DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60));

String dateLabel(BuildContext context, DateTime day) =>
    formatDate(context, day);

String dayLabel(BuildContext context, DateTime day, DateTime today) =>
    relativeDay(context, day, today);

String paceLabel(BuildContext context, KhatmaPace pace) => switch (pace) {
      KhatmaPace.onTrack => context.tr('على المسار', 'On track'),
      KhatmaPace.behind => context.tr('متأخر عن الخطة', 'Behind plan'),
      KhatmaPace.ahead => context.tr('متقدّم على الخطة', 'Ahead of plan'),
      KhatmaPace.overdue => context.tr('انتهت المدة', 'Past the end date'),
    };

Color paceColor(BuildContext context, KhatmaPace pace) {
  final c = context.palette;
  return switch (pace) {
    KhatmaPace.onTrack => c.success,
    KhatmaPace.ahead => c.accent,
    KhatmaPace.behind => c.warning,
    KhatmaPace.overdue => c.destructive,
  };
}

/// "12.5 صفحة/يوم": an average, to one decimal.
String perDayLabel(BuildContext context, double pages) {
  final rounded = (pages * 10).round() / 10;
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
  return context.tr('${ltr(text)} صفحة/يوم', '$text pages/day');
}
