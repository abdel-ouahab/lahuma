import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../fajr_call/data/location_service.dart';
import '../../../fajr_call/presentation/widgets/prayer_settings_sheet.dart';
import '../../../prayer_times/presentation/prayer_times_providers.dart';
import '../../domain/qibla_service.dart';
import '../qibla_providers.dart';
import '../widgets/calibration_hint.dart';
import '../widgets/compass_dial.dart';
import '../widgets/qibla_info_card.dart';
import '../widgets/qibla_labels.dart';

/// Qibla compass: turn until the pointer meets the Kaaba on the dial.
///
/// The location is the prayer times' (GPS, its cached fix, or the city
/// chosen in settings), so both always agree. Without a compass the dial
/// stays north-up and shows the Qibla's angle from north.
class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  static const String path = '/qibla';

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen>
    with WidgetsBindingObserver {
  static const _qibla = QiblaService();

  bool _aligned = false;
  bool _hintDismissed = false;

  /// Opened from the toolbar, whatever the accuracy.
  bool _hintRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Picks up a move since the last fix; the cached place shows meanwhile.
    Future.microtask(_refreshLocation);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from system settings: the permission or the service may be on.
    if (state == AppLifecycleState.resumed) _refreshLocation();
  }

  void _refreshLocation() {
    if (mounted) ref.read(prayerTimesProvider.notifier).refresh();
  }

  /// The phone's true heading, or null without live readings.
  double? _heading(CompassState s, double declination) {
    final h = s.heading;
    if (s.status != CompassStatus.live || h == null) return null;
    return normalizeDegrees(h + declination);
  }

  void _onCompass(CompassState? _, CompassState next) {
    final info = ref.read(qiblaInfoProvider);
    final declination = ref.read(magneticDeclinationProvider).valueOrNull ?? 0;
    final heading = _heading(next, declination);
    final aligned = info != null &&
        heading != null &&
        _qibla.isAligned(_qibla.turn(heading, info.bearing),
            wasAligned: _aligned);
    if (aligned == _aligned) return;
    // Once per arrival, never continuously.
    if (aligned) HapticFeedback.lightImpact();
    setState(() => _aligned = aligned);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(compassProvider, _onCompass);
    final compass = ref.watch(compassProvider);
    final info = ref.watch(qiblaInfoProvider);
    final declination = ref.watch(magneticDeclinationProvider).valueOrNull ?? 0;
    final location = ref.watch(prayerTimesProvider
        .select((s) => (loading: s.loading, failure: s.locationFailure)));
    final live = compass.status == CompassStatus.live;

    final Widget body;
    if (info != null) {
      body = _compass(context, info, compass, _heading(compass, declination));
    } else if (location.failure == null) {
      body = AppLoader(
          label: context.tr('جارٍ تحديد موقعك…', 'Finding your location…'));
    } else {
      body = _LocationPrompt(failure: location.failure!);
    }

    return AppScaffold(
      title: context.tr('اتجاه القبلة', 'Qibla direction'),
      trailing: info != null && live
          ? AppIconButton(
              icon: CupertinoIcons.infinite,
              label: context.tr('معايرة البوصلة', 'Calibrate the compass'),
              onPressed: () => setState(() => _hintRequested = true),
            )
          : null,
      child: SafeArea(child: body),
    );
  }

  Widget _compass(BuildContext context, QiblaInfo info, CompassState compass,
      double? heading) {
    final live = heading != null;
    final turn = live ? _qibla.turn(heading, info.bearing) : 0.0;
    final showHint = compass.status == CompassStatus.live &&
        (_hintRequested || (compass.needsCalibration && !_hintDismissed));

    const padding = EdgeInsets.fromLTRB(AppSpacing.screenMargin, AppSpacing.md,
        AppSpacing.screenMargin, AppSpacing.lg);
    final duration = AppMotion.of(context);

    // The dial and what to do stay at the top; the facts sit at the bottom,
    // within thumb reach. The calibration hint grows the bottom group
    // upwards, so the dial never moves while it's in use.
    return LayoutBuilder(builder: (context, box) {
      final dialSize = math
          .min(box.maxWidth - 2 * AppSpacing.screenMargin, box.maxHeight * 0.56)
          .clamp(220.0, 400.0);
      return SingleChildScrollView(
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 480,
              minHeight: math.max(0, box.maxHeight - padding.vertical),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    CompassDial(
                      size: dialSize,
                      heading: heading ?? 0,
                      qiblaBearing: info.bearing,
                      aligned: _aligned,
                      live: live,
                      semanticLabel: _dialLabel(context, info, live, turn),
                      center: _Readout(
                        status: compass.status,
                        aligned: _aligned,
                        turn: turn,
                        bearing: info.bearing,
                        size: dialSize,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (compass.status == CompassStatus.unavailable)
                      _NoCompassCard(
                          noSensor: compass.noSensor, bearing: info.bearing)
                    else
                      _Status(
                          status: compass.status,
                          aligned: _aligned,
                          turn: turn),
                  ],
                ),
                Column(
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    AnimatedSize(
                      duration: duration,
                      curve: AppMotion.curve,
                      alignment: Alignment.bottomCenter,
                      child: AnimatedSwitcher(
                        duration: duration,
                        child: showHint
                            ? Padding(
                                key: const ValueKey('calibration'),
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.ms),
                                child: CalibrationHint(
                                  onDismiss: () => setState(() {
                                    _hintDismissed = true;
                                    _hintRequested = false;
                                  }),
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ),
                    QiblaInfoCard(info: info),
                    const SizedBox(height: AppSpacing.ms),
                    const _HoldFlat(),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  String _dialLabel(
      BuildContext context, QiblaInfo info, bool live, double turn) {
    if (!live) return qiblaFromNorth(context, info.bearing);
    if (_aligned) {
      return context.tr('أنت في اتجاه القبلة', 'You are facing the Qibla');
    }
    final n = turn.abs().round();
    return turn > 0
        ? context.tr('القبلة على يمينك بـ $n درجة',
            'The Qibla is $n degrees to your right')
        : context.tr('القبلة على يسارك بـ $n درجة',
            'The Qibla is $n degrees to your left');
  }
}

/// The middle of the dial: degrees left to turn, a check when facing the
/// Qibla, or the angle from north without a compass.
class _Readout extends StatelessWidget {
  const _Readout({
    required this.status,
    required this.aligned,
    required this.turn,
    required this.bearing,
    required this.size,
  });

  final CompassStatus status;
  final bool aligned;
  final double turn;
  final double bearing;

  /// The dial's size, which the readout scales with.
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final big = AppTypography.tabular(AppTypography.largeTitle)
        .copyWith(fontSize: size * 0.11, height: 1.1, color: c.label);
    final small = AppTypography.footnote.copyWith(color: c.secondaryLabel);

    final Widget child;
    switch (status) {
      case CompassStatus.starting:
        child = const CupertinoActivityIndicator(key: ValueKey('starting'));
      case CompassStatus.unavailable:
        child = Column(
          key: const ValueKey('north'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(degrees(bearing),
                textDirection: TextDirection.ltr, style: big),
            Text(context.tr('من الشمال', 'from north'), style: small),
          ],
        );
      case CompassStatus.live when aligned:
        child = Icon(
          CupertinoIcons.checkmark_seal_fill,
          key: const ValueKey('aligned'),
          size: size * 0.16,
          color: c.success,
        );
      case CompassStatus.live:
        final right = turn > 0;
        child = Column(
          key: const ValueKey('turn'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(degrees(turn.abs()),
                textDirection: TextDirection.ltr, style: big),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  right
                      ? CupertinoIcons.arrow_turn_up_right
                      : CupertinoIcons.arrow_turn_up_left,
                  size: 14,
                  color: c.accent,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  right
                      ? context.tr('يمينًا', 'right')
                      : context.tr('يسارًا', 'left'),
                  style: small,
                ),
              ],
            ),
          ],
        );
    }

    return ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.fast),
          child: child,
        ),
      ),
    );
  }
}

