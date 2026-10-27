import 'call_attempt.dart';
import 'fajr_call_list.dart';
import 'fajr_contact.dart';

/// One run of a list: every call placed (auto mode) and every tick made on
/// the wake list (manual mode) after it fired.
class CallSession {
  const CallSession({
    required this.id,
    required this.listId,
    required this.listName,
    required this.firedAt,
    this.mode = FajrCallMode.auto,
    this.attempts = const [],
    this.stoppedByUser = false,
  });

  final String id;
  final String listId;

  /// The list's name when it fired, in case it is renamed or deleted later.
  final String listName;
  final DateTime firedAt;
  final FajrCallMode mode;
  final List<CallAttempt> attempts;

  /// The user tapped Stop on the ongoing notification.
  final bool stoppedByUser;

  Iterable<CallAttempt> get _calls => attempts.where((a) => a.status.isCall);

  /// Calls placed (ticks are not counted).
  int get total => _calls.length;
  int get answered => _count(CallStatus.answered);
  int get noAnswer => _count(CallStatus.noAnswer);
  int get failed => _count(CallStatus.failed);

  /// Calls that ended before the ring timeout (see [CallStatus.called]).
  int get ended => _count(CallStatus.called);

  /// Ids of the people known to be awake: the call log shows they answered,
  /// or the user ticked them.
  Set<String> get awakeContactIds => {
        for (final a in attempts)
          if (a.status == CallStatus.answered ||
              a.status == CallStatus.markedAwake)
            a.contact.id,
      };

  int get awake => awakeContactIds.length;

  /// Everyone who appears in this session, in first-call order.
  List<FajrContact> get contacts {
    final seen = <String>{};
    return [
      for (final a in attempts)
        if (seen.add(a.contact.id)) a.contact,
    ];
  }

  int _count(CallStatus status) =>
      attempts.where((a) => a.status == status).length;

  /// Adds the user's "woke up ✓" tick for [contact], or removes it when
  /// [awake] is false. Ticking twice keeps one tick.
  CallSession markAwake(FajrContact contact, DateTime at, {bool awake = true}) {
    final rest = [
      for (final a in attempts)
        if (!(a.status == CallStatus.markedAwake && a.contact.id == contact.id))
          a,
    ];
    return copyWith(attempts: [
      ...rest,
      if (awake)
        CallAttempt(
          contact: contact,
          startedAt: at,
          endedAt: at,
          status: CallStatus.markedAwake,
        ),
    ]);
  }

  CallSession copyWith({
    List<CallAttempt>? attempts,
    bool? stoppedByUser,
  }) =>
      CallSession(
        id: id,
        listId: listId,
        listName: listName,
        firedAt: firedAt,
        mode: mode,
        attempts: attempts ?? this.attempts,
        stoppedByUser: stoppedByUser ?? this.stoppedByUser,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'listId': listId,
        'listName': listName,
        'firedAt': firedAt.millisecondsSinceEpoch,
        'mode': mode.name,
        'attempts': [for (final a in attempts) a.toJson()],
        if (stoppedByUser) 'stoppedByUser': true,
      };

  factory CallSession.fromJson(Map<String, dynamic> json) {
    final fired = json['firedAt'];
    final raw = json['attempts'];
    return CallSession(
      id: json['id'] as String? ?? '',
      listId: json['listId'] as String? ?? '',
      listName: json['listName'] as String? ?? '',
      firedAt:
          DateTime.fromMillisecondsSinceEpoch(fired is num ? fired.toInt() : 0),
      mode: FajrCallMode.parse(json['mode']),
      attempts: [
        if (raw is List)
          for (final a in raw)
            if (a is Map) CallAttempt.fromJson(Map<String, dynamic>.from(a)),
      ],
      stoppedByUser: json['stoppedByUser'] == true,
    );
  }
}
