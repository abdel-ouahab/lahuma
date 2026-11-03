import 'dart:math' as math;
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';

/// "Move the phone in a figure 8" card, with a phone tracing the 8.
class CalibrationHint extends StatelessWidget {
  const CalibrationHint({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Semantics(
      container: true,
      liveRegion: true,
      child: AppCard(
        padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.ms, AppSpacing.ms, AppSpacing.xs, AppSpacing.ms),
        child: Row(
          children: [
            const ExcludeSemantics(child: FigureEight()),
            const SizedBox(width: AppSpacing.ms),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr('حرّك الهاتف على شكل الرقم 8 لمعايرة البوصلة',
                        'Move your phone in a figure 8 to calibrate the compass'),
                    style: AppTypography.subheadline
                        .weight(FontWeight.w600)
                        .copyWith(color: c.label),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr('ثلاث مرات أو أربعًا تكفي عادةً.',
                        'Three or four times is usually enough.'),
                    style: AppTypography.footnote
                        .copyWith(color: c.secondaryLabel),
                  ),
                ],
              ),
            ),
            AppIconButton(
              icon: CupertinoIcons.xmark,
              size: 17,
              color: c.secondaryLabel,
              label: context.tr('إخفاء', 'Dismiss'),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

/// A small phone travelling a figure 8, tilting with the curve. Still when
/// the user asked to reduce motion.
class FigureEight extends StatefulWidget {
  const FigureEight({super.key, this.size = const Size(64, 40)});

  final Size size;

  @override
  State<FigureEight> createState() => _FigureEightState();
}

class _FigureEightState extends State<FigureEight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _t
        ..stop()
        ..value = 0.15;
    } else if (!_t.isAnimating) {
      _t.repeat();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return RepaintBoundary(
      child: CustomPaint(
        size: widget.size,
        painter: _FigureEightPainter(
          t: _t,
          track: c.tertiaryLabel,
          phone: c.accent,
          screen: c.secondaryGroupedBackground,
        ),
      ),
    );
  }
}

class _FigureEightPainter extends CustomPainter {
  _FigureEightPainter({
    required this.t,
    required this.track,
    required this.phone,
    required this.screen,
  }) : super(repaint: t);

  final Animation<double> t;
  final Color track;
  final Color phone;
  final Color screen;

  /// Lemniscate of Bernoulli, scaled into [size].
  Offset _point(double a, Size size) {
    final s = math.sin(a), c = math.cos(a);
    final d = 1 + s * s;
    return Offset(
      size.width / 2 + (size.width / 2 - 8) * c / d,
      size.height / 2 + (size.height - 6) * s * c / d,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i <= 64; i++) {
      final p = _point(i / 64 * 2 * math.pi, size);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = track,
    );

    final a = t.value * 2 * math.pi;
    final p = _point(a, size);
    final ahead = _point(a + 0.05, size);
    final tilt = math.atan2(ahead.dy - p.dy, ahead.dx - p.dx) * 0.35;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(tilt);
    final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 11, height: 18),
        const Radius.circular(2.6));
    canvas.drawRRect(body, Paint()..color = phone);
    canvas.drawRRect(
      body.deflate(1.6),
      Paint()..color = screen.withValues(alpha: 0.85),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FigureEightPainter old) =>
      old.track != track || old.phone != phone || old.screen != screen;
}
