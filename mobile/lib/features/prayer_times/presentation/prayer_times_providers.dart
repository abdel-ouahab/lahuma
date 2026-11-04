import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../fajr_call/data/location_service.dart';
import '../../fajr_call/data/places.dart' show distanceKm;
import '../../fajr_call/domain/prayer_settings.dart' show LocationSource;
import '../../fajr_call/presentation/fajr_call_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/prayer_times_cache.dart';
import '../data/prayer_times_config.dart';
import '../data/prayer_times_service.dart';
import '../data/reverse_geocoder.dart';
import '../domain/prayer_times.dart';

final prayerTimesApiProvider =
    Provider<PrayerTimesApiService>((ref) => PrayerTimesApiService());
final prayerTimesCacheProvider = Provider((ref) => PrayerTimesCache());
final prayerLocationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());
final reverseGeocoderProvider = Provider((ref) => const ReverseGeocoder());

/// Injectable clock (tests pin it).
final prayerClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

class PrayerTimesState {
  const PrayerTimesState({
    this.today,
    this.tomorrow,
    this.location,
    this.loading = true,
    this.locationFailure,
    this.fetchFailed = false,
    this.upcoming = const [],
  });

  final DayPrayerTimes? today;
  final DayPrayerTimes? tomorrow;
  final PrayerLocation? location;

  /// Working on the first data; nothing to show yet.
  final bool loading;

  /// Why there is no location. Only set while [location] is null.
  final LocationFailure? locationFailure;

  /// The request failed and there is nothing cached for today.
  final bool fetchFailed;

  /// Every known day from today on, in order (up to
  /// [PrayerTimesConfig.daysAhead]); what the adhan schedules from.
  final List<DayPrayerTimes> upcoming;
}

class PrayerTimesNotifier extends StateNotifier<PrayerTimesState> {
  PrayerTimesNotifier({
    required PrayerTimesApiService service,
    required PrayerTimesCache cache,
    required LocationService location,
    required ReverseGeocoder geocoder,
    required DateTime Function() now,
    this.manualLocation,
    this.mayAskForLocation,
    bool autoLoad = true,
  })  : _service = service,
        _cache = cache,
        _locationService = location,
        _geocoder = geocoder,
        _now = now,
        super(const PrayerTimesState()) {
    if (autoLoad) _ready = load();
  }

  final PrayerTimesApiService _service;
  final PrayerTimesCache _cache;
  final LocationService _locationService;
  final ReverseGeocoder _geocoder;
  final DateTime Function() _now;

  /// The place saved in the location settings, used when GPS gives nothing.
  final Future<({PrayerLocation location, bool chosen})?> Function()?
      manualLocation;

  /// Whether the first load may show the system location prompt. False
  /// while the introduction is still to come: it asks for nothing, and
  /// finishing it refreshes with the prompt allowed (see
  /// OnboardingController). Null allows it.
  final Future<bool> Function()? mayAskForLocation;

  Future<void>? _ready;
  Future<void> get ready => _ready ?? Future.value();

  final Completer<void> _cacheLoaded = Completer<void>();

  /// Completes once the cached days are in [state] (or the cache could not
  /// be read), before any location fix or network call. The splash waits
  /// for this so Home opens with times instead of a skeleton.
  Future<void> get cacheLoaded => _cacheLoaded.future;

  PrayerLocation? _location;
  final Map<String, DayPrayerTimes> _days = {};
  LocationFailure? _failure;
  bool _busy = false;
  bool _cacheRead = false;

  /// True until the first load has finished.
  bool _initial = true;

  /// Shows the cache at once, then refreshes in the background. Prompts for
  /// location permission only when no location is saved yet.
  Future<void> load() async {
    try {
      final snap = await _cache.load();
      _location = snap.location;
      _days
        ..clear()
        ..addAll(snap.days);
      _cacheRead = true;
      if (!mounted) return;
      _publish();
    } finally {
      if (!_cacheLoaded.isCompleted) _cacheLoaded.complete();
    }
    var ask = true;
    try {
      ask = await mayAskForLocation?.call() ?? true;
    } catch (_) {}
    if (!mounted) return;
    await refresh(request: ask);
    _initial = false;
  }

