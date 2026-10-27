import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/utils/arabic_text.dart';
import '../../data/location_service.dart';
import '../../data/places.dart';
import '../../domain/prayer_settings.dart';
import '../fajr_call_providers.dart';
import 'fajr_call_labels.dart';

final locationServiceProvider = Provider((ref) => const LocationService());

/// Location and calculation method for prayer times, with today's Fajr as
/// live feedback.
class PrayerSettingsSheet extends ConsumerStatefulWidget {
  const PrayerSettingsSheet({super.key, required this.controller});

  final ScrollController controller;

  static Future<void> show(BuildContext context) => showAppSheet<void>(
        context,
        title: context.tr('الموقع وطريقة الحساب', 'Location & method'),
        builder: (_, controller) =>
            PrayerSettingsSheet(controller: controller),
      );

  @override
  ConsumerState<PrayerSettingsSheet> createState() =>
      _PrayerSettingsSheetState();
}

class _PrayerSettingsSheetState extends ConsumerState<PrayerSettingsSheet> {
  bool _locating = false;

  Future<void> _useGps() async {
    setState(() => _locating = true);
    final arabic = context.isArabic;
    try {
      final p = await ref.read(locationServiceProvider).currentPosition();
      final near = nearestPlace(p.latitude, p.longitude);
      final current = ref.read(fajrCallProvider).prayer;
      await ref.read(fajrCallProvider.notifier).setPrayerSettings(
            current.copyWith(
              latitude: p.latitude,
              longitude: p.longitude,
              source: LocationSource.gps,
              placeName: near.km < 60
                  ? near.place.name(arabic)
                  : (arabic ? 'موقعي الحالي' : 'My location'),
              method: near.km < 300
                  ? methodForCountry(near.place.country)
                  : current.method,
            ),
          );
    } on LocationException catch (e) {
      if (!mounted) return;
      final open = await showAppDialog<bool>(
        context,
        title: context.tr('تعذّر تحديد الموقع', "Couldn't get your location"),
        message: switch (e.reason) {
          LocationFailure.serviceDisabled => context.tr(
              'خدمة الموقع متوقفة. فعّلها أو اختر مدينتك من القائمة.',
              'Location services are off. Turn them on or pick your city.'),
          LocationFailure.deniedForever => context.tr(
              'إذن الموقع مرفوض. يمكنك السماح به من الإعدادات أو اختيار مدينتك.',
              'Location access is blocked. Allow it in Settings or pick your city.'),
          _ => context.tr('اختر مدينتك من القائمة بدلًا من ذلك.',
              'Pick your city from the list instead.'),
        },
        actions: [
          AppDialogAction(label: context.tr('حسنًا', 'OK'), value: false),
          if (e.reason == LocationFailure.serviceDisabled ||
              e.reason == LocationFailure.deniedForever)
            AppDialogAction(
                label: context.tr('الإعدادات', 'Settings'),
                value: true,
                isDefault: true),
        ],
      );
      if (open == true) {
        await ref.read(locationServiceProvider).openSettings(e.reason);
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickCity() async {
    final place = await showAppSheet<Place>(
      context,
      title: context.tr('اختر مدينتك', 'Choose your city'),
      builder: (_, controller) => _CityPicker(controller: controller),
    );
    if (place == null || !mounted) return;
    final current = ref.read(fajrCallProvider).prayer;
    await ref.read(fajrCallProvider.notifier).setPrayerSettings(
          current.copyWith(
            latitude: place.latitude,
            longitude: place.longitude,
            placeName: place.name(context.isArabic),
            source: LocationSource.manual,
            method: methodForCountry(place.country),
          ),
        );
  }

  Future<void> _pickMethod(PrayerSettings current) async {
    final method = await showAppPicker<PrayerMethod>(
      context,
      title: context.tr('طريقة الحساب', 'Calculation method'),
      items: PrayerMethod.values,
      selected: current.method,
      labelOf: (m) => methodLabel(context, m),
    );
    if (method == null || !mounted) return;
    await ref
        .read(fajrCallProvider.notifier)
        .setPrayerSettings(current.copyWith(method: method));
  }

  @override
  Widget build(BuildContext context) {
    final prayer = ref.watch(fajrCallProvider.select((s) => s.prayer));
    final now = ref.watch(fajrClockProvider)();
    final fajr = ref.watch(fajrScheduleProvider).prayerTimes.fajrOn(prayer, now);

    return ListView(
      controller: widget.controller,
      children: [
        const SizedBox(height: AppSpacing.md),
        AppListSection(
          hasLeading: true,
          footer: context.tr(
            'يُحسب الوقت على جهازك دون إنترنت، ولا يُرسل موقعك إلى أي مكان.',
            'Times are calculated on your device, offline. Your location is never sent anywhere.',
          ),
          children: [
            AppListTile(
              leading: const AppIconTile(
                  icon: CupertinoIcons.sunrise_fill,
                  color: AppColors.tileOrange),
              title: context.tr('الفجر اليوم', 'Fajr today'),
              value: fajr == null
                  ? context.tr('حدّد موقعك', 'Set your location')
                  : formatClock(context, fajr),
            ),
          ],
        ),
        AppListSection(
          header: context.tr('الموقع', 'Location'),
          hasLeading: true,
          children: [
            AppListTile(
              leading: const AppIconTile(
                  icon: CupertinoIcons.location_fill,
                  color: AppColors.tileBlue),
              title: context.tr('استخدم موقعي الحالي', 'Use my current location'),
              subtitle: prayer.source == LocationSource.gps && prayer.hasLocation
                  ? prayer.placeName
                  : context.tr('مرة واحدة، بدقة المدينة',
                      'Once, at city-level accuracy'),
              trailing: _locating ? const CupertinoActivityIndicator() : null,
              chevron: !_locating,
              onTap: _locating ? null : _useGps,
            ),
            AppListTile(
              leading: const AppIconTile(
                  icon: CupertinoIcons.building_2_fill,
                  color: AppColors.tileIndigo),
              title: context.tr('اختر مدينة', 'Choose a city'),
              value: prayer.source == LocationSource.manual && prayer.hasLocation
                  ? prayer.placeName
                  : null,
              onTap: _pickCity,
            ),
          ],
        ),
        AppListSection(
          header: context.tr('طريقة الحساب', 'Calculation method'),
          footer: context.tr(
            'تختار المدينة طريقة بلدها تلقائيًا، ويمكنك تغييرها. قارن الوقت بتقويم مسجدك.',
            "Choosing a city picks its country's method; you can change it. Compare with your mosque's timetable.",
          ),
          children: [
            AppListTile(
              title: methodLabel(context, prayer.method),
              onTap: () => _pickMethod(prayer),
            ),
          ],
        ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + AppSpacing.lg),
      ],
    );
  }
}

class _CityPicker extends StatefulWidget {
  const _CityPicker({required this.controller});

  final ScrollController controller;

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final arabic = context.isArabic;
    final q = normalizeArabic(_query.trim().toLowerCase());
    final places = [
      for (final p in kPlaces)
        if (q.isEmpty ||
            normalizeArabic(p.ar).contains(q) ||
            p.en.toLowerCase().contains(q))
          p,
    ];
    return ListView(
      controller: widget.controller,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppSearchField(
            placeholder: context.tr('ابحث عن مدينة', 'Search for a city'),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (places.isEmpty)
          AppEmptyState(
            icon: CupertinoIcons.search,
            title: context.tr('لا نتائج', 'No results'),
            message: context.tr(
                'جرّب اسمًا آخر، أو استخدم موقعك الحالي.',
                'Try another name, or use your current location.'),
          )
        else
          AppListSection(
            children: [
              for (final p in places)
                AppListTile(
                  title: p.name(arabic),
                  value: p.country,
                  chevron: false,
                  onTap: () => Navigator.of(context).pop(p),
                ),
            ],
          ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + AppSpacing.lg),
      ],
    );
  }
}
