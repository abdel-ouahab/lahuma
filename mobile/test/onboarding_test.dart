import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lahuma/features/adhkar/domain/dhikr.dart';
import 'package:lahuma/features/adhkar/presentation/adhkar_providers.dart';
import 'package:lahuma/features/fajr_call/data/location_service.dart';
import 'package:lahuma/features/home/presentation/home_screen.dart';
import 'package:lahuma/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:lahuma/features/onboarding/presentation/widgets/onboarding_chrome.dart';
import 'package:lahuma/features/prayer_times/data/prayer_times_cache.dart';
import 'package:lahuma/features/prayer_times/data/prayer_times_service.dart';
import 'package:lahuma/features/prayer_times/data/reverse_geocoder.dart';
import 'package:lahuma/features/prayer_times/domain/prayer_times.dart';
import 'package:lahuma/features/prayer_times/presentation/prayer_times_providers.dart';
import 'package:lahuma/features/settings/presentation/screens/settings_screen.dart';
import 'package:lahuma/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _flag = 'onboarding_completed_v1';

Future<void> _launch(WidgetTester tester) async {
  await tester.pumpWidget(ProviderScope(overrides: [
    // Home reads today's adhkar progress; none are loaded in tests.
    adhkarProvider.overrideWith((ref) async => const AdhkarCollection({})),
  ], child: const LahumaApp()));
}

