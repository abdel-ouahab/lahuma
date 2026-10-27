import 'fajr_contact.dart';

/// What happened to one call (or one tick on the wake list).
///
/// Without the call log Android cannot tell whether an outgoing call was
/// answered, so the Play build records:
/// - [called]: the call ended before the ring timeout (the person answered
///   or declined, or the network ended it);
/// - [noAnswer]: it rang for the whole timeout and the app hung up.
/// Builds with call-log access record [answered] instead when the call log
/// shows a duration. [markedAwake] is the user's own "woke up ✓" tick.
enum CallStatus {
  answered,
  noAnswer,
  failed,
  called,
  markedAwake;

  static CallStatus parse(Object? value) {
    for (final s in values) {
      if (s.name == value) return s;
    }
    return failed;
  }

  /// A real call was placed (a tick is not a call).
  bool get isCall => this != markedAwake;
}

class CallAttempt {
  const CallAttempt({
    required this.contact,
    required this.startedAt,
    this.endedAt,
    required this.status,
    this.attemptNo = 1,
  });

  /// A snapshot of the contact when the call was placed, so the log stays
  /// readable after the list is edited.
  final FajrContact contact;
  final DateTime startedAt;
  final DateTime? endedAt;
  final CallStatus status;

  /// 1 for the first call to this contact in a session, 2 for the first
  /// retry, and so on.
  final int attemptNo;

  Duration? get duration => endedAt?.difference(startedAt);

  Map<String, dynamic> toJson() => {
        'contact': contact.toJson(),
        'startedAt': startedAt.millisecondsSinceEpoch,
        if (endedAt != null) 'endedAt': endedAt!.millisecondsSinceEpoch,
        'status': status.name,
        'attemptNo': attemptNo,
      };

  factory CallAttempt.fromJson(Map<String, dynamic> json) {
    final contact = json['contact'];
    final started = json['startedAt'];
    final ended = json['endedAt'];
    final attemptNo = json['attemptNo'];
    return CallAttempt(
      contact: contact is Map
          ? FajrContact.fromJson(Map<String, dynamic>.from(contact))
          : const FajrContact(id: '', name: '', phone: ''),
      startedAt: DateTime.fromMillisecondsSinceEpoch(
          started is num ? started.toInt() : 0),
      endedAt: ended is num
          ? DateTime.fromMillisecondsSinceEpoch(ended.toInt())
          : null,
      status: CallStatus.parse(json['status']),
      attemptNo: attemptNo is num ? attemptNo.toInt() : 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CallAttempt &&
      other.contact == contact &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt &&
      other.status == status &&
      other.attemptNo == attemptNo;

  @override
  int get hashCode =>
      Object.hash(contact, startedAt, endedAt, status, attemptNo);
}
