import '../../../../../core/design/design.dart';
import '../../../../../core/localization/tr.dart';
import '../../../../tasbih/domain/tasbih.dart';
import '../../../../tasbih/presentation/widgets/beads_painter.dart';
import '../../../../tasbih/presentation/widgets/counter_display.dart';
import 'art_timeline.dart';

/// Page 6: remembrance. The tasbih's own beads and counter: one bead slides
/// along the string, then another, and the count reaches 33; below, the
/// morning adhkar card fills to where today's reading has got.
class RemembranceArt extends OnboardingArtWidget {
  const RemembranceArt({super.key, required super.active});

  static const Size size = Size(300, 280);

  @override
  State<RemembranceArt> createState() => _RemembranceArtState();
}

class _RemembranceArtState extends OnboardingArtState<RemembranceArt> {
  @override
  Duration get length => const Duration(milliseconds: 2400);

  /// سبحان الله, 33 times: the tasbih's first preset.
  static final TasbihDhikr _dhikr = tasbihPresets.first;
  static const _misbaha = Size(176, 188);

  /// Beads on the counted side: 31, then one bead across, then another.
  late final Animation<double> _counted = timeline.drive(TweenSequence([
    TweenSequenceItem(tween: ConstantTween(31), weight: 500),
    TweenSequenceItem(
        tween: Tween(begin: 31.0, end: 32.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 300),
    TweenSequenceItem(tween: ConstantTween(32), weight: 600),
    TweenSequenceItem(
        tween: Tween(begin: 32.0, end: 33.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 300),
    TweenSequenceItem(tween: ConstantTween(33), weight: 700),
  ]));

  /// The tassel's push for each bead.
  late final Animation<double> _swing = timeline.drive(TweenSequence([
    TweenSequenceItem(tween: ConstantTween(0), weight: 500),
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 900),
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1000),
  ]));

  late final Animation<double> _adhkar = segment(600, 1500);

  MisbahaGeometry? _geometry;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final mirror = Directionality.of(context) == TextDirection.ltr;
    var g = _geometry;
    if (g == null || g.mirrored != mirror) {
      g = _geometry = MisbahaGeometry(_misbaha, mirror: mirror);
    }
    final inner = g.innerRadius;
    return Column(
      children: [
        SizedBox.fromSize(
          size: _misbaha,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: BeadsPainter(
                    geometry: g,
                    counted: _counted,
                    swing: _swing,
                    swingDirection: 1,
                    colors: beadColorsOf(BeadMaterial.amber),
                    shadow: beadShadowOf(c),
                    dark: c.isDark,
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: Rect.fromCircle(center: g.center, radius: inner),
                child: AnimatedBuilder(
                  animation: _counted,
                  builder: (context, _) => CounterDisplay(
                    dhikr: _dhikr,
                    // The count changes as each bead lands.
                    count: _counted.value.round(),
                    diameter: inner * 2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.ms),
        AnimatedBuilder(
          animation: _adhkar,
          builder: (context, _) =>
              _AdhkarCard(done: (8 * _adhkar.value).round(), total: 12),
        ),
      ],
    );
  }
}

/// The morning adhkar's card, as on Home: its tile, name and progress.
class _AdhkarCard extends StatelessWidget {
  const _AdhkarCard({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Container(
      width: 300,
      height: 64,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
      decoration: ShapeDecoration(
        color: c.secondaryGroupedBackground,
        shape: AppRadius.continuous(AppRadius.medium,
            side: BorderSide(color: c.separator, width: AppSpacing.hairline)),
      ),
      child: Row(
        children: [
          const AppIconTile(
              icon: CupertinoIcons.sun_max_fill, color: AppColors.tileOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('أذكار الصباح', 'Morning adhkar'),
                        style: AppTypography.subheadline
                            .weight(FontWeight.w600)
                            .copyWith(color: c.label),
                      ),
                    ),
                    LtrText(
                      '$done / $total',
                      style: AppTypography.tabular(AppTypography.caption1)
                          .copyWith(color: c.secondaryLabel),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AppProgressBar(value: done / total),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
