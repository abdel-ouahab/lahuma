import '../../../../../core/design/design.dart';
import '../../../../../core/localization/tr.dart';
import '../../../../khatma/domain/quran_pages.dart';
import '../../../../khatma/presentation/widgets/khatma_ring.dart';
import 'art_timeline.dart';

/// Page 3: the khatma. The real juz ring filling to the end of the twelfth
/// juz, the week with each day's wird ticked in and today ringed in gold,
/// and the streak.
class KhatmaArt extends OnboardingArtWidget {
  const KhatmaArt({super.key, required super.active});

  static const Size size = Size(300, 280);

  static const int juz = 12;

  /// The days already done this week; the next one is today.
  static const int doneDays = 5;

  @override
  State<KhatmaArt> createState() => _KhatmaArtState();
}

class _KhatmaArtState extends OnboardingArtState<KhatmaArt> {
  @override
  Duration get length => const Duration(milliseconds: 2400);

  late final Animation<double> _fill = segment(0, 1600, Curves.easeInOutCubic);
  late final Animation<double> _streak = segment(1700, 2200);

  /// Each day of the week ticking in, one after another.
  late final List<Animation<double>> _days = [
    for (var i = 0; i < 7; i++) segment(500 + i * 140, 800 + i * 140),
  ];

  /// The last page of juz [KhatmaArt.juz]: the page before the next juz's
  /// first hizb.
  static final int _lastPage =
      QuranPages.hizbStartPage(KhatmaArt.juz * 2 + 1) - 1;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Column(
      children: [
        AnimatedBuilder(
          animation: _fill,
          builder: (context, _) {
            final page = (_lastPage * _fill.value).round();
            final juz = (KhatmaArt.juz * _fill.value).floor();
            return KhatmaRing(
              lastPageRead: page,
              size: 148,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LtrText(
                    '$juz',
                    style: AppTypography.tabular(AppTypography.title1)
                        .copyWith(color: c.label, height: 1.1),
                  ),
                  Text(
                    context.tr('من ${ltr('${QuranPages.juzCount}')} جزءًا',
                        'of ${QuranPages.juzCount} juz'),
                    style: AppTypography.caption1
                        .copyWith(color: c.secondaryLabel),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _Week(days: _days),
        const SizedBox(height: AppSpacing.ms),
        FadeTransition(
          opacity: _streak,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.flame_fill,
                  size: 18, color: c.resolve(AppColors.tileOrange)),
              const SizedBox(width: AppSpacing.xs),
              Text(
                context.tr('${ltr('${KhatmaArt.doneDays}')} أيام متتالية',
                    '${KhatmaArt.doneDays}-day streak'),
                style: AppTypography.footnote
                    .weight(FontWeight.w600)
                    .copyWith(color: c.label),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Saturday to Friday: the done days tick in one after another, today wears
/// the gold ring, the last day is still to come.
class _Week extends StatelessWidget {
  const _Week({required this.days});

  final List<Animation<double>> days;

  static const _ar = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];
  static const _en = ['S', 'S', 'M', 'T', 'W', 'T', 'F'];

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final names = context.isArabic ? _ar : _en;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 7; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              children: [
                Text(
                  names[i],
                  style: AppTypography.caption2
                      .copyWith(color: c.secondaryLabel, height: 1.4),
                ),
                const SizedBox(height: 3),
                _Day(
                  state: i < KhatmaArt.doneDays
                      ? _DayState.done
                      : i == KhatmaArt.doneDays
                          ? _DayState.today
                          : _DayState.later,
                  tick: days[i],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

enum _DayState { done, today, later }

class _Day extends StatelessWidget {
  const _Day({required this.state, required this.tick});

  final _DayState state;
  final Animation<double> tick;

  static const double _size = 28;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return AnimatedBuilder(
      animation: tick,
      builder: (context, _) {
        final t = tick.value;
        return Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: switch (state) {
              _DayState.done => Color.lerp(c.tertiaryFill, c.accent, t),
              _DayState.today => c.accentTint,
              _DayState.later => c.tertiaryFill,
            },
            border: state == _DayState.today
                ? Border.all(color: c.gold.withValues(alpha: t), width: 1.6)
                : null,
          ),
          child: switch (state) {
            _DayState.done => Opacity(
                opacity: t,
                child: Transform.scale(
                  scale: 0.6 + 0.4 * t,
                  child: const Icon(CupertinoIcons.checkmark_alt,
                      size: 16, color: AppColors.onAccent),
                ),
              ),
            _DayState.today => Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: c.accent, shape: BoxShape.circle),
                ),
              ),
            _DayState.later => null,
          },
        );
      },
    );
  }
}
