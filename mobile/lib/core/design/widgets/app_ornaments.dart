import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import '../app_colors.dart';
import '../app_spacing.dart';

/// The rub el hizb: two squares, one turned 45°, around [center], the pair
/// rotated by [rotation]. Stroked it shows the interlace; filled it is an
/// eight-pointed star.
Path rubElHizb(Offset center, double radius, {double rotation = 0}) {
  final path = Path();
  for (final turn in const [0.0, math.pi / 4]) {
    final a = turn + rotation;
    path.addPolygon([
      for (var i = 0; i < 4; i++)
        center +
            Offset(math.cos(a + i * math.pi / 2),
                    math.sin(a + i * math.pi / 2)) *
                radius,
    ], true);
  }
  return path;
}

/// A crescent (hilal) of [radius] around [center], its horns pointing
/// along [facing] (radians, 0 = right, clockwise).
Path crescent(Offset center, double radius, double facing) {
  final dir = Offset(math.cos(facing), math.sin(facing));
  return Path.combine(
    PathOperation.difference,
    Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    Path()
      ..addOval(Rect.fromCircle(
          center: center + dir * radius * 0.42, radius: radius * 0.82)),
  );
}

/// Crescents tucked into a surface's corners, horns turned towards its
/// middle, inside two rings cut by the edge. The app's one ornament — on
/// hero surfaces only, never on every card.
class CrescentCornersPainter extends CustomPainter {
  const CrescentCornersPainter(
    this.color, {
    this.corners = const [Alignment.topLeft, Alignment.topRight],
    this.scale = 1,
  });

  final Color color;

  /// Which corners get a crescent.
  final List<Alignment> corners;

  /// 1 fits a card; larger for big hero surfaces.
  final double scale;

  static const double _inset = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fill = Paint()..color = color.withValues(alpha: color.a * 0.35);
    final inset = _inset * scale;
    for (final corner in corners) {
      final center = Offset(
        corner.x < 0 ? inset : size.width - inset,
        corner.y < 0 ? inset : size.height - inset,
      );
      // Towards the surface's middle, i.e. away from this corner.
      final facing = math.atan2(-corner.y, -corner.x);
      final moon = crescent(center, 18 * scale, facing);
      canvas
        ..drawPath(moon, fill)
        ..drawPath(moon, line)
        ..drawCircle(center, 30 * scale, line)
        ..drawCircle(center, 38 * scale, line..strokeWidth = 0.6);
      line.strokeWidth = 1;
    }
  }

  @override
  bool shouldRepaint(CrescentCornersPainter old) =>
      old.color != color || old.corners != corners || old.scale != scale;
}

/// A five-pointed star of [radius] around [center], one point straight up.
Path fivePointStar(Offset center, double radius) {
  final inner = radius * 0.4;
  return Path()
    ..addPolygon([
      for (var i = 0; i < 10; i++)
        center +
            Offset(math.cos(-math.pi / 2 + i * math.pi / 5),
                    math.sin(-math.pi / 2 + i * math.pi / 5)) *
                (i.isEven ? radius : inner),
    ], true);
}

/// The hilal: a crescent of [radius] around [center], horns up, gilded
/// from a lit edge to a shaded one and outlined in [gold], with an engraved
/// line along its outer curve and a five-pointed star between its horns.
void paintHilal(Canvas canvas, Offset center, double radius, Color gold) {
  final moon = crescent(center, radius, -math.pi / 2);
  final bounds = moon.getBounds();
  final lit = Color.lerp(gold, CupertinoColors.white, 0.5)!;
  canvas
    ..drawPath(
      moon,
      Paint()
        ..shader = ui.Gradient.linear(bounds.topLeft, bounds.bottomRight, [
          lit.withValues(alpha: 0.75),
          gold.withValues(alpha: 0.45),
        ]),
    )
    ..drawPath(
      moon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = gold,
    )
    ..save()
    ..clipPath(moon)
    ..drawCircle(
      center,
      radius - radius * 0.13,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = gold.withValues(alpha: 0.7),
    )
    ..restore()
    ..drawPath(
      fivePointStar(center - Offset(0, radius * 0.52), radius * 0.29),
      Paint()..color = gold,
    );
}

/// [paintHilal] filling its box.
class HilalPainter extends CustomPainter {
  const HilalPainter(this.gold);

  final Color gold;

  @override
  void paint(Canvas canvas, Size size) =>
      paintHilal(canvas, size.center(Offset.zero), size.shortestSide / 2, gold);

  @override
  bool shouldRepaint(HilalPainter old) => old.gold != gold;
}

/// A small filled star: eight-pointed by default, or five-pointed.
class StarPainter extends CustomPainter {
  const StarPainter(this.color, {this.points = 8});

  final Color color;

  /// 8 (the rub el hizb) or 5.
  final int points;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawPath(
        points == 5 ? fivePointStar(center, radius) : rubElHizb(center, radius),
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(StarPainter old) =>
      old.color != color || old.points != points;
}

/// A gold hairline fading out to both sides, with a star at its centre.
/// Separates the parts of one surface; not a section divider.
class AppGoldRule extends StatelessWidget {
  const AppGoldRule({super.key, this.color});

  /// Defaults to [AppColors.gold].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final gold =
        color ?? CupertinoDynamicColor.resolve(AppColors.gold, context);
    Widget line(List<Color> colors) => Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
          ),
        );
    return Row(
      textDirection: TextDirection.ltr,
      children: [
        line([gold.withValues(alpha: 0), gold]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: CustomPaint(
            size: const Size.square(11),
            painter: StarPainter(gold),
          ),
        ),
        line([gold, gold.withValues(alpha: 0)]),
      ],
    );
  }
}
