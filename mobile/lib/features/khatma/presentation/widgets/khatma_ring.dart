import 'dart:math' as math;
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/quran_pages.dart';

/// The whole khatma as a ring: how far through the 604 pages the reader is.
class KhatmaRing extends StatelessWidget {
  const KhatmaRing({super.key, required this.lastPageRead, this.size = 156});

  final int lastPageRead;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final fraction = (lastPageRead / QuranPages.total).clamp(0.0, 1.0);
    final percent = (fraction * 100).floor();
    return Semantics(
      label: context.tr(
          'أتممت $percent بالمئة، $lastPageRead من ${QuranPages.total} صفحة',
          '$percent percent done, $lastPageRead of ${QuranPages.total} pages'),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: fraction),
          duration: AppMotion.of(context),
          curve: AppMotion.curve,
          builder: (context, value, _) => CustomPaint(
            painter: _RingPainter(
              value: value,
              track: c.tertiaryFill,
              start: c.accent,
              end: c.gold,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ltr('$percent%'),
                    style: AppTypography.tabular(AppTypography.title1)
                        .copyWith(color: c.label),
                  ),
                  Text(
                    ltr('$lastPageRead / ${QuranPages.total}'),
                    style: AppTypography.tabular(AppTypography.footnote)
                        .copyWith(color: c.secondaryLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.track,
    required this.start,
    required this.end,
  });

  final double value;
  final Color track;
  final Color start;
  final Color end;

  static const double _stroke = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(_stroke / 2);
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = track,
    );
    if (value <= 0) return;
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          endAngle: math.pi * 2 * value,
          colors: [start, end],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.track != track ||
      old.start != start ||
      old.end != end;
}
