import 'dart:math' as math;
import 'dart:ui' as ui;
import '../../../../core/design/design.dart';
import '../../domain/tasbih.dart';

BeadColors beadColorsOf(BeadMaterial material) => switch (material) {
      BeadMaterial.amber => AppColors.beadAmber,
      BeadMaterial.wood => AppColors.beadWood,
      BeadMaterial.pearl => AppColors.beadPearl,
    };

/// Beads are solid objects: their contact shadow stays visible in light mode,
/// where [AppPalette.shadow] is too faint to ground them.
Color beadShadowOf(AppPalette c) =>
    AppColors.shadow.withValues(alpha: c.isDark ? 0.6 : 0.3);

// Lengths along the string, in bead diameters.
const double _imamUnits = 1.55;
const double _separatorUnits = 0.4;
const double _gapUnits = 3.0;

/// From the imam bead's centre to the end of the tassel.
const double _tasselUnits = 4.0;

/// Bead indices followed by a flat separator disc, splitting 33 into thirds.
const Set<int> _separatorAfter = {10, 21};

/// Where the string hangs inside a box: an upright oval with the imam bead
/// at the bottom and the tassel below it, centred as a whole.
///
/// The string runs from the imam bead up the counted side, over the top and
/// back down. Counted beads gather against the imam on that side (the right
/// in Arabic, the left in English); the rest gather against it on the other
/// side, leaving one gap on the string between them.
class MisbahaGeometry {
  factory MisbahaGeometry(Size size, {required bool mirror}) {
    // Height ≈ 3.05 rx with the tassel; width ≈ 2.25 rx with the beads.
    final rx =
        math.min(210.0, math.min(size.width / 2.25, size.height / 3.05));
    // Spare height goes into a taller oval, the way beads hang, up to 1.3×.
    final ry = ((size.height - rx * 0.19 * (0.5 + _tasselUnits)) / 2)
        .clamp(rx * 1.12, rx * 1.3);
    final oval = Rect.fromCenter(
      center: Offset.zero,
      width: rx * 2,
      height: ry * 2,
    );

    // Screen angles run clockwise; from the bottom (π/2) a negative sweep
    // heads right first.
    final sweep = mirror ? math.pi : -math.pi;
    final string = Path()
      ..addArc(oval, math.pi / 2, sweep)
      ..arcTo(oval, -math.pi / 2, sweep, false);
    final metric = string.computeMetrics().first;

    final units = tasbihBeads +
        _imamUnits +
        _separatorUnits * _separatorAfter.length +
        _gapUnits;
    final bead = metric.length / units;

    final height = bead * 0.5 + ry * 2 + bead * _tasselUnits;
    final center = Offset(
      size.width / 2,
      (size.height - height) / 2 + bead * 0.5 + ry,
    );
    final placed = string.shift(center);
    return MisbahaGeometry._(
      size: size,
      mirrored: mirror,
      center: center,
      radiusX: rx,
      radiusY: ry,
      bead: bead,
      string: placed,
      metric: placed.computeMetrics().first,
    );
  }

  MisbahaGeometry._({
    required this.size,
    required this.mirrored,
    required this.center,
    required this.radiusX,
    required this.radiusY,
    required this.bead,
    required this.string,
    required this.metric,
  });

  final Size size;

  /// Counted side on the left (English) instead of the right.
  final bool mirrored;
  final Offset center;
  final double radiusX;
  final double radiusY;

  /// Bead diameter.
  final double bead;
  final Path string;
  final ui.PathMetric metric;

  double get length => metric.length;
  double get imamLength => bead * _imamUnits;
  double get gap => bead * _gapUnits;
  double get imamRadius => bead * 0.72;
  Offset get imamCenter => center + Offset(0, radiusY);

  /// Radius of the clear circle inside the beads (counter and ring).
  double get innerRadius => math.min(radiusX, radiusY) - bead * 1.3;

  ui.Tangent at(double offset) =>
      metric.getTangentForOffset(offset % length)!;
}

