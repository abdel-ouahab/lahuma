import 'dart:math' as math;
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/tasbih.dart';
import 'beads_painter.dart';
import 'counter_display.dart';
import 'tasbih_labels.dart';

/// The prayer beads with the counter inside. Tapping anywhere on it counts.
///
/// Each change of [count] slides one bead along the string (larger jumps,
/// such as a reset, run the beads across in a wave) and gives the tassel a
/// push. Changing [celebration] plays a burst from the counter.
class Misbaha extends StatefulWidget {
  const Misbaha({
    super.key,
    required this.dhikr,
    required this.count,
    required this.material,
    required this.onTap,
    this.celebration = 0,
  });

  final TasbihDhikr dhikr;
  final int count;
  final BeadMaterial material;
  final VoidCallback onTap;

  /// Bump to play the target-reached burst.
  final int celebration;

  @override
  State<Misbaha> createState() => _MisbahaState();
}

class _MisbahaState extends State<Misbaha> with TickerProviderStateMixin {
  late final AnimationController _beads = AnimationController(
    vsync: this,
    upperBound: tasbihBeads.toDouble(),
    value: beadsCounted(widget.count).toDouble(),
  );
  late final AnimationController _swing = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  double _swingDirection = 1;
  MisbahaGeometry? _geometry;

  @override
  void didUpdateWidget(Misbaha old) {
    super.didUpdateWidget(old);
    final still = MediaQuery.disableAnimationsOf(context);

    if (old.count != widget.count || old.dhikr.id != widget.dhikr.id) {
      final target = beadsCounted(widget.count).toDouble();
      final steps = (target - _beads.value).abs();
      if (still) {
        _beads.value = target;
      } else if (steps > 0) {
        // One bead in ~200 ms; a wave of many takes up to 700 ms.
        final ms = (160 + 40 * steps).clamp(200, 700).round();
        _beads.animateTo(
          target,
          duration: Duration(milliseconds: ms),
          curve: steps <= 2 ? Curves.easeOutCubic : Curves.easeInOutCubic,
        );
      }
      if (!still && old.dhikr.id == widget.dhikr.id) {
        _swingDirection = widget.count > old.count ? 1 : -1;
        _swing.forward(from: 0);
      }
    }

    if (old.celebration != widget.celebration && !still) {
      _burst.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _beads.dispose();
    _swing.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final colors = beadColorsOf(widget.material);
    final target = widget.dhikr.target;

    return LayoutBuilder(builder: (context, box) {
      final size = box.biggest;
      final mirror = Directionality.of(context) == TextDirection.ltr;
      var g = _geometry;
      if (g == null || g.size != size || g.mirrored != mirror) {
        g = _geometry = MisbahaGeometry(size, mirror: mirror);
      }
      final inner = g.innerRadius;

      return Semantics(
        button: true,
        excludeSemantics: true,
        label: context.tr(
            'سبّح: ${widget.dhikr.text}', 'Count: ${widget.dhikr.text}'),
        value: target == null
            ? formatCount(widget.count)
            : context.tr(
                '${formatCount(widget.count)} من ${formatCount(target)}',
                '${formatCount(widget.count)} of ${formatCount(target)}'),
        hint: context.tr('اضغط للعدّ', 'Tap to count'),
        onTap: widget.onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: BeadsPainter(
                      geometry: g,
                      counted: _beads,
                      swing: _swing,
                      swingDirection: _swingDirection,
                      colors: colors,
                      shadow: beadShadowOf(c),
                      dark: c.isDark,
                    ),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: Rect.fromCircle(center: g.center, radius: inner),
                child: CounterDisplay(
                  dhikr: widget.dhikr,
                  count: widget.count,
                  diameter: inner * 2,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _BurstPainter(
                      progress: _burst,
                      center: g.center,
                      radius: inner,
                      bead: g.bead,
                      colors: [colors.body, AppColors.beadImam.body, c.success],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Target reached: small beads scatter out from the counter while a ring of
/// light opens past the progress ring.
class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.progress,
    required this.center,
    required this.radius,
    required this.bead,
    required this.colors,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Offset center;
  final double radius;
  final double bead;
  final List<Color> colors;

  static const int _sparks = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t == 0 || t == 1) return;
    final out = Curves.easeOutCubic.transform(t);
    final fade = 1 - t * t;

    canvas.drawCircle(
      center,
      radius * (1 + 0.18 * out),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * (1 - out) + 1
        ..color = colors.last.withValues(alpha: 0.5 * fade),
    );

    final paint = Paint();
    for (var i = 0; i < _sparks; i++) {
      // Fixed jitter so the burst looks scattered but never flickers.
      final jitter = ((i * 53) % 17) / 17 - 0.5;
      final angle = i * 2 * math.pi / _sparks + jitter * 0.3;
      final distance = radius * (0.55 + (0.75 + jitter * 0.3) * out);
      final p = center + Offset(math.cos(angle), math.sin(angle)) * distance;
      paint.color = colors[i % colors.length].withValues(alpha: fade);
      canvas.drawCircle(p, bead * (0.2 - 0.1 * out), paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.progress != progress ||
      old.center != center ||
      old.radius != radius ||
      old.bead != bead ||
      old.colors != colors;
}