/// What to do now, under the dial.
class _Status extends StatelessWidget {
  const _Status({
    required this.status,
    required this.aligned,
    required this.turn,
  });

  final CompassStatus status;
  final bool aligned;
  final double turn;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final Widget child;
    if (status == CompassStatus.starting) {
      child = Text(
        context.tr('جارٍ قراءة البوصلة…', 'Reading the compass…'),
        key: const ValueKey('starting'),
        style: AppTypography.subheadline.copyWith(color: c.secondaryLabel),
      );
    } else if (aligned) {
      child = Semantics(
        key: const ValueKey('aligned'),
        liveRegion: true,
        child: Text(
          context.tr('أنت في اتجاه القبلة ✓', 'You are facing the Qibla ✓'),
          textAlign: TextAlign.center,
          style: AppTypography.title3.copyWith(color: c.success),
        ),
      );
    } else {
      child = Column(
        key: ValueKey(turn > 0),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            turn > 0
                ? context.tr('استدر نحو اليمين', 'Turn right')
                : context.tr('استدر نحو اليسار', 'Turn left'),
            textAlign: TextAlign.center,
            style: AppTypography.headline.copyWith(color: c.label),
          ),
          Text(
            context.tr(
                'حتى يلتقي السهم بالكعبة', 'until the arrow meets the Kaaba'),
            textAlign: TextAlign.center,
            style: AppTypography.footnote.copyWith(color: c.secondaryLabel),
          ),
        ],
      );
    }
    // Same room for one line or two, so the card below doesn't jump.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Center(
        child: AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.fast),
          child: child,
        ),
      ),
    );
  }
}