/// Paints one bead lit from the top left: body, light through it, grain,
/// a lit rim on dark backgrounds and a glint. Its shadow is separate
/// ([paintBeadShadow]) so a row of beads never shades its neighbours' bodies.
void paintBead(
  Canvas canvas,
  Offset center,
  double radius,
  BeadColors colors, {
  bool rim = false,
  int seed = 0,
}) {
  final rect = Rect.fromCircle(center: center, radius: radius);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.38, -0.45),
        radius: 1.1,
        colors: [colors.highlight, colors.body, colors.shade],
        stops: const [0, 0.45, 1],
      ).createShader(rect),
  );
  // Edge falloff gives the bead its volume.
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(
        colors: [
          colors.shade.withValues(alpha: 0),
          colors.shade.withValues(alpha: 0.55),
        ],
        stops: const [0.68, 1],
      ).createShader(rect),
  );
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.42, 0.58),
        radius: 0.62,
        colors: [
          colors.glow.withValues(alpha: colors.glowStrength),
          colors.glow.withValues(alpha: 0),
        ],
      ).createShader(rect),
  );

  if (colors.grain case final grain?) {
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.07
      ..color = grain.withValues(alpha: 0.35);
    // Each bead cut from a different part of the wood.
    final shift = ((seed * 37) % 11) / 11 - 0.5;
    for (var k = 0; k < 3; k++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center + Offset(radius * (0.9 + shift * 0.6), radius * 0.2),
          width: radius * (1.1 + k * 0.75),
          height: radius * (2.4 + k * 0.9),
        ),
        paint,
      );
    }
    canvas.restore();
  }

  if (rim) {
    canvas.drawCircle(
      center,
      radius - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CupertinoColors.white.withValues(alpha: 0.28),
            CupertinoColors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.55],
        ).createShader(rect),
    );
  }

  canvas.save();
  canvas.translate(center.dx - radius * 0.34, center.dy - radius * 0.42);
  canvas.rotate(-math.pi / 6);
  canvas.drawOval(
    Rect.fromCenter(
        center: Offset.zero, width: radius * 0.6, height: radius * 0.34),
    Paint()
      ..color = CupertinoColors.white.withValues(alpha: colors.specular)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.08),
  );
  canvas.restore();
}

/// Soft contact shadow under a bead; [lift] (0…1) raises it off the cloth.
void paintBeadShadow(Canvas canvas, Offset center, double radius, Color color,
    {double lift = 0}) {
  canvas.drawCircle(
    center + Offset(radius * (0.12 + lift * 0.2), radius * (0.38 + lift * 0.5)),
    radius * 0.92,
    Paint()
      ..color = color.withValues(alpha: color.a * (1 - lift * 0.4))
      ..maskFilter =
          MaskFilter.blur(BlurStyle.normal, radius * (0.3 + lift * 0.25)),
  );
}

/// The misbaha: cord, 33 beads with two separators, the imam bead and its
/// tassel.
///
/// [counted] is how many beads sit on the counted side; between whole
/// numbers the next bead is partway across the gap, so animating it slides
/// beads along the string. [swing] (0…1) plays one push of the tassel.
class BeadsPainter extends CustomPainter {
  BeadsPainter({
    required this.geometry,
    required this.counted,
    required this.swing,
    required this.swingDirection,
    required this.colors,
    required this.shadow,
    required this.dark,
  }) : super(repaint: Listenable.merge([counted, swing]));

  final MisbahaGeometry geometry;
  final Animation<double> counted;
  final Animation<double> swing;

  /// 1 or -1: which way the last tap pushed the tassel.
  final double swingDirection;
  final BeadColors colors;
  final Color shadow;
  final bool dark;

  static const BeadColors _imam = AppColors.beadImam;

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    final r = g.bead * 0.47;
    final a = counted.value;

    // Lay out beads and separators along the string.
    final beads = <_Placed>[];
    final separators = <_Placed>[];
    var cursor = g.imamLength / 2;
    for (var i = 0; i < tasbihBeads; i++) {
      // 0 on the counted side, 1 on the other, between while crossing.
      final across = (i + 1 - a).clamp(0.0, 1.0);
      final shift = g.gap * across;
      beads.add(_Placed(i, g.at(cursor + g.bead / 2 + shift), across));
      cursor += g.bead;
      if (_separatorAfter.contains(i)) {
        final len = g.bead * _separatorUnits;
        // The separator rides with the bead before it.
        separators.add(_Placed(i, g.at(cursor + len / 2 + shift), across));
        cursor += len;
      }
    }

