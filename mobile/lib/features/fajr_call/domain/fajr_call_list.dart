import 'fajr_contact.dart';

/// When a list fires: at a fixed clock time, or at Fajr (plus an offset).
enum FajrStartMode {
  fajr,
  fixed;

  static FajrStartMode parse(Object? value) =>
      value == fixed.name ? fixed : fajr;
}

/// `auto`: Android places the calls itself. `manual`: a notification opens
/// the wake list and the user calls each person with one tap (the only mode
/// on iOS, and the fallback when call permissions are denied).
enum FajrCallMode {
  auto,
  manual;

  static FajrCallMode parse(Object? value) =>
      value == manual.name ? manual : auto;
}

/// A clock time without a date.
class TimeOfDayHm {
  const TimeOfDayHm(this.hour, this.minute);

  final int hour;
  final int minute;

  /// Parses `hh:mm`; falls back to 04:30 for anything malformed.
  factory TimeOfDayHm.parse(Object? value) {
    if (value is String) {
      final parts = value.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
          return TimeOfDayHm(h, m);
        }
      }
    }
    return const TimeOfDayHm(4, 30);
  }

  String format() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is TimeOfDayHm && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => format();
}

/// One list of people to wake for Fajr, with its schedule and call settings.
class FajrCallList {
  const FajrCallList({
    required this.id,
    required this.name,
    this.enabled = false,
    this.startMode = FajrStartMode.fajr,
    this.fixedTime = const TimeOfDayHm(4, 30),
    this.fajrOffsetMinutes = 0,
    this.repeatDaily = true,
    this.weekdays = const {},
    this.contacts = const [],
    this.autoHangUp = true,
    this.ringTimeoutSec = defaultRingTimeoutSec,
    this.waitAfterAnswerSec = defaultWaitAfterAnswerSec,
    this.gapBetweenSec = defaultGapBetweenSec,
    this.stopAfterFirstAnswer = false,
    this.retryOnNoAnswer = true,
    this.maxRetries = 1,
    this.repeatWholeLoop = false,
    this.loopRepeats = 1,
    this.mode = FajrCallMode.auto,
    this.phoneAccountId,
    this.armedAt,
  });

  static const int defaultRingTimeoutSec = 20;
  static const int defaultWaitAfterAnswerSec = 30;
  static const int defaultGapBetweenSec = 3;

  static const int minRingTimeoutSec = 10;
  static const int maxRingTimeoutSec = 180;
  static const int maxWaitAfterAnswerSec = 120;
  static const int maxGapBetweenSec = 30;
  static const int minFajrOffset = -30;
  static const int maxFajrOffset = 60;
  static const int maxRetriesLimit = 3;
  static const int maxLoopRepeats = 3;

  final String id;
  final String name;
  final bool enabled;
  final FajrStartMode startMode;
  final TimeOfDayHm fixedTime;

  /// Minutes added to Fajr; negative means before the adhan.
  final int fajrOffsetMinutes;

  /// When false the list fires once, at its next occurrence.
  final bool repeatDaily;

  /// `DateTime.monday` … `DateTime.sunday`. Empty means every day.
  final Set<int> weekdays;

  final List<FajrContact> contacts;

  /// When true the app ends each call [ringTimeoutSec] after dialling,
  /// answered or not (Android can't see the answer). When false the call
  /// runs until the other side or the network ends it.
  final bool autoHangUp;

  /// How long a call lasts before the app ends it, counted from dialling.
  final int ringTimeoutSec;
  final int waitAfterAnswerSec;
  final int gapBetweenSec;
  final bool stopAfterFirstAnswer;
  final bool retryOnNoAnswer;
  final int maxRetries;
  final bool repeatWholeLoop;

  /// Extra passes over the whole list when [repeatWholeLoop] is on.
  final int loopRepeats;

  final FajrCallMode mode;

  /// Android `PhoneAccountHandle` id of the SIM to call from; null uses the
  /// phone's default.
  final String? phoneAccountId;

  /// When a one-off list (`repeatDaily == false`) was switched on: it fires
  /// at its first occurrence after this moment, then turns itself off.
  final DateTime? armedAt;

  bool runsOn(int weekday) => weekdays.isEmpty || weekdays.contains(weekday);

