import 'dart:math' as math;
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/qibla_service.dart';
import 'qibla_labels.dart';
import 'qibla_pointer.dart';

/// The compass. The dial turns so its north stays on the earth's north, the
/// Kaaba rides its rim at the Qibla bearing, and a fixed pointer above it
/// marks where the phone faces. An arc on the rim spans the turn still to
/// make; when the pointer reaches the Kaaba the rim glows green.
///
/// Turning always takes the short way across north (359° → 1° moves 2°).
class CompassDial extends StatefulWidget {
  const CompassDial({
    super.key,
    required this.size,
    required this.heading,
    required this.qiblaBearing,
    this.aligned = false,
    this.live = true,
    this.center,
    this.semanticLabel,
  });

  /// Width and height of the whole compass, pointer included.
  final double size;

  /// True heading the phone faces, degrees. The dial turns by minus this.
  final double heading;

  /// Degrees clockwise from true north.
  final double qiblaBearing;
  final bool aligned;

  /// False draws a still, north-up dial without the pointer or the arc:
  /// the Qibla relative to north, for phones without a compass.
  final bool live;

  /// Shown in the middle of the dial.
  final Widget? center;
  final String? semanticLabel;

  @override
  State<CompassDial> createState() => _CompassDialState();
}

class _CompassDialState extends State<CompassDial>
    with SingleTickerProviderStateMixin {
  /// [CompassDial.heading] unwrapped, so the tween never spins the long way.
  late double _heading = widget.heading;

  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
    value: widget.aligned ? 1 : 0,
  );

  _DialText? _text;

  @override
  void didUpdateWidget(CompassDial old) {
    super.didUpdateWidget(old);
    if (old.heading != widget.heading) {
      _heading = unwrapDegrees(_heading, widget.heading);
    }
    if (old.aligned != widget.aligned) {
      final target = widget.aligned ? 1.0 : 0.0;
      if (MediaQuery.disableAnimationsOf(context)) {
        _glow.value = target;
      } else {
        _glow.animateTo(target, curve: AppMotion.curve);
      }
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    _text?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final g = _DialGeometry(widget.size);
    final colors = _DialColors(
      face: c.cardGradient,
      rim: c.isDark ? c.separator : c.opaqueSeparator,
      majorTick: c.secondaryLabel,
      minorTick: c.tertiaryLabel,
      inner: c.tertiaryFill,
      accent: c.accent,
      aligned: c.success,
      shadow: c.shadow(0.45),
      halo: c.secondaryGroupedBackground,
      kaabaEdge: c.isDark ? c.separator : null,
    );

    final labels = cardinals(context);
    final key = '${g.radius}|${labels.first}|${c.accent}|${c.secondaryLabel}';
    if (_text?.key != key) {
      _text?.dispose();
      _text = _DialText.build(
        key: key,
        radius: g.radius,
        cardinals: labels,
        north: c.accent,
        cardinal: c.label,
        numeral: c.secondaryLabel,
        arabic: context.isArabic,
      );
    }

    final dial = TweenAnimationBuilder<double>(
      tween: Tween(end: widget.live ? _heading : 0),
      duration: AppMotion.of(context, const Duration(milliseconds: 180)),
      curve: Curves.easeOut,
      builder: (context, heading, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _DialPainter(
          geometry: g,
          heading: heading,
          qibla: widget.qiblaBearing,
          live: widget.live,
          glow: _glow,
          colors: colors,
          text: _text!,
        ),
      ),
    );

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          children: [
            Positioned.fill(child: RepaintBoundary(child: dial)),
            if (widget.live)
              Positioned(
                top: g.pointerTop,
                left: (widget.size - g.pointerWidth) / 2,
                child: QiblaPointer(
                  color: widget.aligned ? c.success : c.accent,
                  width: g.pointerWidth,
                  height: g.pointerHeight,
                ),
              ),
            if (widget.center != null)
              Positioned.fromRect(
                rect: Rect.fromCircle(
                    center: g.center, radius: g.radius * _innerRadius),
                child: Center(child: widget.center),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fractions of the dial radius.
const double _tickOuter = 0.955;
const double _labelRing = 0.74;
const double _innerRadius = 0.48;

/// Where everything sits for a compass of a given size. The dial is pushed
/// down to leave room above it for the pointer, and inset all round so the
/// Kaaba can straddle the rim anywhere.
class _DialGeometry {
  _DialGeometry(this.size)
      : kaabaRadius = (size * 0.058).clamp(13.0, 22.0),
        pointerHeight = (size * 0.045).clamp(11.0, 16.0) {
    pointerWidth = pointerHeight * 1.6;
    pointerTop = 0;
    final top = pointerHeight + 3 + kaabaRadius;
    radius = (size - top - kaabaRadius - 2) / 2;
    center = Offset(size / 2, top + radius);
  }

  final double size;
  final double kaabaRadius;
  final double pointerHeight;
  late final double pointerWidth;
  late final double pointerTop;
  late final double radius;
  late final Offset center;

  /// The point at [r] from the centre in screen direction [degrees]
  /// (0 = up, clockwise).
  Offset at(double degrees, double r) {
    final a = degrees * math.pi / 180;
    return Offset(center.dx + r * math.sin(a), center.dy - r * math.cos(a));
  }
}

class _DialColors {
  const _DialColors({
    required this.face,
    required this.rim,
    required this.majorTick,
    required this.minorTick,
    required this.inner,
    required this.accent,
    required this.aligned,
    required this.shadow,
    required this.halo,
    required this.kaabaEdge,
  });

  final Gradient face;
  final Color rim;
  final Color majorTick;
  final Color minorTick;
  final Color inner;
  final Color accent;
  final Color aligned;
  final Color shadow;
  final Color halo;

  /// Faint outline that keeps the black Kaaba visible on a dark dial.
  final Color? kaabaEdge;

  @override
  bool operator ==(Object other) =>
      other is _DialColors &&
      other.face == face &&
      other.rim == rim &&
      other.majorTick == majorTick &&
      other.minorTick == minorTick &&
      other.inner == inner &&
      other.accent == accent &&
      other.aligned == aligned &&
      other.shadow == shadow &&
      other.halo == halo &&
      other.kaabaEdge == kaabaEdge;

  @override
  int get hashCode => Object.hash(face, rim, majorTick, minorTick, inner,
      accent, aligned, shadow, halo, kaabaEdge);
}

/// The dial's words and numbers, laid out once per size and theme rather
/// than on every frame of a turn.
class _DialText {
  _DialText._(this.key, this.cardinals, this.numerals);

  factory _DialText.build({
    required String key,
    required double radius,
    required List<String> cardinals,
    required Color north,
    required Color cardinal,
    required Color numeral,
    required bool arabic,
  }) {
    TextPainter lay(String text, TextStyle style) => TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
        )..layout();

    final cardinalSize = (radius * (arabic ? 0.088 : 0.1)).clamp(11.0, 18.0);
    final numeralSize = (radius * 0.064).clamp(9.0, 12.0);
    final base = AppTypography.headline.weight(FontWeight.w700);
    return _DialText._(
      key,
      [
        for (var i = 0; i < 4; i++)
          lay(
            cardinals[i],
            base.copyWith(
              fontSize: cardinalSize,
              height: 1.1,
              color: i == 0 ? north : cardinal,
            ),
          ),
      ],
      {
        for (var d = 30; d < 360; d += 30)
          if (d % 90 != 0)
            d: lay(
              '$d',
              AppTypography.tabular(AppTypography.caption2).copyWith(
                fontSize: numeralSize,
                height: 1,
                color: numeral,
              ),
            ),
      },
    );
  }

  final String key;
  final List<TextPainter> cardinals;
  final Map<int, TextPainter> numerals;

  void dispose() {
    for (final p in [...cardinals, ...numerals.values]) {
      p.dispose();
    }
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.geometry,
    required this.heading,
    required this.qibla,
    required this.live,
    required this.glow,
    required this.colors,
    required this.text,
  }) : super(repaint: glow);

  final _DialGeometry geometry;
  final double heading;
  final double qibla;
  final bool live;
  final Animation<double> glow;
  final _DialColors colors;
  final _DialText text;

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    final r = g.radius;
    final o = g.center;
    final t = glow.value;
    final qiblaColor = Color.lerp(colors.accent, colors.aligned, t)!;
    final dialRect = Rect.fromCircle(center: o, radius: r);

    // ── Body: shadow, face, inner well ──
    canvas.drawCircle(
      o.translate(0, r * 0.035),
      r,
      Paint()
        ..color = colors.shadow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.07),
    );
    canvas.drawCircle(
        o, r, Paint()..shader = colors.face.createShader(dialRect));
    canvas.drawCircle(o, r * _innerRadius, Paint()..color = colors.inner);

    // ── Alignment glow ──
    if (t > 0) {
      canvas.drawCircle(
        o,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.05
          ..color = colors.aligned.withValues(alpha: 0.45 * t)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06),
      );
    }
    canvas.drawCircle(
      o,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 + t
        ..color = Color.lerp(colors.rim, colors.aligned, t)!,
    );

    // ── Ticks: every 5°, longer every 15° and 30° ──
    final minor = Paint()
      ..color = colors.minorTick
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final major = Paint()
      ..color = colors.majorTick
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final north = Paint()
      ..color = colors.accent
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    for (var d = 0; d < 360; d += 5) {
      final len = d % 30 == 0
          ? 0.085
          : d % 15 == 0
              ? 0.055
              : 0.03;
      final a = d - heading;
      canvas.drawLine(
        g.at(a, r * _tickOuter),
        g.at(a, r * (_tickOuter - len)),
        d == 0
            ? north
            : d % 30 == 0
                ? major
                : minor,
      );
    }

    // ── Cardinals and degree numerals, kept upright ──
    for (var i = 0; i < 4; i++) {
      _drawUpright(
          canvas, text.cardinals[i], g.at(i * 90 - heading, r * _labelRing));
    }
    text.numerals.forEach((d, p) {
      _drawUpright(canvas, p, g.at(d - heading, r * (_labelRing + 0.02)));
    });

    // ── The turn still to make, from the pointer to the Kaaba ──
    final kaabaAngle = qibla - heading;
    if (live && t < 1) {
      final sweep = signedDelta(0, kaabaAngle);
      canvas.drawArc(
        dialRect,
        -math.pi / 2,
        sweep * math.pi / 180,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.028
          ..strokeCap = StrokeCap.round
          ..color = colors.accent.withValues(alpha: 0.55 * (1 - t)),
      );
    }

    // ── Qibla line and the Kaaba on the rim ──
    canvas.drawLine(
      g.at(kaabaAngle, r * (_innerRadius + 0.03)),
      g.at(kaabaAngle, r - g.kaabaRadius - 3),
      Paint()
        ..color = qiblaColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    final k = g.at(kaabaAngle, r);
    if (t > 0) {
      canvas.drawCircle(
        k,
        g.kaabaRadius + 2,
        Paint()
          ..color = colors.aligned.withValues(alpha: 0.5 * t)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, g.kaabaRadius * 0.5),
      );
    }
    canvas.drawCircle(k, g.kaabaRadius, Paint()..color = colors.halo);
    canvas.drawCircle(
      k,
      g.kaabaRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = qiblaColor,
    );
    paintKaaba(canvas, k, g.kaabaRadius * 1.15, edge: colors.kaabaEdge);
  }

  void _drawUpright(Canvas canvas, TextPainter p, Offset at) =>
      p.paint(canvas, at - Offset(p.width / 2, p.height / 2));

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.heading != heading ||
      old.qibla != qibla ||
      old.live != live ||
      old.geometry.size != geometry.size ||
      old.colors != colors ||
      old.text != text;
}