    // Cord.
    canvas.drawPath(
      g.string,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, g.bead * 0.07)
        ..color = colors.cord.withValues(alpha: dark ? 0.9 : 0.75),
    );

    // Shadows first, so no bead shades another.
    for (final b in beads) {
      paintBeadShadow(canvas, b.tangent.position, r, shadow, lift: b.lift);
    }
    paintBeadShadow(canvas, g.imamCenter, g.imamRadius, shadow);

    _paintTassel(canvas);

    for (final s in separators) {
      _paintSeparator(canvas, s.tangent);
    }
    // Resting beads, then the moving one on top.
    for (final b in beads) {
      if (b.lift == 0) _paintBead(canvas, b, r);
    }
    for (final b in beads) {
      if (b.lift > 0) _paintBead(canvas, b, r);
    }

    paintBead(canvas, g.imamCenter, g.imamRadius, _imam, rim: dark);
  }

  void _paintBead(Canvas canvas, _Placed b, double r) {
    // A moving bead is lifted a little between the fingers.
    paintBead(canvas, b.tangent.position, r * (1 + 0.07 * b.lift), colors,
        rim: dark, seed: b.index);
  }

  void _paintSeparator(Canvas canvas, ui.Tangent t) {
    final g = geometry;
    final w = g.bead * _separatorUnits * 0.8;
    final h = g.bead * 0.82;
    canvas.save();
    canvas.translate(t.position.dx, t.position.dy);
    canvas.rotate(-t.angle);
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(w / 2)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_imam.highlight, _imam.body, _imam.shade],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
    canvas.restore();
  }

  void _paintTassel(Canvas canvas) {
    final g = geometry;
    final d = g.bead;
    final t = swing.value;
    // A push that dies away: two and a half swings, damped.
    final angle = t == 0 || t == 1
        ? 0.0
        : swingDirection *
            0.16 *
            (1 - t) *
            (1 - t) *
            math.sin(t * math.pi * 2 * 2.5);

    canvas.save();
    canvas.translate(g.imamCenter.dx, g.imamCenter.dy + g.imamRadius * 0.8);
    canvas.rotate(angle);

    // Minaret: a tapered stone under the imam bead.
    final top = d * 0.27;
    final bottom = d * 0.17;
    final length = d * 0.8;
    final minaret = Path()
      ..moveTo(-top, 0)
      ..lineTo(top, 0)
      ..lineTo(bottom, length)
      ..quadraticBezierTo(0, length + d * 0.12, -bottom, length)
      ..close();
    final bounds = Rect.fromLTRB(-top, 0, top, length);
    canvas.drawPath(
      minaret,
      Paint()
        ..shader = LinearGradient(
          colors: [_imam.shade, _imam.highlight, _imam.body, _imam.shade],
          stops: const [0, 0.3, 0.62, 1],
        ).createShader(bounds),
    );

    // Silk fringe: lit down the middle, darker at the sides; the ends trail
    // behind the swing.
    final y0 = length + d * 0.05;
    final y1 = y0 + d * 2.3;
    final strand = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.2, d * 0.065);
    const strands = 33;
    final lag = -angle * d * 1.4;
    for (var i = 0; i < strands; i++) {
      final f = i / (strands - 1) - 0.5;
      // Bell-shaped: gathered at the knot, falling nearly straight.
      final path = Path()
        ..moveTo(f * d * 0.36, y0)
        ..quadraticBezierTo(
            f * d * 1.0 + lag * 0.3, y0 + (y1 - y0) * 0.35, f * d * 1.15 + lag, y1);
      final lit = Color.lerp(
          _imam.glow, _imam.shade, (f.abs() * 2).clamp(0.0, 1.0))!;
      strand.color = (i.isEven ? Color.lerp(lit, _imam.highlight, 0.2)! : lit)
          .withValues(alpha: 0.95);
      canvas.drawPath(path, strand);
    }

    // Knot binding the fringe.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(0, y0 + d * 0.06), width: d * 0.42, height: d * 0.22),
        Radius.circular(d * 0.1),
      ),
      Paint()
        ..shader = LinearGradient(
          colors: [_imam.shade, _imam.highlight, _imam.shade],
        ).createShader(Rect.fromCenter(
            center: Offset(0, y0), width: d * 0.42, height: d * 0.22)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BeadsPainter old) =>
      old.geometry != geometry ||
      old.counted != counted ||
      old.swing != swing ||
      old.swingDirection != swingDirection ||
      old.colors != colors ||
      old.shadow != shadow ||
      old.dark != dark;
}

class _Placed {
  _Placed(this.index, this.tangent, double across)
      : lift = across > 0 && across < 1 ? math.sin(math.pi * across) : 0;

  final int index;
  final ui.Tangent tangent;

  /// 0 at rest; peaks at 1 halfway across the gap.
  final double lift;
}

/// A single bead (material previews, the settings picker).
class BeadSwatch extends StatelessWidget {
  const BeadSwatch({super.key, required this.material, this.size = 36});

  final BeadMaterial material;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return CustomPaint(
      size: Size.square(size),
      painter: _SwatchPainter(
        colors: beadColorsOf(material),
        shadow: beadShadowOf(c),
        dark: c.isDark,
      ),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter(
      {required this.colors, required this.shadow, required this.dark});

  final BeadColors colors;
  final Color shadow;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide * 0.4;
    final center = size.center(Offset(0, -r * 0.12));
    paintBeadShadow(canvas, center, r, shadow);
    paintBead(canvas, center, r, colors, rim: dark, seed: 3);
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.colors != colors || old.shadow != shadow || old.dark != dark;
}