  FajrCallList copyWith({
    String? name,
    bool? enabled,
    FajrStartMode? startMode,
    TimeOfDayHm? fixedTime,
    int? fajrOffsetMinutes,
    bool? repeatDaily,
    Set<int>? weekdays,
    List<FajrContact>? contacts,
    bool? autoHangUp,
    int? ringTimeoutSec,
    int? waitAfterAnswerSec,
    int? gapBetweenSec,
    bool? stopAfterFirstAnswer,
    bool? retryOnNoAnswer,
    int? maxRetries,
    bool? repeatWholeLoop,
    int? loopRepeats,
    FajrCallMode? mode,
    String? phoneAccountId,
    bool clearPhoneAccount = false,
    DateTime? armedAt,
  }) =>
      FajrCallList(
        id: id,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        startMode: startMode ?? this.startMode,
        fixedTime: fixedTime ?? this.fixedTime,
        fajrOffsetMinutes: fajrOffsetMinutes ?? this.fajrOffsetMinutes,
        repeatDaily: repeatDaily ?? this.repeatDaily,
        weekdays: weekdays ?? this.weekdays,
        contacts: contacts ?? this.contacts,
        autoHangUp: autoHangUp ?? this.autoHangUp,
        ringTimeoutSec: ringTimeoutSec ?? this.ringTimeoutSec,
        waitAfterAnswerSec: waitAfterAnswerSec ?? this.waitAfterAnswerSec,
        gapBetweenSec: gapBetweenSec ?? this.gapBetweenSec,
        stopAfterFirstAnswer: stopAfterFirstAnswer ?? this.stopAfterFirstAnswer,
        retryOnNoAnswer: retryOnNoAnswer ?? this.retryOnNoAnswer,
        maxRetries: maxRetries ?? this.maxRetries,
        repeatWholeLoop: repeatWholeLoop ?? this.repeatWholeLoop,
        loopRepeats: loopRepeats ?? this.loopRepeats,
        mode: mode ?? this.mode,
        phoneAccountId:
            clearPhoneAccount ? null : (phoneAccountId ?? this.phoneAccountId),
        armedAt: armedAt ?? this.armedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'startMode': startMode.name,
        'fixedTime': fixedTime.format(),
        'fajrOffsetMinutes': fajrOffsetMinutes,
        'repeatDaily': repeatDaily,
        'weekdays': (weekdays.toList()..sort()),
        'contacts': [for (final c in contacts) c.toJson()],
        'autoHangUp': autoHangUp,
        'ringTimeoutSec': ringTimeoutSec,
        'waitAfterAnswerSec': waitAfterAnswerSec,
        'gapBetweenSec': gapBetweenSec,
        'stopAfterFirstAnswer': stopAfterFirstAnswer,
        'retryOnNoAnswer': retryOnNoAnswer,
        'maxRetries': maxRetries,
        'repeatWholeLoop': repeatWholeLoop,
        'loopRepeats': loopRepeats,
        'mode': mode.name,
        if (phoneAccountId != null) 'phoneAccountId': phoneAccountId,
        if (armedAt != null) 'armedAt': armedAt!.millisecondsSinceEpoch,
      };

  /// Tolerant of missing or out-of-range fields, so older saved lists and
  /// hand-edited data never crash the app; values are clamped to the ranges
  /// the editor allows.
  factory FajrCallList.fromJson(Map<String, dynamic> json) {
    int intOf(String key, int fallback, int min, int max) {
      final v = json[key];
      return (v is num ? v.toInt() : fallback).clamp(min, max);
    }

    bool boolOf(String key, bool fallback) {
      final v = json[key];
      return v is bool ? v : fallback;
    }

    final rawDays = json['weekdays'];
    final armed = json['armedAt'];
    final rawContacts = json['contacts'];
    return FajrCallList(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      enabled: boolOf('enabled', false),
      startMode: FajrStartMode.parse(json['startMode']),
      fixedTime: TimeOfDayHm.parse(json['fixedTime']),
      fajrOffsetMinutes:
          intOf('fajrOffsetMinutes', 0, minFajrOffset, maxFajrOffset),
      repeatDaily: boolOf('repeatDaily', true),
      weekdays: {
        if (rawDays is List)
          for (final d in rawDays)
            if (d is int && d >= DateTime.monday && d <= DateTime.sunday) d,
      },
      contacts: [
        if (rawContacts is List)
          for (final c in rawContacts)
            if (c is Map) FajrContact.fromJson(Map<String, dynamic>.from(c)),
      ],
      autoHangUp: boolOf('autoHangUp', true),
      ringTimeoutSec: intOf('ringTimeoutSec', defaultRingTimeoutSec,
          minRingTimeoutSec, maxRingTimeoutSec),
      waitAfterAnswerSec: intOf('waitAfterAnswerSec', defaultWaitAfterAnswerSec,
          0, maxWaitAfterAnswerSec),
      gapBetweenSec:
          intOf('gapBetweenSec', defaultGapBetweenSec, 0, maxGapBetweenSec),
      stopAfterFirstAnswer: boolOf('stopAfterFirstAnswer', false),
      retryOnNoAnswer: boolOf('retryOnNoAnswer', true),
      maxRetries: intOf('maxRetries', 1, 1, maxRetriesLimit),
      repeatWholeLoop: boolOf('repeatWholeLoop', false),
      loopRepeats: intOf('loopRepeats', 1, 1, maxLoopRepeats),
      mode: FajrCallMode.parse(json['mode']),
      phoneAccountId: json['phoneAccountId'] as String?,
      armedAt: armed is num
          ? DateTime.fromMillisecondsSinceEpoch(armed.toInt())
          : null,
    );
  }

  // Value equality through the canonical JSON (weekdays sorted), so the
  // editor can tell whether anything changed.
  @override
  bool operator ==(Object other) =>
      other is FajrCallList && other.toJson().toString() == toJson().toString();

  @override
  int get hashCode => toJson().toString().hashCode;
}
