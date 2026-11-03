import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode, MaterialApp;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lahuma/core/design/app_theme.dart';
import 'package:lahuma/core/router/app_router.dart';
import 'package:lahuma/features/fajr_call/data/location_service.dart';
import 'package:lahuma/features/prayer_times/data/prayer_times_cache.dart';
import 'package:lahuma/features/prayer_times/data/prayer_times_service.dart';
import 'package:lahuma/features/prayer_times/data/reverse_geocoder.dart';
import 'package:lahuma/features/prayer_times/domain/prayer_times.dart';
import 'package:lahuma/features/prayer_times/presentation/prayer_times_providers.dart';
import 'package:lahuma/features/qibla/data/compass_source.dart';
import 'package:lahuma/features/qibla/presentation/qibla_providers.dart';
import 'package:lahuma/features/qibla/presentation/screens/qibla_screen.dart';
import 'package:lahuma/features/qibla/presentation/widgets/calibration_hint.dart';
import 'package:lahuma/features/qibla/presentation/widgets/compass_dial.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Algiers: Qibla 105.4°, 3,926 km.
const _algiers = (latitude: 36.7538, longitude: 3.0588);

class _Offline extends PrayerTimesApiService {
  @override
  Future<DayPrayerTimes> fetch(DateTime day, double lat, double lng) =>
      Future.error(Exception('offline'));

  @override
  Future<List<DayPrayerTimes>> fetchRange(
          List<DateTime> days, double lat, double lng) =>
      Future.error(Exception('offline'));
}

class _Location extends LocationService {
  _Location(this.next);
  final Object next; // a position record or a LocationFailure
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

class _Geocoder extends ReverseGeocoder {
  @override
  Future<String> cityName(double lat, double lng) async => 'الجزائر';
}

class _Compass extends CompassSource {
  _Compass({this.has});

  final bool? has;
  bool listening = false;
  bool cancelled = false;
  late final controller = StreamController<CompassReading>(
    onListen: () => listening = true,
    onCancel: () => cancelled = true,
  );

  @override
  Future<bool?> hasCompass() async => has;

  @override
  Stream<CompassReading> readings() => controller.stream;

