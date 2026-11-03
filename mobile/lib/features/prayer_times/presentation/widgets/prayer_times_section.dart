import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../fajr_call/data/location_service.dart';
import '../../../fajr_call/presentation/fajr_call_providers.dart';
import '../../../fajr_call/presentation/widgets/fajr_call_labels.dart';
import '../../../fajr_call/presentation/widgets/prayer_settings_sheet.dart';
import '../../domain/prayer_times.dart';
import '../prayer_times_providers.dart';
import 'prayer_hero.dart';
import 'prayer_lanterns.dart';
import 'prayer_painters.dart';

/// Top of Home: a gold frame holding the hero (title, greeting, adhan and
/// city chips over a sky that follows the day) and a card with the next
/// prayer's countdown ring and the Hijri and Gregorian dates; under it, the
/// day's six times. Falls back to a skeleton, an inline "enable location"
/// prompt, or a retry card; it never blocks the rest of Home.
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

    Future<void> pickCity() async {
      await PrayerSettingsSheet.show(context);
      notifier.refresh();
    }

    final Widget card;
    Widget? strip;
    if (today != null) {
      final next = nextPrayerOf(today, state.tomorrow, _now);
      card = _CountdownCard(today: today, next: next, now: _now);
      strip = _PrayerStrip(
        today: today,
        highlight: next.tomorrow ? null : next.kind,
      );
    } else if (state.loading) {
      card = const _SkeletonCard();
      strip = const _SkeletonStrip();
    } else if (state.location == null) {
      final noFix = state.locationFailure == LocationFailure.unavailable;
      card = _MessageCard(
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
        onSecondary: pickCity,
      );
    } else {
      card = _MessageCard(
        icon: CupertinoIcons.wifi_slash,
        message: context.tr(
            'تعذّر تحميل مواقيت الصلاة', 'Couldn\'t load prayer times'),
        action: context.tr('إعادة المحاولة', 'Retry'),
        onAction: () => notifier.refresh(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PrayerFrame(
          hero: PrayerHero(
            city: state.location?.city ?? '',
            current: currentPrayerOf(today, _now),
            onPickCity: pickCity,
          ),
          child: card,
        ),
        if (strip != null) ...[
          const SizedBox(height: AppSpacing.ms),
          strip,
        ],
      ],
    );
  }
}

const double _frameRadius = 28;
const double _cardRadius = 24;

/// How far the hero's ground runs down beside the card before fading out.
const double _groundRunoff = 44;

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _two(int n) => n.toString().padLeft(2, '0');

String _countdown(Duration d) =>
    '${_two(d.inHours)}:${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}';

IconData _iconOf(PrayerKind k) => switch (k) {
      PrayerKind.fajr => CupertinoIcons.sun_haze_fill,
      PrayerKind.sunrise => CupertinoIcons.sunrise_fill,
      PrayerKind.dhuhr => CupertinoIcons.sun_max_fill,
      PrayerKind.asr => CupertinoIcons.sun_min_fill,
      PrayerKind.maghrib => CupertinoIcons.sunset_fill,
      PrayerKind.isha => CupertinoIcons.moon_fill,
    };

/// The gold frame: [hero] on top, then [child] in front of the hero's
/// ground, which runs on beside it and fades into the frame.
class _PrayerFrame extends StatelessWidget {
  const _PrayerFrame({required this.hero, required this.child});

