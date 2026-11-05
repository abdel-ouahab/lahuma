import '../../../../../core/design/design.dart';
import 'art_timeline.dart';

/// The last step: the shamsa gathering once more, small, around the hilal,
/// closing the introduction the way the splash opened it.
class StartArt extends OnboardingArtWidget {
  const StartArt({super.key, required super.active});

  static const Size size = Size(180, 160);

  @override
  State<StartArt> createState() => _StartArtState();
}

class _StartArtState extends OnboardingArtState<StartArt> {
  @override
  Duration get length => const Duration(milliseconds: 1300);

  late final Animation<double> _trace = segment(0, 700, Curves.easeInOutCubic);
  late final Animation<double> _bloom = segment(300, 1100);
  late final Animation<double> _hilal = segment(600, 1300);

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: ShamsaPainter(
              trace: _trace,
              bloom: _bloom,
              color: c.gold,
              radius: 52,
            ),
          ),
        ),
        FadeTransition(
          opacity: _hilal,
          child: ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.0).animate(_hilal),
            child: CustomPaint(
              size: const Size.square(40),
              painter: HilalPainter(c.gold),
            ),
          ),
        ),
      ],
    );
  }
}
