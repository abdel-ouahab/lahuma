import '../../../../../core/design/design.dart';
import '../../../../../core/localization/tr.dart';
import '../../../../splash/splash_screen.dart' show SplashLayout;
import 'art_timeline.dart';

/// Page 1: the intention. The wordmark inside the shamsa (its ring tracing
/// itself and its rays opening, as on the splash) in a soft glow, and the
/// ayahs read for one's parents counting up.
class WelcomeArt extends OnboardingArtWidget {
  const WelcomeArt({super.key, required super.active});

  static const Size size = Size(300, 280);

  /// Al-Baqarah's ayahs: a whole surah read and gifted.
  static const int gifted = 286;

  @override
  State<WelcomeArt> createState() => _WelcomeArtState();
}

class _WelcomeArtState extends OnboardingArtState<WelcomeArt> {
  @override
  Duration get length => const Duration(milliseconds: 2400);

  late final Animation<double> _trace = segment(0, 700, Curves.easeInOutCubic);
  late final Animation<double> _bloom = segment(300, 1100);
  late final Animation<double> _mark = segment(300, 900);
  late final Animation<double> _count = segment(800, 2400);
  late final Animation<double> _counterIn = segment(700, 1100);

  static const Offset _center = Offset(150, 104);
  static const double _radius = 72;
  static const double _markWidth = 106;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    // Green ink on ivory; at night the gold carries it.
    final ink = c.isDark ? c.gold : c.accent;
    const reach = _radius * ShamsaPainter.reach;
    return Stack(
      children: [
        Positioned.fromRect(
          rect: Rect.fromCircle(center: _center, radius: reach + 24),
          child: FadeTransition(
            opacity: _trace,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  c.gold.withValues(alpha: c.isDark ? 0.14 : 0.18),
                  c.gold.withValues(alpha: 0),
                ]),
              ),
            ),
          ),
        ),
        Positioned.fromRect(
          rect: Rect.fromCircle(center: _center, radius: reach),
          child: CustomPaint(
            painter: ShamsaPainter(
              trace: _trace,
              bloom: _bloom,
              color: c.gold,
              radius: _radius,
            ),
          ),
        ),
        Positioned(
          left: _center.dx - _markWidth / 2,
          top: _center.dy - _markWidth / 2 * SplashLayout.wordmarkAspect,
          child: FadeTransition(
            opacity: _mark,
            child: Image.asset(
              SplashLayout.wordmarkAsset,
              width: _markWidth,
              height: _markWidth * SplashLayout.wordmarkAspect,
              color: ink,
              colorBlendMode: BlendMode.srcIn,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 216,
          child: FadeTransition(
            opacity: _counterIn,
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _count,
                  builder: (context, _) => LtrText(
                    '${(WelcomeArt.gifted * _count.value).round()}',
                    style: AppTypography.tabular(AppTypography.title2)
                        .copyWith(color: c.label, height: 1.1),
                  ),
                ),
                Text(
                  context.tr(
                      'آية تُهدى لوالديك', 'ayahs gifted to your parents'),
                  style:
                      AppTypography.footnote.copyWith(color: c.secondaryLabel),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
