import 'dart:async';
import 'dart:math' as math;

import '../../../../../core/design/design.dart';
import '../../../../../core/localization/tr.dart';
import '../../../../qibla/presentation/widgets/compass_dial.dart';
import 'art_timeline.dart';

/// Page 4: on time, facing the qibla. The real compass swings and settles on
/// the qibla (its rim glows when aligned), the countdown to the next prayer
/// ticks, and the day's prayers sit below with the next one filled.
class PrayerArt extends OnboardingArtWidget {
  const PrayerArt({super.key, required super.active});

  static const Size size = Size(300, 280);

  /// Roughly the qibla from North Africa.
  static const double qibla = 104;

  @override
  State<PrayerArt> createState() => _PrayerArtState();
}

class _PrayerArtState extends OnboardingArtState<PrayerArt> {
  @override
  Duration get length => const Duration(milliseconds: 2200);

  static const _countdownStart = Duration(hours: 1, minutes: 24, seconds: 10);

  late final Animation<double> _swing = segment(0, 1900, Curves.linear);
  late final Animation<double> _rowIn = segment(300, 900);

  /// Seconds the countdown has run. A once-a-second timer rather than an
  /// animation: nothing needs drawing between the ticks.
  int _elapsed = 0;
  Timer? _clock;

  @override
  void playingChanged(bool playing) {
    _clock?.cancel();
    _clock = playing
        ? Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() => _elapsed++);
          })
        : null;
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  /// A swing that dies away onto the qibla: from 95° short of it, twice
  /// across, then still.
  static double _heading(double t) =>
      PrayerArt.qibla -
      95 * math.exp(-3.2 * t) * math.cos(2 * math.pi * 1.3 * t);

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final left = _countdownStart - Duration(seconds: _elapsed);
    String two(int v) => v.toString().padLeft(2, '0');
    final clock =
        '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
    return Column(
      children: [
        AnimatedBuilder(
          animation: _swing,
          builder: (context, _) {
            final t = _swing.value;
            return CompassDial(
              size: 164,
              heading: _heading(t) % 360,
              qiblaBearing: PrayerArt.qibla,
              aligned: t > 0.9,
            );
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.tr('العصر بعد ${ltr(clock)}', 'Asr in $clock'),
          style: AppTypography.tabular(AppTypography.subheadline)
              .weight(FontWeight.w600)
              .copyWith(color: c.resolve(AppColors.prayerGreen)),
        ),
        const SizedBox(height: AppSpacing.ms),
        FadeTransition(
          opacity: _rowIn,
          child: const _PrayerRow(next: 2),
        ),
      ],
    );
  }
}

/// The day's five prayers; [next] is filled green.
class _PrayerRow extends StatelessWidget {
  const _PrayerRow({required this.next});

  final int next;

  static const _times = ['05:12', '12:47', '16:05', '18:31', '19:54'];

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final names = [
      context.tr('الفجر', 'Fajr'),
      context.tr('الظهر', 'Dhuhr'),
      context.tr('العصر', 'Asr'),
      context.tr('المغرب', 'Maghrib'),
      context.tr('العشاء', 'Isha'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 5; i++)
          Container(
            width: 54,
            height: 58,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: ShapeDecoration(
              color: i == next
                  ? c.resolve(AppColors.prayerGreenFill)
                  : c.secondaryGroupedBackground,
              shape: AppRadius.continuous(AppRadius.medium,
                  side: i == next
                      ? BorderSide(color: c.gold, width: 1)
                      : BorderSide(
                          color: c.separator, width: AppSpacing.hairline)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  names[i],
                  maxLines: 1,
                  style: AppTypography.caption2.copyWith(
                    color: i == next ? AppColors.onAccent : c.secondaryLabel,
                    height: 1.3,
                  ),
                ),
                LtrText(
                  _times[i],
                  style: AppTypography.tabular(AppTypography.footnote)
                      .weight(FontWeight.w600)
                      .copyWith(
                        color: i == next ? AppColors.onAccent : c.label,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
