import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/fajr_call/data/fajr_call_platform.dart';
import 'package:lahuma/features/fajr_call/data/fajr_call_repository.dart';
import 'package:lahuma/features/fajr_call/data/fajr_notifications.dart';
import 'package:lahuma/features/fajr_call/data/fajr_schedule.dart';
import 'package:lahuma/features/fajr_call/domain/call_attempt.dart';
import 'package:lahuma/features/fajr_call/domain/call_session.dart';
import 'package:lahuma/features/fajr_call/domain/fajr_call_list.dart';
import 'package:lahuma/features/fajr_call/presentation/fajr_call_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'helpers/fajr_call_fakes.dart';

void main() {
  late DateTime clock;
  late FakeFajrPlatform platform;
  late FakeFajrNotifications notifications;
  late FajrCallRepository repo;

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Algiers'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime(2026, 11, 15, 1);
    platform = FakeFajrPlatform();
    notifications = FakeFajrNotifications();
    repo = FajrCallRepository();
  });

  Future<FajrCallNotifier> make() async {
    final n = FajrCallNotifier(
      repository: repo,
      platform: platform,
      notifications: notifications,
      schedule: const FajrSchedule(),
      now: () => clock,
      arabic: () => true,
    );
    await n.ready;
    return n;
  }

  test('a manual list is scheduled as notifications, not natively', () async {
    await repo.savePrayerSettings(algiers);
    await repo.saveLists([parentsList.copyWith(mode: FajrCallMode.manual)]);
    final n = await make();
    expect(n.state.loaded, isTrue);
    final last = notifications.synced.last;
    expect(last.single.list.id, 'l1');
    expect(last.single.times, hasLength(FajrSchedule.precomputeCount));
    expect(platform.synced, isEmpty, reason: 'engine not supported');
  });

  test('auto lists fall back to manual without call permissions', () async {
    platform.supported = true;
    await repo.savePrayerSettings(algiers);
    await repo.saveLists([parentsList]);
    final n = await make();
    expect(n.state.effectiveMode(parentsList), FajrCallMode.manual);
    expect(platform.synced.last, isEmpty);
    expect(notifications.synced.last.single.list.id, 'l1');
  });

  test('auto lists go to the engine when supported and permitted', () async {
    platform
      ..supported = true
      ..perms =
          const FajrNativePermissions(callPhone: true, phoneState: true);
    await repo.savePrayerSettings(algiers);
    await repo.saveLists([parentsList]);
    await make();
    final native = platform.synced.last.single;
    expect(native.list.id, 'l1');
    expect(native.fireTimes.first.isAfter(clock), isTrue);
    expect(notifications.synced.last, isEmpty);
  });

  test('disabled, empty and location-less lists are not scheduled', () async {
    await repo.saveLists([
      parentsList.copyWith(enabled: false),
      const FajrCallList(id: 'empty', name: 'x', enabled: true),
      parentsList.copyWith(), // Fajr mode, but no location saved
    ]);
    await make();
    expect(notifications.synced.last, isEmpty);
  });

  test('saveList arms a one-off list, which expires after it ran', () async {
    await repo.savePrayerSettings(algiers);
    final n = await make();
    await n.saveList(parentsList.copyWith(repeatDaily: false));
    final saved = n.state.listById('l1')!;
    expect(saved.armedAt, clock);
    expect(n.state.listById('l1')!.enabled, isTrue);

    clock = DateTime(2026, 11, 15, 9); // after that morning's Fajr
    await n.refresh();
    expect(n.state.listById('l1')!.enabled, isFalse);
  });

  test('re-enabling a one-off list re-arms it from now', () async {
    await repo.savePrayerSettings(algiers);
    final n = await make();
    await n.saveList(parentsList.copyWith(repeatDaily: false));
    clock = DateTime(2026, 11, 16, 9);
    await n.setEnabled('l1', false);
    await n.setEnabled('l1', true);
    expect(n.state.listById('l1')!.armedAt, clock);
    expect(n.state.listById('l1')!.enabled, isTrue);
  });

  test('sessions written by the engine are merged on refresh', () async {
    final n = await make();
    platform.pending = [
      CallSession(
        id: 'native-1',
        listId: 'l1',
        listName: 'والداي',
        firedAt: DateTime(2026, 11, 15, 5, 56),
        attempts: [
          CallAttempt(
              contact: mother,
              startedAt: DateTime(2026, 11, 15, 5, 56),
              status: CallStatus.noAnswer),
        ],
      ),
    ];
    await n.refresh();
    expect(n.state.sessions.single.id, 'native-1');
    expect((await repo.loadSessions()).single.id, 'native-1');
  });

  test('wake list: calls and ticks build one session per morning', () async {
    await repo.saveLists([parentsList]);
    final n = await make();
    final at = DateTime(2026, 11, 15, 5, 56);
    var session = n.wakeSession(parentsList, at);
    expect(session.attempts, isEmpty);

    await n.logManualCall(session, mother);
    session = n.wakeSession(parentsList, at);
    await n.logManualCall(session, mother);
    session = n.wakeSession(parentsList, at);
    expect(session.total, 2);
    expect(session.attempts.last.attemptNo, 2);
    expect(session.mode, FajrCallMode.manual);

    await n.markAwake(session, father, awake: true);
    expect(n.wakeSession(parentsList, at).awake, 1);
    expect(n.state.sessions, hasLength(1));
    expect(n.state.sessions.single.id,
        FajrCallNotifier.manualSessionId('l1', at));
  });

  test('clearLog only clears the given list', () async {
    final n = await make();
    await n.logManualCall(
        n.wakeSession(parentsList, DateTime(2026, 11, 15, 5)), mother);
    await n.logManualCall(
        n.wakeSession(parentsList.copyWith(), DateTime(2026, 11, 16, 5)),
        mother);
    const other = FajrCallList(id: 'l2', name: 'Friends');
    await n.logManualCall(
        n.wakeSession(other, DateTime(2026, 11, 15, 5)), father);
    await n.clearLog(listId: 'l1');
    expect(n.state.sessions.map((s) => s.listId), ['l2']);
  });

  test('notification ids are stable and per-list budgets fit iOS', () {
    expect(FajrNotifications.idFor('l1', 0), FajrNotifications.idFor('l1', 0));
    expect(FajrNotifications.idFor('l1', 1),
        isNot(FajrNotifications.idFor('l1', 0)));
    expect(FajrNotifications.perList(1), FajrNotifications.maxPerList);
    expect(FajrNotifications.perList(10) * 10,
        lessThanOrEqualTo(FajrNotifications.maxPending));
    expect(FajrNotifications.wakeRoute('l1', DateTime.utc(2026)),
        '/fajr-call/wake/l1?at=${DateTime.utc(2026).millisecondsSinceEpoch}');
  });
}
