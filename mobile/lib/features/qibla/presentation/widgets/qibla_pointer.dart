import '../../../../core/design/design.dart';

/// The fixed marker above the dial: where the top of the phone points.
/// Fades between colours when [color] changes (accent → green on alignment).
class QiblaPointer extends StatelessWidget {
  const QiblaPointer({
    super.key,
    required this.color,
    this.width = 22,
    this.height = 14,
  });

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final shadow = context.palette.shadow(0.5);
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: AppMotion.of(context),
      builder: (context, value, _) => CustomPaint(
        size: Size(width, height),
        painter: _PointerPainter(color: value ?? color, shadow: shadow),
      ),
    );
  }
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter({required this.color, required this.shadow});

  final Color color;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // A downward triangle with softened corners.
    final path = Path()
      ..moveTo(w * 0.12, 0)
      ..quadraticBezierTo(0, 0, w * 0.08, h * 0.16)
      ..lineTo(w * 0.42, h * 0.92)
      ..quadraticBezierTo(w * 0.5, h * 1.06, w * 0.58, h * 0.92)
      ..lineTo(w * 0.92, h * 0.16)
      ..quadraticBezierTo(w, 0, w * 0.88, 0)
      ..close();
    canvas.drawPath(
      path.shift(const Offset(0, 1.5)),
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, AppColors.onAccent, 0.25)!, color],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_PointerPainter old) =>
      old.color != color || old.shadow != shadow;
}