  /// Re-reads the location and fills in any missing day. Cheap when nothing
  /// moved and today and tomorrow are cached. [request] allows the system
  /// permission prompt.
  Future<void> refresh({bool request = false}) async {
    if (_busy || !_cacheRead) return;
    _busy = true;
    try {
      final now = _now();
      var moved = false;
      _failure = null;
      _publish(); // skeleton while retrying, so a tap visibly does something
      // GPS first; the place saved in settings only covers a missing fix.
      final setting = await manualLocation?.call();
      if (!mounted) return;
      {
        try {
          final p = await _locationService.currentPosition(request: request);
          final saved = _location;
          if (saved == null ||
              distanceKm(saved.latitude, saved.longitude, p.latitude,
                      p.longitude) >
                  PrayerTimesConfig.refetchDistanceKm) {
            _location =
                PrayerLocation(latitude: p.latitude, longitude: p.longitude);
            _days.clear();
            moved = true;
          }
        } on LocationException catch (e) {
          _failure = e.reason;
        } catch (_) {
          _failure = LocationFailure.unavailable;
        }
        if (!mounted) return;
        if (_failure != null && setting != null && _location == null) {
          _adopt(setting.location);
        }
      }

      final loc = _location;
      if (loc == null) {
        _publish();
        return;
      }
      _failure = null;
      _publish();

      if (moved || loc.city.isEmpty) {
        final city = await _geocoder.cityName(loc.latitude, loc.longitude);
        if (!mounted) return;
        if (city.isNotEmpty) _location = loc.copyWith(city: city);
        _publish();
      }

      var failed = false;
      for (final day in [now, DateTime(now.year, now.month, now.day + 1)]) {
        final d = DateTime(day.year, day.month, day.day);
        if (_days.containsKey(DayPrayerTimes.dayKey(d))) continue;
        try {
          final times = await _service.fetch(d, loc.latitude, loc.longitude);
          _days[times.key] = times;
          if (!mounted) return;
          _publish();
        } catch (_) {
          failed = true;
        }
      }
      // The rest of the week, for the adhan. Best effort: Home only needs
      // today and tomorrow, so a failure here is not surfaced.
      final rest = [
        for (var i = 2; i < PrayerTimesConfig.daysAhead; i++)
          DateTime(now.year, now.month, now.day + i),
      ].where((d) => !_days.containsKey(DayPrayerTimes.dayKey(d))).toList();
      if (rest.isNotEmpty) {
        try {
          final more =
              await _service.fetchRange(rest, loc.latitude, loc.longitude);
          for (final t in more) {
            _days[t.key] = t;
          }
        } catch (_) {}
        if (!mounted) return;
      }
      await _cache.save(PrayerTimesSnapshot(location: _location, days: _days),
          now: now);
      if (!mounted) return;
      _publish(fetchFailed: failed);
    } finally {
      _busy = false;
    }
  }

  /// Switches to [place], dropping cached days when it is a different spot.
  void _adopt(PrayerLocation place) {
    final saved = _location;
    if (saved == null ||
        distanceKm(saved.latitude, saved.longitude, place.latitude,
                place.longitude) >
            PrayerTimesConfig.refetchDistanceKm) {
      _days.clear();
    }
    _location = place;
  }

  /// The clock moved to a new day: switch to its cached times, or fetch.
  Future<void> dayChanged() async {
    if (!_cacheRead) return;
    _publish();
    final now = _now();
    final missing = [
      for (var i = 0; i < PrayerTimesConfig.daysAhead; i++)
        DateTime(now.year, now.month, now.day + i),
    ].any((d) => _forDay(d) == null);
    if (missing) await refresh();
  }

  /// "تفعيل الموقع": prompts when the system still allows it, otherwise
  /// opens the settings page that can fix it.
  Future<void> enableLocation() async {
    final failure = state.locationFailure;
    if (failure == LocationFailure.deniedForever ||
        failure == LocationFailure.serviceDisabled) {
      await _locationService.openSettings(failure!);
      return;
    }
    final started = DateTime.now();
    await refresh(request: true);
    // Still denied, and it came back instantly: the system showed no prompt
    // (Android stops asking after two refusals), so send them to settings.
    final again = state.locationFailure;
    if (again == LocationFailure.denied &&
        DateTime.now().difference(started) <
            const Duration(milliseconds: 400)) {
      await _locationService.openSettings(again!);
    }
  }

  DayPrayerTimes? _forDay(DateTime d) => _days[DayPrayerTimes.dayKey(d)];

  void _publish({bool fetchFailed = false}) {
    final now = _now();
    final today = _forDay(now);
    state = PrayerTimesState(
      today: today,
      tomorrow: _forDay(DateTime(now.year, now.month, now.day + 1)),
      location: _location,
      // Skeleton while work is under way and nothing can be shown yet.
      loading: today == null &&
          !fetchFailed &&
          _failure == null &&
          (_initial || _busy),
      locationFailure: _location == null ? _failure : null,
      fetchFailed: fetchFailed && today == null,
      upcoming: [
        for (final k in _days.keys.toList()..sort())
          if (k.compareTo(DayPrayerTimes.dayKey(now)) >= 0) _days[k]!,
      ],
    );
  }
}

final prayerTimesProvider =
    StateNotifierProvider<PrayerTimesNotifier, PrayerTimesState>((ref) {
  return PrayerTimesNotifier(
    service: ref.watch(prayerTimesApiProvider),
    cache: ref.watch(prayerTimesCacheProvider),
    location: ref.watch(prayerLocationServiceProvider),
    geocoder: ref.watch(reverseGeocoderProvider),
    now: ref.watch(prayerClockProvider),
    mayAskForLocation: () =>
        ref.read(settingsRepositoryProvider).getOnboardingCompleted(),
    manualLocation: () async {
      await ref.read(fajrCallProvider.notifier).ready;
      final p = ref.read(fajrCallProvider).prayer;
      if (!p.hasLocation) return null;
      return (
        location: PrayerLocation(
            latitude: p.latitude!, longitude: p.longitude!, city: p.placeName),
        chosen: p.source == LocationSource.manual,
      );
    },
  );
});

/// Today's timings, for other features (e.g. Fajr Call). Null until loaded.
final todayPrayerTimesProvider =
    Provider<DayPrayerTimes?>((ref) => ref.watch(prayerTimesProvider).today);

/// Known timings from today on (up to a week), for the adhan scheduler.
final upcomingPrayerDaysProvider = Provider<List<DayPrayerTimes>>(
    (ref) => ref.watch(prayerTimesProvider).upcoming);

/// Today's Fajr as a local time, or null until the timings are known.
final todayFajrProvider =
    Provider<DateTime?>((ref) => ref.watch(todayPrayerTimesProvider)?.fajr);
