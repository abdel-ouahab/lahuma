import 'dart:math' as math;

import '../../../../../core/design/design.dart';
import '../../../../../core/localization/tr.dart';
import '../../../../splash/splash_screen.dart' show SplashLayout;
import 'art_timeline.dart';

/// Page 1: the intention. The wordmark inside the gold star (drawn from its
/// corners, as on the splash), soft rays turning slowly behind it, and the
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

  @override
  Duration get ambientLength => const Duration(seconds: 60);

  late final Animation<double> _draw = segment(0, 900, Curves.easeInOutCubic);
  late final Animation<double> _mark = segment(300, 900);
  late final Animation<double> _count = segment(700, 2400);
  late final Animation<double> _counterIn = segment(600, 1000);

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    // Green ink on ivory; at night the gold carries it.
    final ink = c.isDark ? c.gold : c.accent;
    const center = Offset(150, 108);
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _RaysPainter(
              turn: ambient,
              center: center,
              color: c.gold.withValues(alpha: c.isDark ? 0.12 : 0.16),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _CenteredStar(
              DrawnStarPainter(progress: _draw, color: c.gold, radius: 96),
              center,
            ),
          ),
        ),
        Positioned(
          left: center.dx - 58,
          top: center.dy - 58 * SplashLayout.wordmarkAspect,
          child: FadeTransition(
            opacity: _mark,
            child: Image.asset(
              SplashLayout.wordmarkAsset,
              width: 116,
              height: 116 * SplashLayout.wordmarkAspect,
              color: ink,
              colorBlendMode: BlendMode.srcIn,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 218,
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

/// Paints [star] centred on [center] instead of on the box.
class _CenteredStar extends CustomPainter {
  _CenteredStar(this.star, this.center) : super(repaint: star.progress);

  final DrawnStarPainter star;
  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    final side = star.radius * 2.4;
    canvas.save();
    canvas.translate(center.dx - side / 2, center.dy - side / 2);
    star.paint(canvas, Size.square(side));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CenteredStar old) => star.shouldRepaint(old.star);
}

/// Sixteen soft rays from [center], fading outwards, turning once a
/// minute with [turn].
class _RaysPainter extends CustomPainter {
  _RaysPainter({
    required this.turn,
    required this.center,
    required this.color,
  }) : super(repaint: turn);

  final Animation<double> turn;
  final Offset center;
  final Color color;

  static const int _rays = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final reach = size.longestSide * 0.62;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
        stops: const [0.25, 1],
      ).createShader(Rect.fromCircle(center: center, radius: reach));
    final rotation = turn.value * 2 * math.pi;
    const half = math.pi / _rays / 3;
    for (var i = 0; i < _rays; i++) {
      final a = rotation + i * 2 * math.pi / _rays;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(center.dx + math.cos(a - half) * reach,
              center.dy + math.sin(a - half) * reach)
          ..lineTo(center.dx + math.cos(a + half) * reach,
              center.dy + math.sin(a + half) * reach)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) =>
      old.color != color || old.center != center || old.turn != turn;
}