  final Widget hero;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final frame = c.resolve(AppColors.prayerFrame);
    return Container(
      decoration: ShapeDecoration(
        color: frame,
        shape: AppRadius.continuous(_frameRadius),
        shadows: [
          BoxShadow(
            color: c.shadow(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      foregroundDecoration: ShapeDecoration(
        shape: AppRadius.continuous(
          _frameRadius,
          side: BorderSide(color: c.resolve(AppColors.prayerGold), width: 1.5),
        ),
      ),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(_frameRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hero,
            Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _groundRunoff,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.prayerSilhouette, frame],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.ms, 0, AppSpacing.ms, AppSpacing.ms),
                  child: child,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The white card inside the frame, with Ramadan lanterns hanging from its
/// top corners.
class _CardSurface extends StatelessWidget {
  const _CardSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final gold = c.resolve(AppColors.prayerGold);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: c.secondaryGroupedBackground,
        shape: AppRadius.continuous(_cardRadius),
        shadows: [
          BoxShadow(
            color: c.shadow(0.3),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(_cardRadius),
        child: PrayerLanterns(
          gold: gold,
          glow: c.isDark ? 0.45 : 0.3,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md, AppSpacing.ml, AppSpacing.md, AppSpacing.md),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Ring diameter for a card [width] wide.
double _ringSize(double width) => math.min(216, width * 0.66);

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({
    required this.today,
    required this.next,
    required this.now,
  });

  final DayPrayerTimes today;
  final NextPrayer next;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final arabic = context.isArabic;
    final green = c.resolve(AppColors.prayerGreen);
    final prev = previousPrayerOf(today, next);
    final progress = elapsedBetween(prev.at, next.at, now);
    final name = arabic ? next.kind.ar : next.kind.en;
    final countdown = _countdown(next.remaining(now));
    final hijri = today.hijri?.format(arabic);
    final date = today.date;

    return _CardSurface(
      child: Column(
        children: [
          Semantics(
            container: true,
            label: context.tr(
                'الصلاة القادمة $name ${_hm(next.at)}، متبقي $countdown',
                'Next prayer $name at ${_hm(next.at)}, $countdown remaining'),
            excludeSemantics: true,
            child: LayoutBuilder(
              builder: (context, box) => _CountdownRing(
                size: _ringSize(box.maxWidth),
                progress: progress,
                name: name,
                remaining: next.remaining(now),
                at: _hm(next.at),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.ms),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: AppGoldRule(),
          ),
          const SizedBox(height: AppSpacing.ms),
          if (hijri != null)
            Text(
              hijri,
              textAlign: TextAlign.center,
              style: AppTypography.headline
                  .weight(FontWeight.w700)
                  .copyWith(color: green),
            ),
          Text(
            '${weekdayName(context, date.weekday)} ${formatDate(context, date)}'
            '${arabic ? ' م' : ''}',
            textAlign: TextAlign.center,
            style: AppTypography.footnote.copyWith(color: c.secondaryLabel),
          ),
        ],
      ),
    );
  }
}

/// The ring with the next prayer's name, a live countdown and its time.
/// The arc sweeps in once when it first appears.
class _CountdownRing extends StatefulWidget {
  const _CountdownRing({
    required this.size,
    required this.progress,
    required this.name,
    required this.remaining,
    required this.at,
  });

  final double size;
  final double progress;
  final String name;
  final Duration remaining;
  final String at;

  @override
  State<_CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<_CountdownRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.value = 1;
    } else if (_sweep.isDismissed) {
      _sweep.forward();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final green = c.resolve(AppColors.prayerGreen);
    final gold = c.resolve(AppColors.prayerGold);
    final r = widget.remaining;
    final digits = AppTypography.tabular(AppTypography.largeTitle)
        .copyWith(color: c.resolve(AppColors.prayerInk), height: 1.1);
    final colon = Text(':', style: digits.copyWith(color: gold));

    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (context, child) => CustomPaint(
          painter: PrayerRingPainter(
            progress:
                widget.progress * Curves.easeOutCubic.transform(_sweep.value),
            color: green,
            track: c.resolve(AppColors.prayerTrack),
            knob: gold,
            rim: c.secondaryGroupedBackground,
            shadow: c.shadow(0.6),
          ),
          child: child,
        ),
        child: Padding(
          padding: EdgeInsets.all(widget.size * 0.17),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.name,
                    style: AppTypography.title2.copyWith(color: green)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.ltr,
                  children: [
                    Text(_two(r.inHours), style: digits),
                    colon,
                    Text(_two(r.inMinutes % 60), style: digits),
                    colon,
                    Text(_two(r.inSeconds % 60), style: digits),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.md - 2, vertical: AppSpacing.xs),
                  decoration: ShapeDecoration(
                    color: c.resolve(AppColors.prayerGreenFill),
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.bell_fill, size: 14, color: gold),
                      const SizedBox(width: AppSpacing.xs + 2),
                      Text(
                        widget.at,
                        textDirection: TextDirection.ltr,
                        style: AppTypography.tabular(AppTypography.headline)
                            .weight(FontWeight.w700)
                            .copyWith(color: CupertinoColors.white),
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

/// The day's six times in a row; [highlight] (the next prayer) is a green
/// tile.
class _PrayerStrip extends StatelessWidget {
  const _PrayerStrip({required this.today, required this.highlight});

  final DayPrayerTimes today;
  final PrayerKind? highlight;

  @override
  Widget build(BuildContext context) {
    final arabic = context.isArabic;
    return _StripSurface(
      child: Row(
        children: [
          for (final k in PrayerKind.values)
            Expanded(
              child: _PrayerTile(
                icon: _iconOf(k),
                name: arabic ? k.ar : k.en,
                time: _hm(today[k]),
                next: k == highlight,
              ),
            ),
        ],
      ),
    );
  }
}

class _StripSurface extends StatelessWidget {
  const _StripSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs + 2),
      decoration: ShapeDecoration(
        color: c.secondaryGroupedBackground,
        shape: AppRadius.continuous(
          _cardRadius - 2,
          side: BorderSide(
              color: c.resolve(AppColors.prayerGold).withValues(alpha: 0.3)),
        ),
        shadows: [
          BoxShadow(
            color: c.shadow(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PrayerTile extends StatelessWidget {
  const _PrayerTile({
    required this.icon,
    required this.name,
    required this.time,
    required this.next,
  });

  final IconData icon;
  final String name;
  final String time;
  final bool next;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final gold = c.resolve(AppColors.prayerGold);
    final fill = c.resolve(AppColors.prayerGreenFill);
    return Semantics(
      selected: next,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
        decoration: next
            ? ShapeDecoration(
                color: fill,
                shape: AppRadius.continuous(AppRadius.large),
                shadows: [
                  BoxShadow(
                    color: fill.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              )
            : null,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: gold),
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                name,
                style: AppTypography.caption1.copyWith(
                    color: next
                        ? CupertinoColors.white.withValues(alpha: 0.85)
                        : c.secondaryLabel),
              ),
              Text(
                time,
                textDirection: TextDirection.ltr,
                style: AppTypography.tabular(AppTypography.subheadline)
                    .weight(FontWeight.w700)
                    .copyWith(
                        color: next
                            ? CupertinoColors.white
                            : c.resolve(AppColors.prayerInk)),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Always laid out, so every tile is the same height.
              Container(
                width: 5,
                height: 5,
                decoration: ShapeDecoration(
                  color: next ? gold : null,
                  shape: const CircleBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades its child in and out while the times load.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
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
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(_pulse),
        child: widget.child,
      );
}

Widget _bar(BuildContext context, double height,
        {double? width, double radius = 6}) =>
    Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.palette.fill,
        borderRadius: BorderRadius.circular(radius),
      ),
    );

/// The countdown card's footprint, with an empty ring.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.tr('جارٍ تحميل مواقيت الصلاة', 'Loading prayer times'),
      child: ExcludeSemantics(
        child: _CardSurface(
          child: _Pulse(
            child: Column(
              children: [
                LayoutBuilder(builder: (context, box) {
                  final size = _ringSize(box.maxWidth);
                  return SizedBox.square(
                    dimension: size,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          shape: CircleBorder(
                            side: BorderSide(
                                color: context.palette.fill, width: 12),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.ms),
                _bar(context, 12, width: 110),
                const SizedBox(height: AppSpacing.lg),
                _bar(context, 16, width: 150),
                const SizedBox(height: AppSpacing.sm),
                _bar(context, 12, width: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonStrip extends StatelessWidget {
  const _SkeletonStrip();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: _StripSurface(
          child: _Pulse(
            child: SizedBox(
              height: 84,
              child: Row(
                children: [
                  for (var i = 0; i < 6; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 4),
                        child: _bar(context, double.infinity,
                            radius: AppRadius.medium),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
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
    return _CardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: c.resolve(AppColors.prayerGreen)),
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