  @override
  Future<double> declination(double latitude, double longitude) async => 0;
}

void main() {
  late List<String> haptics;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    haptics = [];
  });

  Future<void> pump(
    WidgetTester tester, {
    required _Compass compass,
    Object location = _algiers,
    String locale = 'ar',
    ThemeMode mode = ThemeMode.light,
    Size size = const Size(390, 844),
    Widget home = const QiblaScreen(),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    });

    final container = ProviderContainer(overrides: [
      compassSourceProvider.overrideWithValue(compass),
      prayerTimesProvider.overrideWith((ref) => PrayerTimesNotifier(
            service: _Offline(),
            cache: PrayerTimesCache(),
            location: _Location(location),
            geocoder: _Geocoder(),
            now: () => DateTime(2026, 11, 2, 10),
          )),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        locale: Locale(locale),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: AppTheme.builder,
        home: home,
      ),
    ));
    await settle(tester);
  }

  Future<void> emit(WidgetTester tester, _Compass compass, double heading,
      {double? accuracy = 10}) async {
    compass.controller
        .add(CompassReading(heading: heading, accuracy: accuracy));
    await settle(tester);
  }

  for (final (locale, mode, size) in [
    ('ar', ThemeMode.light, const Size(390, 844)),
    ('en', ThemeMode.dark, const Size(390, 844)),
    ('ar', ThemeMode.dark, const Size(320, 568)),
    ('ar', ThemeMode.light, const Size(820, 1180)),
  ]) {
    testWidgets(
        'shows the compass and the Qibla · $locale · ${mode.name} · ${size.width.round()}',
        (tester) async {
      final compass = _Compass();
      await pump(tester,
          compass: compass, locale: locale, mode: mode, size: size);
      await emit(tester, compass, 10);

      expect(find.byType(CompassDial), findsOneWidget);
      expect(find.text('105°'), findsOneWidget);
      expect(find.text('3,926'), findsOneWidget);
      expect(find.text('الجزائر'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('turn guidance, then one light haptic on alignment',
      (tester) async {
    final compass = _Compass();
    await pump(tester, compass: compass);

    await emit(tester, compass, 60);
    expect(find.text('استدر نحو اليمين'), findsOneWidget);
    expect(find.text('45°'), findsOneWidget);

    // Smoothing needs a few readings to catch up with a big turn.
    for (var i = 0; i < 40; i++) {
      await emit(tester, compass, 105.4);
    }
    expect(find.text('أنت في اتجاه القبلة ✓'), findsOneWidget);
    expect(haptics, ['HapticFeedbackType.lightImpact']);

    // Small wobbles inside the band don't fire again.
    for (final h in [104.0, 107.0, 105.0, 103.5]) {
      await emit(tester, compass, h);
    }
    expect(haptics, hasLength(1));

    for (var i = 0; i < 40; i++) {
      await emit(tester, compass, 150);
    }
    expect(find.text('استدر نحو اليسار'), findsOneWidget);
  });

  testWidgets('leaving the screen stops the compass', (tester) async {
    final compass = _Compass();
    final open = ValueNotifier(true);
    await pump(tester,
        compass: compass,
        home: ValueListenableBuilder<bool>(
          valueListenable: open,
          builder: (_, on, __) => on ? const QiblaScreen() : const SizedBox(),
        ));
    await emit(tester, compass, 0);
    expect(compass.listening, isTrue);
    expect(compass.cancelled, isFalse);

    open.value = false;
    await settle(tester);
    expect(compass.cancelled, isTrue);
  });

  testWidgets('no magnetometer: still dial and the angle from north',
      (tester) async {
    await pump(tester, compass: _Compass(has: false));
    expect(find.text('لا توجد بوصلة في هاتفك'), findsOneWidget);
    expect(tester.widget<CompassDial>(find.byType(CompassDial)).live, isFalse);
    expect(find.text('105°'), findsWidgets);
  });

  testWidgets('no readings in time: says so', (tester) async {
    await pump(tester, compass: _Compass());
    expect(find.text('جارٍ قراءة البوصلة…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(find.text('لم تصل قراءة من البوصلة'), findsOneWidget);
  });

  testWidgets('low accuracy shows the figure-8 hint until dismissed',
      (tester) async {
    final compass = _Compass();
    await pump(tester, compass: compass);
    await emit(tester, compass, 10, accuracy: 45);
    expect(find.byType(CalibrationHint), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.xmark));
    await settle(tester);
    expect(find.byType(CalibrationHint), findsNothing);

    // The toolbar brings it back on demand.
    await tester.tap(find.byIcon(CupertinoIcons.infinite));
    await settle(tester);
    expect(find.byType(CalibrationHint), findsOneWidget);
  });

  for (final (failure, title, action) in [
    (LocationFailure.denied, 'نحتاج إلى موقعك', 'السماح بالوصول إلى الموقع'),
    (LocationFailure.deniedForever, 'الوصول إلى الموقع متوقف', 'فتح الإعدادات'),
    (
      LocationFailure.serviceDisabled,
      'خدمة الموقع متوقفة',
      'فتح إعدادات الموقع'
    ),
  ]) {
    testWidgets('no location (${failure.name}): explains and offers a fix',
        (tester) async {
      final compass = _Compass();
      await pump(tester, compass: compass, location: failure);
      expect(find.text(title), findsOneWidget);
      expect(find.text(action), findsOneWidget);
      expect(find.text('اختر مدينتك'), findsOneWidget);
      expect(find.byType(CompassDial), findsNothing);
      await emit(tester, compass, 0); // ends the silence timer
    });
  }

  test('/qibla is routed', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    expect(router.configuration.findMatch(Uri.parse('/qibla')).fullPath,
        QiblaScreen.path);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
