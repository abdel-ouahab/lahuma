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

/// The eight-pointed star as one outline (the union of the rub el hizb's
/// two squares) of [radius] around [center], one point straight up.
Path eightPointStar(Offset center, double radius) {
  final inner = radius * math.cos(math.pi / 4) / math.cos(math.pi / 8);
  return Path()
    ..addPolygon([
      for (var i = 0; i < 16; i++)
        center +
            Offset(math.cos(-math.pi / 2 + i * math.pi / 8),
                    math.sin(-math.pi / 2 + i * math.pi / 8)) *
                (i.isEven ? radius : inner),
    ], true);
}

/// A star-and-cross lattice: eight-pointed stars on a square grid, each
/// touching its neighbours point to point, the crosses between them left
/// open. Centred on the box so it sits the same way in both directions. A
/// texture for splash and introduction backgrounds: give it a faint
/// [color] and a RepaintBoundary, since it never changes.
class StarLatticePainter extends CustomPainter {
  const StarLatticePainter(this.color, {this.spacing = 56});

  final Color color;

  /// Distance between star centres.
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final center = size.center(Offset.zero);
    final columns = (size.width / spacing / 2).ceil() + 1;
    final rows = (size.height / spacing / 2).ceil() + 1;
    for (var x = -columns; x <= columns; x++) {
      for (var y = -rows; y <= rows; y++) {
        canvas.drawPath(
          eightPointStar(
              center + Offset(x * spacing, y * spacing), spacing / 2),
          line,
        );
      }
    }
  }

  @override
  bool shouldRepaint(StarLatticePainter old) =>
      old.color != color || old.spacing != spacing;
}

/// The rub el hizb drawing itself: from each of its eight corners a line
/// runs along both sides, the lines meeting mid-side when [progress]
/// reaches 1; the corners show as dots from the start, where the pen
/// touches down. [scale] grows or shrinks it about the box's centre.
class DrawnStarPainter extends CustomPainter {
  DrawnStarPainter({
    required this.progress,
    required this.color,
    required this.radius,
    Animation<double>? scale,
    this.strokeWidth = 1.4,
  })  : scale = scale ?? const AlwaysStoppedAnimation(1),
        super(repaint: Listenable.merge([progress, scale]));

  final Animation<double> progress;
  final Animation<double> scale;
  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value.clamp(0.0, 1.0);
    if (t == 0) return;
    final center = size.center(Offset.zero);
    final r = radius * scale.value;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final dot = Paint()
      ..color = color.withValues(alpha: color.a * math.min(1, t * 4));
    final path = Path();
    for (final turn in const [-math.pi / 2, -math.pi / 4]) {
      final corners = [
        for (var i = 0; i < 4; i++)
          center +
              Offset(math.cos(turn + i * math.pi / 2),
                      math.sin(turn + i * math.pi / 2)) *
                  r,
      ];
      for (var i = 0; i < 4; i++) {
        final a = corners[i];
        final b = corners[(i + 1) % 4];
        final mid = Offset.lerp(a, b, 0.5)!;
        path
          ..moveTo(a.dx, a.dy)
          ..lineTo(Offset.lerp(a, mid, t)!.dx, Offset.lerp(a, mid, t)!.dy)
          ..moveTo(b.dx, b.dy)
          ..lineTo(Offset.lerp(b, mid, t)!.dx, Offset.lerp(b, mid, t)!.dy);
        canvas.drawCircle(a, strokeWidth * 1.3, dot);
      }
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(DrawnStarPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.progress != progress ||
      old.scale != scale;
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

/// A Maghrebi horseshoe arch filling [size], [inset] in from its edges: a
/// crown as wide as the arch whose arc runs [horseshoe] radians past its
/// half-circle before dropping into straight jambs, so the opening is
/// narrower than the arch.
Path horseshoeArch(Size size, double inset,
    {double horseshoe = 30 * math.pi / 180}) {
  final r = size.width / 2 - inset;
  final center = Offset(size.width / 2, size.width / 2);
  final springX = r * math.cos(horseshoe);
  final bottom = size.height - inset;
  return Path()
    ..moveTo(center.dx - springX, bottom)
    ..lineTo(center.dx - springX, center.dy + r * math.sin(horseshoe))
    ..arcTo(Rect.fromCircle(center: center, radius: r), math.pi - horseshoe,
        math.pi + 2 * horseshoe, false)
    ..lineTo(center.dx + springX, bottom)
    ..close();
}

/// The corners of a Mushaf page's frame: a double rule turning each
/// corner, a small lozenge in the angle and a dot at each end of the outer
/// rule. For surfaces about reading the Quran.
class FrameCornersPainter extends CustomPainter {
  const FrameCornersPainter(
    this.color, {
    this.corners = const [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ],
  });

  final Color color;

  /// Which corners get a frame corner.
  final List<Alignment> corners;

  static const double _inset = 12;
  static const double _arm = 46;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final inner = Paint()
      ..color = color.withValues(alpha: color.a * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final fill = Paint()..color = color;
    for (final corner in corners) {
      // Unit steps from the corner towards the surface's middle.
      final dx = corner.x < 0 ? 1.0 : -1.0;
      final dy = corner.y < 0 ? 1.0 : -1.0;
      Path rule(Offset at, double arm) => Path()
        ..moveTo(at.dx + arm * dx, at.dy)
        ..lineTo(at.dx, at.dy)
        ..lineTo(at.dx, at.dy + arm * dy);
      final p = Offset(
        corner.x < 0 ? _inset : size.width - _inset,
        corner.y < 0 ? _inset : size.height - _inset,
      );
      final q = p + Offset(_gap * dx, _gap * dy);
      final lozenge = q + Offset(6 * dx, 6 * dy);
      canvas
        ..drawPath(rule(p, _arm), outer)
        ..drawPath(rule(q, _arm - 14), inner)
        ..drawPath(
          Path()
            ..addPolygon([
              lozenge + const Offset(0, -3.2),
              lozenge + const Offset(3.2, 0),
              lozenge + const Offset(0, 3.2),
              lozenge + const Offset(-3.2, 0),
            ], true),
          fill,
        )
        ..drawCircle(p + Offset((_arm + 3) * dx, 0), 1.5, fill)
        ..drawCircle(p + Offset(0, (_arm + 3) * dy), 1.5, fill);
    }
  }

  @override
  bool shouldRepaint(FrameCornersPainter old) =>
      old.color != color || old.corners != corners;
}

/// A verse-end marker (the rosette around an ayah number in the Mushaf):
/// a circle of [radius] around [center] edged with sixteen small lobes.
Path ayahMarker(Offset center, double radius) {
  const lobes = 16;
  final ring = radius * 0.89;
  var path = Path()..addOval(Rect.fromCircle(center: center, radius: ring));
  for (var i = 0; i < lobes; i++) {
    final a = -math.pi / 2 + i * 2 * math.pi / lobes;
    path = Path.combine(
      PathOperation.union,
      path,
      Path()
        ..addOval(Rect.fromCircle(
          center: center + Offset(math.cos(a), math.sin(a)) * ring,
          radius: radius * 0.11,
        )),
    );
  }
  return path;
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
