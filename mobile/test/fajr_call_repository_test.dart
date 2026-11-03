import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/core/constants/storage_keys.dart';
import 'package:lahuma/features/fajr_call/data/fajr_call_repository.dart';
import 'package:lahuma/features/fajr_call/domain/call_attempt.dart';
import 'package:lahuma/features/fajr_call/domain/call_session.dart';
import 'package:lahuma/features/fajr_call/domain/fajr_call_list.dart';
import 'package:lahuma/features/fajr_call/domain/fajr_contact.dart';
import 'package:lahuma/features/fajr_call/domain/prayer_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const contact = FajrContact(id: 'c1', name: 'أبي', phone: '+213661000000');

CallSession session(String id, DateTime firedAt) => CallSession(
      id: id,
      listId: 'l1',
      listName: 'والداي',
      firedAt: firedAt,
      attempts: [
        CallAttempt(
            contact: contact, startedAt: firedAt, status: CallStatus.called),
      ],
    );

void main() {
  late FajrCallRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = FajrCallRepository();
  });

  test('starts empty', () async {
    expect(await repo.loadLists(), isEmpty);
    expect(await repo.loadSessions(), isEmpty);
    expect(await repo.loadPrayerSettings(), const PrayerSettings());
  });

  test('saves and loads lists in order', () async {
    const lists = [
      FajrCallList(id: 'a', name: 'والداي', contacts: [contact]),
      FajrCallList(id: 'b', name: 'Friends', enabled: true),
    ];
    await repo.saveLists(lists);
    expect(await repo.loadLists(), lists);
  });

  test('sessions come back newest first and are capped', () async {
    final base = DateTime(2026, 1, 1, 5);
    await repo.saveSessions([
      for (var i = 0; i < FajrCallRepository.maxSessions + 5; i++)
        session('s$i', base.add(Duration(days: i))),
    ]);
    final loaded = await repo.loadSessions();
    expect(loaded, hasLength(FajrCallRepository.maxSessions));
    expect(loaded.first.id, 's34');
    expect(loaded.last.id, 's5');
  });

  test('upsert replaces a session with the same id', () async {
    final s = session('s1', DateTime(2026, 1, 1, 5));
    await repo.upsertSessions([s]);
    final ticked = s.markAwake(contact, DateTime(2026, 1, 1, 6));
    final all = await repo
        .upsertSessions([ticked, session('s2', DateTime(2026, 1, 2, 5))]);
    expect(all.map((e) => e.id), ['s2', 's1']);
    expect(all.last.awake, 1);
  });

  test('clearSessions empties the log only', () async {
    await repo.saveLists(const [FajrCallList(id: 'a', name: 'a')]);
    await repo.upsertSessions([session('s1', DateTime(2026, 1, 1))]);
    await repo.clearSessions();
    expect(await repo.loadSessions(), isEmpty);
    expect(await repo.loadLists(), hasLength(1));
  });

  test('prayer settings round-trip', () async {
    const s =
        PrayerSettings(latitude: 36.75, longitude: 3.06, placeName: 'الجزائر');
    await repo.savePrayerSettings(s);
    expect(await repo.loadPrayerSettings(), s);
  });

  test('corrupt storage falls back to empty / defaults', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.fajrCallLists: '{not json',
      StorageKeys.fajrCallSessions: '"a string"',
      StorageKeys.fajrCallPrayerSettings: '[1,2',
    });
    expect(await repo.loadLists(), isEmpty);
    expect(await repo.loadSessions(), isEmpty);
    expect(await repo.loadPrayerSettings(), const PrayerSettings());
  });
}
