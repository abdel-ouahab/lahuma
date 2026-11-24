import 'package:hijri/hijri_calendar.dart';

/// A day of the Hijri calendar.
class HijriDay implements Comparable<HijriDay> {
  const HijriDay(this.year, this.month, this.day);

  final int year;

  /// 1 (Muharram) … 12 (Dhu al-Hijjah).
  final int month;
  final int day;

  @override
  int compareTo(HijriDay other) => year != other.year
      ? year.compareTo(other.year)
      : month != other.month
          ? month.compareTo(other.month)
          : day.compareTo(other.day);

  @override
  bool operator ==(Object other) =>
      other is HijriDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '$year-$month-$day AH';
}

/// A Hijri month, for paging through the calendar.
class HijriMonth {
  const HijriMonth(this.year, this.month);

  final int year;
  final int month;

  HijriMonth get next =>
      month == 12 ? HijriMonth(year + 1, 1) : HijriMonth(year, month + 1);

  HijriMonth get previous =>
      month == 1 ? HijriMonth(year - 1, 12) : HijriMonth(year, month - 1);

  @override
  bool operator ==(Object other) =>
      other is HijriMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

/// Converts between Gregorian and Hijri dates with the Umm al-Qura tables,
/// shifted by [adjustment] days for where the month is sighted earlier or
/// later than in Makkah (−2 … +2).
///
/// +1 means the Hijri date here is one day ahead of Umm al-Qura.
class HijriConverter {
  const HijriConverter({this.adjustment = 0});

  final int adjustment;

  /// The span the Umm al-Qura tables cover, with a margin: 1357–1499 AH
  /// (1938–2076).
  static const int minYear = 1357;
  static const int maxYear = 1499;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  HijriDay fromGregorian(DateTime date) {
    final d = _dateOnly(date).add(Duration(days: adjustment));
    final h = HijriCalendar.fromDate(d);
    return HijriDay(h.hYear, h.hMonth, h.hDay);
  }

  DateTime toGregorian(HijriDay day) {
    final g = HijriCalendar().hijriToGregorian(day.year, day.month, day.day);
    return _dateOnly(g).subtract(Duration(days: adjustment));
  }

  /// 29 or 30.
  int monthLength(int year, int month) =>
      HijriCalendar().getDaysInMonth(year, month);

  bool inRange(HijriMonth m) => m.year >= minYear && m.year <= maxYear;
}