/// Pumps [total] in 50 ms frames. The miniatures loop, so nothing settles.
Future<void> _wait(WidgetTester tester,
    [Duration total = const Duration(milliseconds: 800)]) async {
  for (var t = Duration.zero;
      t < total;
      t += const Duration(milliseconds: 50)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// A first launch, through the splash into the introduction.
Future<void> _firstLaunch(WidgetTester tester,
    {String locale = 'arabic'}) async {
  SharedPreferences.setMockInitialValues({'settings.locale': locale});
  await _launch(tester);
  await _wait(tester, const Duration(milliseconds: 2600));
  expect(find.byType(OnboardingScreen), findsOneWidget);
}

double _page(WidgetTester tester) => onboardingPageOf(
    tester.widget<PageView>(find.byType(PageView)).controller!);

Future<bool?> _seen() async =>
    (await SharedPreferences.getInstance()).getBool(_flag);

class _RecordingLocation extends LocationService {
  final requests = <bool>[];

  @override
  Future<({double latitude, double longitude})> currentPosition(
      {bool request = true}) async {
    requests.add(request);
    return (latitude: 36.75, longitude: 3.06);
  }
}

class _NoGeocoder extends ReverseGeocoder {
  @override
  Future<String> cityName(double lat, double lng) async => '';
}

/// Offline: only the location request matters here.
class _NoApi extends PrayerTimesApiService {
  @override
  Future<DayPrayerTimes> fetch(DateTime day, double lat, double lng) =>
      Future.error(Exception('offline'));

  @override
  Future<List<DayPrayerTimes>> fetchRange(
          List<DateTime> days, double lat, double lng) =>
      Future.error(Exception('offline'));
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Skip marks the introduction seen and opens Home',
      (tester) async {
    await _firstLaunch(tester);
    expect(await _seen(), isNull);

    await tester.tap(find.text('تخطي'));
    await _wait(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(await _seen(), isTrue);
  });

  testWidgets('Next walks the pages; Start on the last marks it seen',
      (tester) async {
    await _firstLaunch(tester);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('التالي'));
      await _wait(tester);
    }
    expect(find.text('بسم الله، لنبدأ'), findsOneWidget);
    // No Skip on the last page, and Next has become Start.
    expect(find.text('التالي'), findsNothing);
    expect(
        tester
            .widget<IgnorePointer>(find
                .ancestor(
                    of: find.text('تخطي'), matching: find.byType(IgnorePointer))
                .first)
            .ignoring,
        isTrue);
    expect(await _seen(), isNull);

    await tester.tap(find.text('ابدأ'));
    await _wait(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(await _seen(), isTrue);
  });

  testWidgets('Arabic: page 1 is on the right, the next comes from the left',
      (tester) async {
    await _firstLaunch(tester);
    // The first page's dot is the rightmost.
    final dots = find.descendant(
        of: find.byType(OnboardingIndicator), matching: find.byType(Container));
    expect(tester.getCenter(dots.first).dx,
        greaterThan(tester.getCenter(dots.last).dx));

    // Pulling the page to the left goes nowhere: there is nothing before it.
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await _wait(tester);
    expect(_page(tester), closeTo(0, 0.01));

    // Pulling it to the right brings in page 2 from the left.
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await _wait(tester);
    expect(_page(tester), closeTo(1, 0.01));
    expect(find.text('اقرأ واستمع'), findsOneWidget);
  });

  testWidgets('English: the next page comes from the right', (tester) async {
    await _firstLaunch(tester, locale: 'english');
    final dots = find.descendant(
        of: find.byType(OnboardingIndicator), matching: find.byType(Container));
    expect(tester.getCenter(dots.first).dx,
        lessThan(tester.getCenter(dots.last).dx));

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await _wait(tester);
    expect(_page(tester), closeTo(1, 0.01));
    expect(find.text('Read and listen'), findsOneWidget);
  });

  testWidgets('Reduce Motion: last frames at once, pages turn at once',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    SharedPreferences.setMockInitialValues({});
    await _launch(tester);
    await _wait(tester, const Duration(milliseconds: 600));
    expect(find.byType(OnboardingScreen), findsOneWidget);
    // The welcome counter already shows its total.
    expect(find.text('286'), findsOneWidget);

    await tester.tap(find.text('التالي'));
    await tester.pump();
    expect(_page(tester), closeTo(1, 0.01));
  });

  testWidgets('on iOS the Fajr page adds the iPhone line', (tester) async {
    const note = 'على iPhone: تذكيرٌ بقائمة الاتصال، ونقرةٌ واحدة لكل اتصال.';
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await _firstLaunch(tester);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('التالي'));
      await _wait(tester);
    }
    expect(find.text('نداء الفجر'), findsOneWidget);
    expect(find.text(note), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('elsewhere the Fajr page has no iPhone line', (tester) async {
    await _firstLaunch(tester);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('التالي'));
      await _wait(tester);
    }
    expect(find.text('نداء الفجر'), findsOneWidget);
    expect(find.textContaining('iPhone'), findsNothing);
  });

  testWidgets('the prayer page counts down once a second while shown',
      (tester) async {
    await _firstLaunch(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('التالي'));
      await _wait(tester);
    }
    expect(find.text('صلاتك في وقتها'), findsOneWidget);
    final before = find.textContaining('01:24:');
    expect(before, findsOneWidget);
    final first = tester.widget<Text>(before).data!;
    await _wait(tester, const Duration(seconds: 2));
    final later = tester.widget<Text>(find.textContaining('01:24:')).data!;
    expect(later, isNot(first));
  });

  testWidgets('Settings shows it again and returns to Settings',
      (tester) async {
    SharedPreferences.setMockInitialValues({_flag: true});
    await _launch(tester);
    await _wait(tester, const Duration(milliseconds: 2600));
    GoRouter.of(tester.element(find.byType(HomeScreen))).go('/settings');
    await _wait(tester);

    final row = find.text('عرض المقدمة مرة أخرى');
    await tester.scrollUntilVisible(row, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(row);
    await _wait(tester);
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await tester.tap(find.text('تخطي'));
    await _wait(tester);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  test('prayer times ask for the location only once the introduction was seen',
      () async {
    Future<List<bool>> firstLoad({required bool seen}) async {
      SharedPreferences.setMockInitialValues({});
      final location = _RecordingLocation();
      final notifier = PrayerTimesNotifier(
        service: _NoApi(),
        cache: PrayerTimesCache(),
        location: location,
        geocoder: _NoGeocoder(),
        now: () => DateTime(2026, 11, 4, 10),
        mayAskForLocation: () async => seen,
      );
      await notifier.ready;
      notifier.dispose();
      return location.requests;
    }

    expect(await firstLoad(seen: false), [false]);
    expect(await firstLoad(seen: true), [true]);
  });
}
