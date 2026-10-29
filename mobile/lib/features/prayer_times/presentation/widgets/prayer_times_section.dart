import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../fajr_call/data/location_service.dart';
import '../../../fajr_call/presentation/fajr_call_providers.dart';
import '../../../fajr_call/presentation/widgets/prayer_settings_sheet.dart';
import '../../domain/prayer_times.dart';
import '../prayer_times_providers.dart';

/// Top of Home: city + Hijri date, the next prayer with a live countdown,
/// and the day's six times. Falls back to a skeleton, an inline "enable
/// location" prompt, or a retry card; it never blocks the rest of Home.
class PrayerTimesSection extends ConsumerStatefulWidget {
  const PrayerTimesSection({super.key});

  @override
  ConsumerState<PrayerTimesSection> createState() => _PrayerTimesSectionState();
}

class _PrayerTimesSectionState extends ConsumerState<PrayerTimesSection>
    with WidgetsBindingObserver {
  Timer? _ticker;
  late DateTime _now;
  late DateTime _day;

  @override
  void initState() {
    super.initState();
    _now = ref.read(prayerClockProvider)();
    _day = DateTime(_now.year, _now.month, _now.day);
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the background or from system settings: the day, the
    // permission or the position may have changed.
    if (state == AppLifecycleState.resumed) {
      ref.read(prayerTimesProvider.notifier).refresh();
    }
  }

  void _tick() {
    if (!mounted) return;
    final now = ref.read(prayerClockProvider)();
    final day = DateTime(now.year, now.month, now.day);
    setState(() => _now = now);
    if (day != _day) {
      _day = day;
      ref.read(prayerTimesProvider.notifier).dayChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    // A new city in the location settings applies right away.
    ref.listen(fajrCallProvider.select((s) => s.prayer), (prev, next) {
      if (prev != null &&
          (prev.latitude != next.latitude ||
              prev.longitude != next.longitude)) {
        ref.read(prayerTimesProvider.notifier).refresh();
      }
    });
    final state = ref.watch(prayerTimesProvider);
    final notifier = ref.read(prayerTimesProvider.notifier);
    final today = state.today;

    if (today != null) {
      return _PrayerCard(
        city: state.location?.city ?? '',
        today: today,
        tomorrow: state.tomorrow,
        now: _now,
      );
    }
    if (state.loading) return const _PrayerSkeleton();
    if (state.location == null) {
      final noFix = state.locationFailure == LocationFailure.unavailable;
      return _MessageCard(
        icon: CupertinoIcons.location_slash_fill,
        message: noFix
            ? context.tr(
                'تعذّر تحديد موقعك الآن', "Couldn't find your location")
            : context.tr('فعّل الموقع لعرض مواقيت الصلاة',
                'Turn on location to show prayer times'),
        action: noFix
            ? context.tr('إعادة المحاولة', 'Retry')
            : context.tr('تفعيل الموقع', 'Enable location'),
        onAction: notifier.enableLocation,
        secondaryAction: context.tr('اختر مدينتك', 'Pick your city'),
        onSecondary: () async {
          await PrayerSettingsSheet.show(context);
          notifier.refresh();
        },
      );
    }
    return _MessageCard(
      icon: CupertinoIcons.wifi_slash,
      message: context.tr(
          'تعذّر تحميل مواقيت الصلاة', 'Couldn\'t load prayer times'),
      action: context.tr('إعادة المحاولة', 'Retry'),
      onAction: () => notifier.refresh(),
    );
  }
}

/// Fixed heights below keep the loading and loaded cards the same size.
const double _nextHeight = 76;
const double _cellHeight = 56;

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _countdown(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({
    required this.city,
    required this.today,
    required this.tomorrow,
    required this.now,
  });

  final String city;
  final DayPrayerTimes today;
  final DayPrayerTimes? tomorrow;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final arabic = context.isArabic;
    final next = nextPrayerOf(today, tomorrow, now);
    final hijri = today.hijri?.format(arabic);
    final remaining = next.remaining(now);
    final name = arabic ? next.kind.ar : next.kind.en;
    final countdown = _countdown(remaining);

    return AppCard(
      padding: const EdgeInsetsDirectional.all(AppSpacing.ms + 2),
      semanticLabel: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── City + Hijri date ──
          Row(
            children: [
              Icon(CupertinoIcons.location_solid, size: 14, color: c.accent),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  city.isEmpty ? context.tr('موقعك', 'Your location') : city,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.footnote
                      .copyWith(color: c.label, fontWeight: FontWeight.w600),
                ),
              ),
              if (hijri != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    hijri,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.footnote
                        .copyWith(color: c.secondaryLabel),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.ms),

          // ── Next prayer ──
          Semantics(
            container: true,
            label: context.tr(
                'الصلاة القادمة $name ${_hm(next.at)}، متبقي $countdown',
                'Next prayer $name at ${_hm(next.at)}, $countdown remaining'),
            excludeSemantics: true,
            child: Container(
              height: _nextHeight,
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.md),
              decoration: ShapeDecoration(
                color: c.accentTint,
                shape: AppRadius.continuous(AppRadius.medium),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('الصلاة القادمة', 'Next prayer'),
                          style: AppTypography.caption1
                              .copyWith(color: c.secondaryLabel),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            name,
                            style:
                                AppTypography.title2.copyWith(color: c.label),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _hm(next.at),
                        textDirection: TextDirection.ltr,
                        style: AppTypography.tabular(AppTypography.title2)
                            .copyWith(color: c.accent),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${context.tr('متبقي', 'in')} ',
                            style: AppTypography.footnote
                                .copyWith(color: c.secondaryLabel),
                          ),
                          Text(
                            countdown,
                            textDirection: TextDirection.ltr,
                            style: AppTypography.tabular(AppTypography.footnote)
                                .copyWith(color: c.secondaryLabel),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── The six times ──
          Row(
            children: [
              for (final k in PrayerKind.values)
                Expanded(
                  child: _TimeCell(
                    name: arabic ? k.ar : k.en,
                    time: _hm(today[k]),
                    state: next.tomorrow || today[k].isBefore(now)
                        ? _CellState.passed
                        : k == next.kind
                            ? _CellState.next
                            : _CellState.upcoming,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _CellState { passed, next, upcoming }

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.name,
    required this.time,
    required this.state,
  });

  final String name;
  final String time;
  final _CellState state;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final isNext = state == _CellState.next;
    final nameColor = isNext ? c.accent : c.secondaryLabel;
    final timeColor = isNext ? c.accent : c.label;
    return Opacity(
      opacity: state == _CellState.passed ? 0.45 : 1,
      child: Container(
        height: _cellHeight,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: isNext
            ? ShapeDecoration(
                color: c.accentTint,
                shape: AppRadius.continuous(AppRadius.small),
              )
            : null,
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  style: AppTypography.caption1.copyWith(
                      color: nameColor,
                      fontWeight: isNext ? FontWeight.w600 : null)),
              Text(time,
                  textDirection: TextDirection.ltr,
                  style: AppTypography.tabular(AppTypography.footnote).copyWith(
                      color: timeColor,
                      fontWeight: isNext ? FontWeight.w700 : FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Same footprint as the loaded card, with a gentle pulse.
class _PrayerSkeleton extends StatefulWidget {
  const _PrayerSkeleton();

  @override
  State<_PrayerSkeleton> createState() => _PrayerSkeletonState();
}

class _PrayerSkeletonState extends State<_PrayerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    Widget bar(double height, {double? width, double radius = 6}) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: c.fill,
            borderRadius: BorderRadius.circular(radius),
          ),
        );
    return Semantics(
      label: context.tr('جارٍ تحميل مواقيت الصلاة', 'Loading prayer times'),
      child: ExcludeSemantics(
        child: AppCard(
          padding: const EdgeInsetsDirectional.all(AppSpacing.ms + 2),
          child: FadeTransition(
            opacity: Tween(begin: 0.45, end: 1.0).animate(_pulse),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [bar(14, width: 90), bar(14, width: 110)],
                ),
                const SizedBox(height: AppSpacing.ms),
                bar(_nextHeight, radius: AppRadius.medium),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: _cellHeight,
                  child: Row(
                    children: [
                      for (var i = 0; i < 6; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 2, vertical: 6),
                            child:
                                bar(double.infinity, radius: AppRadius.small),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.message,
    required this.action,
    required this.onAction,
    this.secondaryAction,
    this.onSecondary,
  });

  final IconData icon;
  final String message;
  final String action;
  final VoidCallback onAction;
  final String? secondaryAction;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return AppCard(
      padding: const EdgeInsetsDirectional.all(AppSpacing.ms + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: c.secondaryLabel),
              const SizedBox(width: AppSpacing.ms),
              Expanded(
                child: Text(message,
                    style: AppTypography.subheadline.copyWith(color: c.label)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.ms),
          Row(
            children: [
              Expanded(
                child: AppButton.tinted(
                    label: action, small: true, onPressed: onAction),
              ),
              if (secondaryAction != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton.plain(
                      label: secondaryAction!,
                      small: true,
                      onPressed: onSecondary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