/// No readings: say why it may be, and how to use the angle instead.
class _NoCompassCard extends StatelessWidget {
  const _NoCompassCard({required this.noSensor, required this.bearing});

  final bool noSensor;
  final double bearing;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final angle = degrees(bearing);
    return AppCard(
      padding: const EdgeInsetsDirectional.all(AppSpacing.ms + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.compass, size: 24, color: c.secondaryLabel),
          const SizedBox(width: AppSpacing.ms),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  noSensor
                      ? context.tr(
                          'لا توجد بوصلة في هاتفك', 'Your phone has no compass')
                      : context.tr('لم تصل قراءة من البوصلة',
                          'No reading from the compass'),
                  style: AppTypography.headline.copyWith(color: c.label),
                ),
                const SizedBox(height: 2),
                Text(
                  noSensor
                      ? context.tr(
                          'القبلة من موقعك على ${ltr(angle)} من الشمال باتجاه عقارب الساعة. حدّد الشمال بمعلم تعرفه، ثم استدر بهذه الزاوية.',
                          'From where you are, the Qibla is $angle clockwise from north. Find north from a landmark you know, then turn by that angle.')
                      : context.tr(
                          'قد لا يحتوي هاتفك على حساس مغناطيسي، أو يحتاج التطبيق إلى إذن الموقع. القبلة من موقعك على ${ltr(angle)} من الشمال باتجاه عقارب الساعة.',
                          'Your phone may have no magnetic sensor, or the app may need location access. From where you are, the Qibla is $angle clockwise from north.'),
                  style: AppTypography.subheadline
                      .copyWith(color: c.secondaryLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Standing advice for a steady reading.
class _HoldFlat extends StatelessWidget {
  const _HoldFlat();

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(CupertinoIcons.device_phone_portrait,
                size: 16, color: c.secondaryLabel),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.tr('ضع الهاتف مستويًا، وأبعده عن المعادن والمغناطيس.',
                  'Hold the phone flat, away from metal and magnets.'),
              style: AppTypography.footnote.copyWith(color: c.secondaryLabel),
            ),
          ),
        ],
      ),
    );
  }
}

/// No location yet: why it's needed and the one step that fixes it, with
/// choosing a city as the way around.
class _LocationPrompt extends ConsumerWidget {
  const _LocationPrompt({required this.failure});

  final LocationFailure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(prayerTimesProvider.notifier);
    final (icon, title, message, action) = switch (failure) {
      LocationFailure.denied => (
          CupertinoIcons.location_fill,
          context.tr('نحتاج إلى موقعك', 'Your location is needed'),
          context.tr(
              'يُحسب اتجاه القبلة على هاتفك من موقعك التقريبي، ولا يلزم موقع دقيق.',
              'The Qibla is worked out on your phone from your approximate location. A precise one isn\'t needed.'),
          context.tr('السماح بالوصول إلى الموقع', 'Allow location access'),
        ),
      LocationFailure.deniedForever => (
          CupertinoIcons.location_slash_fill,
          context.tr('الوصول إلى الموقع متوقف', 'Location access is off'),
          context.tr(
              'اسمح للتطبيق بالوصول إلى موقعك من الإعدادات ليُحسب اتجاه القبلة من مكانك، أو اختر مدينتك.',
              'Allow location access in Settings to find the Qibla from where you are, or pick your city.'),
          context.tr('فتح الإعدادات', 'Open Settings'),
        ),
      LocationFailure.serviceDisabled => (
          CupertinoIcons.location_slash_fill,
          context.tr('خدمة الموقع متوقفة', 'Location services are off'),
          context.tr(
              'شغّل خدمة الموقع في هاتفك ليُحسب اتجاه القبلة من مكانك، أو اختر مدينتك.',
              'Turn on location services to find the Qibla from where you are, or pick your city.'),
          context.tr('فتح إعدادات الموقع', 'Open location settings'),
        ),
      LocationFailure.unavailable => (
          CupertinoIcons.location_slash_fill,
          context.tr('تعذّر تحديد موقعك', 'Couldn\'t find your location'),
          context.tr('تأكد من أن الموقع يعمل ثم أعد المحاولة، أو اختر مدينتك.',
              'Check that location is on and try again, or pick your city.'),
          context.tr('إعادة المحاولة', 'Try again'),
        ),
    };

    // Centred when it fits, scrollable under large text sizes.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AppEmptyState(
                icon: icon,
                title: title,
                message: message,
                action: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton.filled(
                        label: action, onPressed: notifier.enableLocation),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton.plain(
                      label: context.tr('اختر مدينتك', 'Pick your city'),
                      onPressed: () async {
                        await PrayerSettingsSheet.show(context);
                        notifier.refresh();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
