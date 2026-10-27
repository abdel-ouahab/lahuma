import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/fajr_call/domain/call_attempt.dart';
import 'package:lahuma/features/fajr_call/domain/call_session.dart';
import 'package:lahuma/features/fajr_call/domain/fajr_call_list.dart';
import 'package:lahuma/features/fajr_call/domain/fajr_contact.dart';
import 'package:lahuma/features/fajr_call/domain/prayer_settings.dart';

const mother = FajrContact(
  id: 'c1',
  name: 'أمي',
  phone: '+213551234567',
  rawPhone: '0551 23 45 67',
  relation: ContactRelation.mother,
);
const friend = FajrContact(id: 'c2', name: 'Ali', phone: '+33612345678');

CallAttempt attempt(FajrContact c, CallStatus s, {int no = 1, int min = 0}) =>
    CallAttempt(
      contact: c,
      startedAt: DateTime(2026, 11, 15, 5, 56 + min),
      endedAt: DateTime(2026, 11, 15, 5, 56 + min, 20),
      status: s,
      attemptNo: no,
    );

void main() {
  group('normalizePhone', () {
    test('local number with a dial code becomes E.164', () {
      expect(normalizePhone('0551 23-45-67', dialCode: '213'), '+213551234567');
    });
    test('00 prefix becomes +', () {
      expect(normalizePhone('00213 551 234 567'), '+213551234567');
    });
    test('keeps an explicit + and drops separators', () {
      expect(normalizePhone(' +33 (6) 12.34.56.78 '), '+33612345678');
    });
    test('local number without a known country stays as dialled', () {
      expect(normalizePhone('0551234567'), '0551234567');
    });
    test('short codes are not rewritten', () {
      expect(normalizePhone('017', dialCode: '213'), '017');
    });
    test('empty input', () {
      expect(normalizePhone('  - '), '');
    });
  });

  group('FajrContact', () {
    test('JSON round-trip', () {
      expect(FajrContact.fromJson(mother.toJson()), mother);
      expect(FajrContact.fromJson(friend.toJson()), friend);
    });
    test('fromInput keeps the raw number and normalises the dialled one', () {
      final c = FajrContact.fromInput(
          id: 'x', name: ' أبي ', phone: '0661 00 00 00', dialCode: '213');
      expect(c.name, 'أبي');
      expect(c.phone, '+213661000000');
      expect(c.rawPhone, '0661 00 00 00');
    });
  });

  group('FajrCallList', () {
    test('defaults match the product brief', () {
      const l = FajrCallList(id: 'l', name: 'والداي');
      expect(l.ringTimeoutSec, 20);
      expect(l.waitAfterAnswerSec, 30);
      expect(l.gapBetweenSec, 3);
      expect(l.stopAfterFirstAnswer, isFalse);
      expect(l.retryOnNoAnswer, isTrue);
      expect(l.maxRetries, 1);
      expect(l.repeatWholeLoop, isFalse);
      expect(l.loopRepeats, 1);
      expect(l.mode, FajrCallMode.auto);
      expect(l.startMode, FajrStartMode.fajr);
    });

    test('JSON round-trip with every field set', () {
      const l = FajrCallList(
        id: 'l1',
        name: 'والداي',
        enabled: true,
        startMode: FajrStartMode.fixed,
        fixedTime: TimeOfDayHm(5, 7),
        fajrOffsetMinutes: -10,
        repeatDaily: false,
        weekdays: {DateTime.friday, DateTime.monday},
        contacts: [mother, friend],
        ringTimeoutSec: 45,
        waitAfterAnswerSec: 10,
        gapBetweenSec: 5,
        stopAfterFirstAnswer: true,
        retryOnNoAnswer: false,
        maxRetries: 3,
        repeatWholeLoop: true,
        loopRepeats: 2,
        mode: FajrCallMode.manual,
        phoneAccountId: 'sim-2',
      );
      final back = FajrCallList.fromJson(l.toJson());
      expect(back, l);
      expect(back.contacts, [mother, friend]);
      expect(back.weekdays, {DateTime.monday, DateTime.friday});
      expect(back.fixedTime, const TimeOfDayHm(5, 7));
    });

    test('fromJson clamps out-of-range values and survives junk', () {
      final l = FajrCallList.fromJson({
        'id': 'l',
        'ringTimeoutSec': 500,
        'fajrOffsetMinutes': -999,
        'maxRetries': 0,
        'weekdays': [0, 3, 9, 'x'],
        'contacts': ['junk', mother.toJson()],
        'fixedTime': '25:99',
        'mode': 'nope',
      });
      expect(l.ringTimeoutSec, FajrCallList.maxRingTimeoutSec);
      expect(l.fajrOffsetMinutes, FajrCallList.minFajrOffset);
      expect(l.maxRetries, 1);
      expect(l.weekdays, {3});
      expect(l.contacts, [mother]);
      expect(l.fixedTime, const TimeOfDayHm(4, 30));
      expect(l.mode, FajrCallMode.auto);
    });

    test('runsOn: empty weekdays means every day', () {
      const every = FajrCallList(id: 'a', name: 'a');
      const fri = FajrCallList(id: 'b', name: 'b', weekdays: {DateTime.friday});
      expect(every.runsOn(DateTime.tuesday), isTrue);
      expect(fri.runsOn(DateTime.friday), isTrue);
      expect(fri.runsOn(DateTime.saturday), isFalse);
    });

    test('copyWith can clear the SIM choice', () {
      const l = FajrCallList(id: 'a', name: 'a', phoneAccountId: 'sim');
      expect(l.copyWith(clearPhoneAccount: true).phoneAccountId, isNull);
      expect(l.copyWith(name: 'b').phoneAccountId, 'sim');
    });
  });

  group('CallSession', () {
    final session = CallSession(
      id: 's1',
      listId: 'l1',
      listName: 'والداي',
      firedAt: DateTime(2026, 11, 15, 5, 56),
      attempts: [
        attempt(mother, CallStatus.noAnswer),
        attempt(friend, CallStatus.answered, min: 1),
        attempt(mother, CallStatus.called, no: 2, min: 2),
        attempt(friend, CallStatus.failed, no: 2, min: 3),
      ],
    );

    test('totals count calls, not ticks', () {
      final ticked = session.markAwake(mother, DateTime(2026, 11, 15, 6));
      expect(ticked.total, 4);
      expect(ticked.answered, 1);
      expect(ticked.noAnswer, 1);
      expect(ticked.ended, 1);
      expect(ticked.failed, 1);
      expect(ticked.awake, 2, reason: 'friend answered, mother was ticked');
    });

    test('markAwake is idempotent and can be undone', () {
      final at = DateTime(2026, 11, 15, 6);
      var s = session.markAwake(mother, at).markAwake(mother, at);
      expect(
          s.attempts.where((a) => a.status == CallStatus.markedAwake).length, 1);
      s = s.markAwake(mother, at, awake: false);
      expect(s.awakeContactIds, {'c2'});
    });

    test('contacts are listed once in first-call order', () {
      expect(session.contacts.map((c) => c.id), ['c1', 'c2']);
    });

    test('JSON round-trip', () {
      final s = session
          .markAwake(mother, DateTime(2026, 11, 15, 6))
          .copyWith(stoppedByUser: true);
      final back = CallSession.fromJson(s.toJson());
      expect(back.id, s.id);
      expect(back.listName, s.listName);
      expect(back.firedAt, s.firedAt);
      expect(back.stoppedByUser, isTrue);
      expect(back.attempts, s.attempts);
    });
  });

  group('PrayerSettings', () {
    test('defaults to the Algerian method with no location', () {
      const s = PrayerSettings();
      expect(s.method, PrayerMethod.algeria);
      expect(s.hasLocation, isFalse);
    });

    test('JSON round-trip and invalid coordinates are dropped', () {
      const s = PrayerSettings(
        latitude: 36.7538,
        longitude: 3.0588,
        placeName: 'الجزائر',
        source: LocationSource.gps,
        method: PrayerMethod.morocco,
        madhab: PrayerMadhab.hanafi,
      );
      expect(PrayerSettings.fromJson(s.toJson()), s);
      final bad = PrayerSettings.fromJson({'latitude': 120, 'longitude': 3});
      expect(bad.hasLocation, isFalse);
    });
  });
}
