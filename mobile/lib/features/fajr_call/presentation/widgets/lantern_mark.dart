import 'dart:math' as math;
import '../../../../core/design/design.dart';

/// A small lantern drawn in code (no artwork), glowing over a crescent of
/// dawn. It floats gently; with Reduce Motion it stays still.
class LanternMark extends StatefulWidget {
  const LanternMark({super.key, this.size = 96});

  final double size;

  @override
  State<LanternMark> createState() => _LanternMarkState();
}

class _LanternMarkState extends State<LanternMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final glow = c.resolve(AppColors.tileOrange);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_controller.value);
          return SizedBox.square(
            dimension: widget.size,
            child: CustomPaint(
              painter: _LanternPainter(
                lift: t,
                frame: c.secondaryLabel,
                glass: glow,
                dawn: c.accent,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LanternPainter extends CustomPainter {
  _LanternPainter({
    required this.lift,
    required this.frame,
    required this.glass,
    required this.dawn,
  });

  /// 0…1: how far the lantern has floated up.
  final double lift;
  final Color frame;
  final Color glass;
  final Color dawn;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Dawn: a soft arc along the bottom.
    final horizon = Paint()
      ..shader = RadialGradient(
        colors: [dawn.withValues(alpha: 0.35), dawn.withValues(alpha: 0)],
      ).createShader(
          Rect.fromCircle(center: Offset(w / 2, h), radius: w * 0.6));
    canvas.drawCircle(Offset(w / 2, h), w * 0.6, horizon);

    canvas.save();
    canvas.translate(0, -h * 0.05 * lift);

    final cx = w / 2;
    final top = h * 0.12;
    final bodyTop = h * 0.32;
    final bodyBottom = h * 0.70;
    final bodyHalf = w * 0.17;

    // Glow behind the glass, breathing with the float.
    final glowPaint = Paint()
      ..shader = RadialGradient(colors: [
        glass.withValues(alpha: 0.45 + 0.15 * lift),
        glass.withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(
          center: Offset(cx, (bodyTop + bodyBottom) / 2), radius: w * 0.42));
    canvas.drawCircle(
        Offset(cx, (bodyTop + bodyBottom) / 2), w * 0.42, glowPaint);

    final stroke = Paint()
      ..color = frame
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, w * 0.025)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Hanging ring.
    canvas.drawCircle(Offset(cx, top), w * 0.045, stroke);

    // Dome cap.
    final cap = Path()
      ..moveTo(cx - bodyHalf * 1.15, bodyTop)
      ..quadraticBezierTo(cx, top - h * 0.02, cx + bodyHalf * 1.15, bodyTop)
      ..close();
    canvas.drawPath(cap, Paint()..color = frame.withValues(alpha: 0.25));
    canvas.drawPath(cap, stroke);

    // Glass body: a tall hexagon, filled warm.
    final body = Path()
      ..moveTo(cx - bodyHalf, bodyTop)
      ..lineTo(cx + bodyHalf, bodyTop)
      ..lineTo(cx + bodyHalf * 1.25, (bodyTop + bodyBottom) / 2)
      ..lineTo(cx + bodyHalf, bodyBottom)
      ..lineTo(cx - bodyHalf, bodyBottom)
      ..lineTo(cx - bodyHalf * 1.25, (bodyTop + bodyBottom) / 2)
      ..close();
    canvas.drawPath(body, Paint()..color = glass.withValues(alpha: 0.85));
    canvas.drawPath(body, stroke);

    // Flame.
    final flameCenter = Offset(cx, (bodyTop + bodyBottom) / 2 + h * 0.02);
    final flame = Path()
      ..moveTo(flameCenter.dx, flameCenter.dy - h * 0.09)
      ..quadraticBezierTo(flameCenter.dx + w * 0.06, flameCenter.dy,
          flameCenter.dx, flameCenter.dy + h * 0.05)
      ..quadraticBezierTo(flameCenter.dx - w * 0.06, flameCenter.dy,
          flameCenter.dx, flameCenter.dy - h * 0.09)
      ..close();
    canvas.drawPath(
        flame, Paint()..color = AppColors.onAccent.withValues(alpha: 0.9));

    // Vertical bars over the glass.
    canvas.drawLine(Offset(cx, bodyTop), Offset(cx, bodyBottom),
        stroke..strokeWidth = math.max(1, w * 0.012));

    // Base.
    final base = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, bodyBottom + h * 0.035),
          width: bodyHalf * 2.4,
          height: h * 0.06),
      Radius.circular(h * 0.02),
    );
    canvas.drawRRect(base, Paint()..color = frame.withValues(alpha: 0.35));

    canvas.restore();
  }

  @override
  bool shouldRepaint(_LanternPainter old) =>
      old.lift != lift ||
      old.frame != frame ||
      old.glass != glass ||
      old.dawn != dawn;
}
