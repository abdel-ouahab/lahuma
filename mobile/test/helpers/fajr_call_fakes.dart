import 'package:lahuma/core/notifications/local_notifications.dart';
import 'package:lahuma/features/fajr_call/data/fajr_call_platform.dart';
import 'package:lahuma/features/fajr_call/data/fajr_notifications.dart';
import 'package:lahuma/features/fajr_call/domain/call_session.dart';
import 'package:lahuma/features/fajr_call/domain/fajr_call_list.dart';
import 'package:lahuma/features/fajr_call/domain/fajr_contact.dart';
import 'package:lahuma/features/fajr_call/domain/prayer_settings.dart';
import 'package:timezone/timezone.dart' as tz;

const algiers = PrayerSettings(
    latitude: 36.754, longitude: 3.059, placeName: 'الجزائر');

const mother = FajrContact(
    id: 'c1',
    name: 'أمي',
    phone: '+213551234567',
    relation: ContactRelation.mother);
const father = FajrContact(
    id: 'c2',
    name: 'أبي',
    phone: '+213661000000',
    relation: ContactRelation.father);

const parentsList = FajrCallList(
  id: 'l1',
  name: 'والداي',
  enabled: true,
  contacts: [mother, father],
);

/// Records what would have gone to the Android engine.
class FakeFajrPlatform extends FajrCallPlatform {
  FakeFajrPlatform({
    this.supported = false,
    this.perms = const FajrNativePermissions(),
    List<CallSession> pending = const [],
    this.accounts = const [],
  }) : _pending = pending;

  bool supported;
  FajrNativePermissions perms;
  List<CallSession> _pending;
  final List<PhoneAccountOption> accounts;
  final synced = <List<({FajrCallList list, List<DateTime> fireTimes})>>[];
  final ran = <FajrCallList>[];

  set pending(List<CallSession> s) => _pending = s;

  @override
  Future<bool> isAutoCallSupported() async => supported;

  @override
  Future<void> sync({
    required List<({FajrCallList list, List<DateTime> fireTimes})> lists,
    required FajrNativeStrings strings,
  }) async =>
      synced.add(lists);

  @override
  Future<bool> runNow(FajrCallList list, FajrNativeStrings strings) async {
    ran.add(list);
    return true;
  }

  @override
  Future<List<CallSession>> takeSessions() async {
    final s = _pending;
    _pending = const [];
    return s;
  }

  @override
  Future<FajrNativePermissions> permissions() async => perms;

  @override
  Future<FajrNativePermissions> requestCallPermissions() async => perms;

  @override
  Future<void> requestIgnoreBatteryOptimizations() async {}

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<List<PhoneAccountOption>> phoneAccounts() async => accounts;
}

/// Records the manual-mode notifications that would be scheduled.
class FakeFajrNotifications extends FajrNotifications {
  FakeFajrNotifications() : super(LocalNotifications());

  final synced = <List<({FajrCallList list, List<tz.TZDateTime> times})>>[];

  @override
  Future<void> sync(
    List<({FajrCallList list, List<tz.TZDateTime> times})> lists, {
    required bool arabic,
  }) async =>
      synced.add(lists);
}
