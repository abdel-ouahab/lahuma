import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/fajr_call/data/location_service.dart';
import 'package:lahuma/features/prayer_times/data/prayer_times_cache.dart';
import 'package:lahuma/features/prayer_times/data/prayer_times_service.dart';
import 'package:lahuma/features/prayer_times/data/reverse_geocoder.dart';
import 'package:lahuma/features/prayer_times/domain/prayer_times.dart';
import 'package:lahuma/features/prayer_times/presentation/prayer_times_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> payload(String fajr) => {
      'data': {
        'timings': {
          'Fajr': '$fajr (+01)',
          'Sunrise': '06:30',
          'Dhuhr': '12:45',
          'Asr': '15:50',
          'Maghrib': '18:20',
          'Isha': '19:40',
        },
        'date': {
          'hijri': {
            'day': '12',
            'month': {
              'number': 3,
              'en': 'Rabīʿ al-awwal',
              'ar': 'رَبيع الأوّل'
            },
            'year': '1448',
          },
        },
      },
    };

class FakeApi extends PrayerTimesApiService {
  int calls = 0;
  bool fail = false;

  @override
  Future<DayPrayerTimes> fetch(DateTime day, double lat, double lng) async {
    calls++;
    if (fail) throw Exception('offline');
    return PrayerTimesApiService.parse(payload('05:1${calls % 10}'), day);
  }

  int rangeCalls = 0;

  @override
  Future<List<DayPrayerTimes>> fetchRange(
      List<DateTime> days, double lat, double lng) async {
    rangeCalls++;
    if (fail) throw Exception('offline');
    return [
      for (final d in days) PrayerTimesApiService.parse(payload('05:20'), d)
    ];
  }
}

class FakeLocation extends LocationService {
  FakeLocation(this.next);
  Object next; // a record position or a LocationFailure
  LocationFailure? opened;

  @override
  Future<({double latitude, double longitude})> currentPosition(
      {bool request = true}) async {
    final n = next;
    if (n is LocationFailure) throw LocationException(n);
    return n as ({double latitude, double longitude});
  }

  @override
  Future<void> openSettings(LocationFailure reason) async => opened = reason;
}

class FakeGeocoder extends ReverseGeocoder {
  @override
  Future<String> cityName(double lat, double lng) async => 'الجزائر';
}

void main() {
  final day = DateTime(2026, 10, 28);
  late DateTime clock;
  late FakeApi api;
  late FakeLocation loc;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime(2026, 10, 28, 10);
    api = FakeApi();
    loc = FakeLocation((latitude: 36.75, longitude: 3.06));
  });

  PrayerTimesNotifier make() => PrayerTimesNotifier(
        service: api,
        cache: PrayerTimesCache(),
        location: loc,
        geocoder: FakeGeocoder(),
        now: () => clock,
        autoLoad: false,
      );

  test('parses timings and the Hijri date', () {
    final d = PrayerTimesApiService.parse(payload('05:12'), day);
    expect(d.fajr, DateTime(2026, 10, 28, 5, 12));
    expect(d[PrayerKind.isha], DateTime(2026, 10, 28, 19, 40));
    expect(d.hijri!.format(true), '12 رَبيع الأوّل 1448 هـ');
    expect(() => PrayerTimesApiService.parse({'data': {}}, day),
        throwsFormatException);
  });

  test('next prayer rolls over to tomorrow\'s Fajr after Isha', () {
    final today = PrayerTimesApiService.parse(payload('05:12'), day);
    final tomorrow = PrayerTimesApiService.parse(
        payload('05:13'), day.add(const Duration(days: 1)));
    expect(nextPrayerOf(today, tomorrow, DateTime(2026, 10, 28, 10)).kind,
        PrayerKind.dhuhr);
    final after = nextPrayerOf(today, tomorrow, DateTime(2026, 10, 28, 22));
    expect(after.kind, PrayerKind.fajr);
    expect(after.tomorrow, isTrue);
    expect(after.at, DateTime(2026, 10, 29, 5, 13));
  });

  test('first load fetches today and tomorrow, then caches', () async {
    final n = make();
    await n.load();
    expect(n.state.today, isNotNull);
    expect(n.state.tomorrow, isNotNull);
    expect(n.state.location!.city, 'الجزائر');
    expect(api.calls, 2);

    // Relaunch offline: cached times show without any request.
    api.fail = true;
    final again = make();
    await again.load();
    expect(again.state.today!.key, '2026-10-28');
    expect(again.state.fetchFailed, isFalse);
    expect(api.calls, 2);
  });

  test('moving more than 5 km refetches; a short hop does not', () async {
    final n = make();
    await n.load();
    loc.next = (latitude: 36.76, longitude: 3.06); // ~1 km
    await n.refresh();
    expect(api.calls, 2);
    loc.next = (latitude: 35.70, longitude: -0.63); // Oran
    await n.refresh();
    expect(api.calls, 4);
  });

  test('a new day uses the cached tomorrow and fetches the next one', () async {
    final n = make();
    await n.load();
    clock = DateTime(2026, 10, 29, 0, 5);
    await n.dayChanged();
    expect(n.state.today!.key, '2026-10-29');
    // Tomorrow came with the week; only the new last day is requested.
    expect(api.calls, 2);
    expect(api.rangeCalls, 2);
  });

  test('denied with no saved location asks for it; settings when forever',
      () async {
    loc.next = LocationFailure.denied;
    final n = make();
    await n.load();
    expect(n.state.today, isNull);
    expect(n.state.location, isNull);
    expect(n.state.loading, isFalse);
    expect(n.state.locationFailure, LocationFailure.denied);

    loc.next = LocationFailure.deniedForever;
    await n.refresh();
    await n.enableLocation();
    expect(loc.opened, LocationFailure.deniedForever);

    loc.next = (latitude: 36.75, longitude: 3.06);
    await n.refresh(); // back from settings (app resumed)
    expect(n.state.today, isNotNull);
  });

  test('denied with a saved location keeps using it', () async {
    final first = make();
    await first.load();
    loc.next = LocationFailure.deniedForever;
    final n = make();
    await n.load();
    expect(n.state.today, isNotNull);
    expect(n.state.locationFailure, isNull);
  });

  test('keeps a week ahead, fetching only the missing days', () async {
    final n = make();
    await n.load();
    expect(n.state.upcoming.map((d) => d.key).toList(), [
      for (var i = 0; i < 7; i++)
        DayPrayerTimes.dayKey(DateTime(2026, 10, 28 + i)),
    ]);
    expect(api.rangeCalls, 1);
    await n.refresh();
    expect(api.rangeCalls, 1); // nothing missing

    clock = DateTime(2026, 10, 29, 0, 5);
    await n.dayChanged();
    expect(n.state.upcoming.first.key, '2026-10-29');
    expect(n.state.upcoming.length, 7);
  });

  test('parses the monthly calendar payload', () {
    final days = PrayerTimesApiService.parseCalendar({
      'data': [
        {
          ...payload('05:12')['data'] as Map<String, dynamic>,
          'date': {
            'gregorian': {'date': '01-11-2026'},
          },
        },
      ],
    });
    expect(days.single.key, '2026-11-01');
    expect(days.single.fajr, DateTime(2026, 11, 1, 5, 12));
  });

  test('network failure with nothing cached surfaces fetchFailed', () async {
    api.fail = true;
    final n = make();
    await n.load();
    expect(n.state.today, isNull);
    expect(n.state.fetchFailed, isTrue);
    expect(n.state.loading, isFalse);
    api.fail = false;
    await n.refresh();
    expect(n.state.today, isNotNull);
  });
}
