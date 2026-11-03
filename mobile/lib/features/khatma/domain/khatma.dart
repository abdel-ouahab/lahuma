/// A plan to read the whole Quran by an end date, measured in Madinah
/// Mushaf pages (604).
///
/// Local-first: everything is JSON in SharedPreferences, keyed by string
/// ids and calendar dates (`yyyy-MM-dd`), so it can sync later without a
/// migration.
library;

enum KhatmaStatus { active, paused, completed }

/// What the plan is shown in. Progress is always kept in pages.
enum ReadingUnit { pages, juz, hizb }

/// The reading set for one day, fixed when the day starts so the goal does
/// not move while the reader reads.
class DayPlan {
  const DayPlan({
    required this.date,
    required this.startPage,
    required this.targetPage,
  });

  final DateTime date;

  /// Last page read when the day began; today's portion starts on the next.
  final int startPage;

  /// The page to reach today.
  final int targetPage;

  int get fromPage => startPage + 1;
  int get pages => targetPage - startPage;

  Map<String, Object?> toJson() => {
        'date': dateKey(date),
        'startPage': startPage,
        'targetPage': targetPage,
      };

  static DayPlan? fromJson(Object? json) {
    if (json is! Map) return null;
    final date = parseDate(json['date']);
    if (date == null) return null;
    return DayPlan(
      date: date,
      startPage: (json['startPage'] as num?)?.toInt() ?? 0,
      targetPage: (json['targetPage'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Pages read on one day of a khatma ([fromPage]–[toPage], inclusive).
class DailyLog {
  const DailyLog({
    required this.khatmaId,
    required this.date,
    required this.fromPage,
    required this.toPage,
  });

  final String khatmaId;
  final DateTime date;
  final int fromPage;
  final int toPage;

  int get pages => toPage - fromPage + 1;

  DailyLog copyWith({int? fromPage, int? toPage}) => DailyLog(
        khatmaId: khatmaId,
        date: date,
        fromPage: fromPage ?? this.fromPage,
        toPage: toPage ?? this.toPage,
      );

  Map<String, Object?> toJson() => {
        'khatmaId': khatmaId,
        'date': dateKey(date),
        'fromPage': fromPage,
        'toPage': toPage,
      };

  static DailyLog? fromJson(Object? json) {
    if (json is! Map) return null;
    final date = parseDate(json['date']);
    final id = json['khatmaId'];
    if (date == null || id is! String) return null;
    return DailyLog(
      khatmaId: id,
      date: date,
      fromPage: (json['fromPage'] as num?)?.toInt() ?? 1,
      toPage: (json['toPage'] as num?)?.toInt() ?? 0,
    );
  }
}

const Object _unset = Object();

class Khatma {
  const Khatma({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.startPage,
    required this.lastPageRead,
    required this.planFrom,
    required this.planFromPage,
    this.displayUnit = ReadingUnit.pages,
    this.morningEnabled = true,
    this.morningMinutes = defaultMorningMinutes,
    this.eveningEnabled = false,
    this.eveningMinutes = defaultEveningMinutes,
    this.status = KhatmaStatus.active,
    this.completedAt,
    this.pausedOn,
    this.today,
    this.overdueKept = false,
  });

  static const int defaultMorningMinutes = 7 * 60;
  static const int defaultEveningMinutes = 21 * 60;

  final String id;
  final DateTime startDate;

  /// The last day of reading (inclusive).
  final DateTime endDate;

  /// The first page of this khatma (1, or later for a reader partway
  /// through).
  final int startPage;

  /// 0 … 604. `startPage - 1` before anything is read.
  final int lastPageRead;

  /// Where the current pace line starts: the creation day, or the day the
  /// plan was last edited or resumed, with the last page read when that
  /// day began. "On track / behind / ahead" is measured against it.
  final DateTime planFrom;
  final int planFromPage;

  final ReadingUnit displayUnit;

  /// Reminder times, in minutes after midnight (local time).
  final bool morningEnabled;
  final int morningMinutes;
  final bool eveningEnabled;
  final int eveningMinutes;

  final KhatmaStatus status;
  final DateTime? completedAt;

  /// The day the khatma was paused; the end date moves on by the days it
  /// stays paused.
  final DateTime? pausedOn;

  /// Today's portion, fixed when the day began. Null until first planned.
  final DayPlan? today;

  /// The reader chose to carry on past the end date without extending it.
  final bool overdueKept;

  int get pagesToRead => 604 - startPage + 1;
  int get pagesRead => lastPageRead - (startPage - 1);
  bool get finished => lastPageRead >= 604;

  Khatma copyWith({
    DateTime? endDate,
    int? lastPageRead,
    DateTime? planFrom,
    int? planFromPage,
    ReadingUnit? displayUnit,
    bool? morningEnabled,
    int? morningMinutes,
    bool? eveningEnabled,
    int? eveningMinutes,
    KhatmaStatus? status,
    Object? completedAt = _unset,
    Object? pausedOn = _unset,
    Object? today = _unset,
    bool? overdueKept,
  }) =>
      Khatma(
        id: id,
        startDate: startDate,
        endDate: endDate ?? this.endDate,
        startPage: startPage,
        lastPageRead: lastPageRead ?? this.lastPageRead,
        planFrom: planFrom ?? this.planFrom,
        planFromPage: planFromPage ?? this.planFromPage,
        displayUnit: displayUnit ?? this.displayUnit,
        morningEnabled: morningEnabled ?? this.morningEnabled,
        morningMinutes: morningMinutes ?? this.morningMinutes,
        eveningEnabled: eveningEnabled ?? this.eveningEnabled,
        eveningMinutes: eveningMinutes ?? this.eveningMinutes,
        status: status ?? this.status,
        completedAt: identical(completedAt, _unset)
            ? this.completedAt
            : completedAt as DateTime?,
        pausedOn:
            identical(pausedOn, _unset) ? this.pausedOn : pausedOn as DateTime?,
        today: identical(today, _unset) ? this.today : today as DayPlan?,
        overdueKept: overdueKept ?? this.overdueKept,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'startDate': dateKey(startDate),
        'endDate': dateKey(endDate),
        'startPage': startPage,
        'lastPageRead': lastPageRead,
        'planFrom': dateKey(planFrom),
        'planFromPage': planFromPage,
        'displayUnit': displayUnit.name,
        'morningEnabled': morningEnabled,
        'morningMinutes': morningMinutes,
        'eveningEnabled': eveningEnabled,
        'eveningMinutes': eveningMinutes,
        'status': status.name,
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (pausedOn != null) 'pausedOn': dateKey(pausedOn!),
        if (today != null) 'today': today!.toJson(),
        'overdueKept': overdueKept,
      };

  static Khatma? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final start = parseDate(json['startDate']);
    final end = parseDate(json['endDate']);
    if (id is! String || start == null || end == null) return null;
    final startPage = ((json['startPage'] as num?)?.toInt() ?? 1).clamp(1, 604);
    final last = ((json['lastPageRead'] as num?)?.toInt() ?? startPage - 1)
        .clamp(0, 604);
    return Khatma(
      id: id,
      startDate: start,
      endDate: end,
      startPage: startPage,
      lastPageRead: last,
      planFrom: parseDate(json['planFrom']) ?? start,
      planFromPage: (json['planFromPage'] as num?)?.toInt() ?? startPage - 1,
      displayUnit: ReadingUnit.values.firstWhere(
          (u) => u.name == json['displayUnit'],
          orElse: () => ReadingUnit.pages),
      morningEnabled: json['morningEnabled'] as bool? ?? true,
      morningMinutes: _minutes(json['morningMinutes'], defaultMorningMinutes),
      eveningEnabled: json['eveningEnabled'] as bool? ?? false,
      eveningMinutes: _minutes(json['eveningMinutes'], defaultEveningMinutes),
      status: KhatmaStatus.values.firstWhere((s) => s.name == json['status'],
          orElse: () => KhatmaStatus.active),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      pausedOn: parseDate(json['pausedOn']),
      today: DayPlan.fromJson(json['today']),
      overdueKept: json['overdueKept'] as bool? ?? false,
    );
  }

  static int _minutes(Object? value, int fallback) {
    final m = (value as num?)?.toInt();
    return m != null && m >= 0 && m < 24 * 60 ? m : fallback;
  }
}

/// `yyyy-MM-dd` of a local calendar day.
String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime? parseDate(Object? value) {
  if (value is! String) return null;
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// The local calendar day of [t] (midnight).
DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

/// Whole calendar days from [from] to [to]; counted on UTC dates so a
/// daylight-saving change never turns a day into 23 or 25 hours.
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

/// [day] moved by [days] calendar days (DST-safe).
DateTime addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);