/// The Kaaba in three-quarter view, [size] wide, centred on [center]: the
/// black kiswa with its gold band and the raised door near the east corner.
void paintKaaba(Canvas canvas, Offset center, double size, {Color? edge}) {
  final s = size;
  final depth = Offset(s * 0.3, -s * 0.17);
  final w = s * 0.64, h = s * 0.64;
  final left = center.dx - (w + depth.dx) / 2;
  final top = center.dy - (h + depth.dy.abs()) / 2 + depth.dy.abs();
  final front = Rect.fromLTWH(left, top, w, h);

  Path quad(Offset a, Offset b) =>
      Path()..addPolygon([a, b, b + depth, a + depth], true);

  final side = quad(front.topRight, front.bottomRight);
  final roof = quad(front.topLeft, front.topRight);
  canvas.drawRect(front, Paint()..color = AppColors.kaabaFront);
  canvas.drawPath(side, Paint()..color = AppColors.kaabaSide);
  canvas.drawPath(roof, Paint()..color = AppColors.kaabaTop);

  // The gold band (hizam), round both visible walls.
  final gold = Paint()..color = AppColors.kaabaGold;
  final bandTop = top + h * 0.2, bandHeight = h * 0.11;
  canvas.drawRect(Rect.fromLTWH(left, bandTop, w, bandHeight), gold);
  canvas.drawPath(
    quad(Offset(front.right, bandTop),
        Offset(front.right, bandTop + bandHeight)),
    gold,
  );
  // The door, above the ground near the corner.
  canvas.drawRect(
    Rect.fromLTWH(left + w * 0.6, top + h * 0.46, w * 0.2, h * 0.36),
    gold,
  );

  if (edge != null) {
    final outline = Path()
      ..addPolygon([
        front.bottomLeft,
        front.topLeft,
        front.topLeft + depth,
        front.topRight + depth,
        front.bottomRight + depth,
        front.bottomRight,
      ], true);
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = edge,
    );
  }
}
