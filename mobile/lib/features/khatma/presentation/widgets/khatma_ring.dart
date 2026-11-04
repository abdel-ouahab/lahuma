import 'dart:math' as math;
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/quran_pages.dart';

/// The whole khatma as a ring of the 30 juz', each segment filling as its
/// pages are read: how far through the 604 pages the reader is.
class KhatmaRing extends StatelessWidget {
  const KhatmaRing({
    super.key,
    required this.lastPageRead,
    this.size = 156,
    this.center,
  });

  final int lastPageRead;
  final double size;

  /// Replaces the percentage and page count inside the ring (for small
  /// rings).
  final Widget? center;

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
              track: c.gold.withValues(alpha: 0.25),
              start: c.accent,
              end: c.gold,
              stroke: (size * 0.07).clamp(4.0, 10.0),
            ),
            child: Center(
              child: center ??
                  Column(
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
    required this.stroke,
  });

  /// 0–1 of the 604 pages.
  final double value;
  final Color track;
  final Color start;
  final Color end;
  final double stroke;

  static const double _gap = 0.045;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final page = value * QuranPages.total;
    const step = 2 * math.pi / QuranPages.juzCount;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final read = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..shader = SweepGradient(
        colors: [start, end],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    for (var juz = 1; juz <= QuranPages.juzCount; juz++) {
      // Every odd hizb opens a juz'.
      final first = QuranPages.hizbStartPage(juz * 2 - 1);
      final last = QuranPages.hizbEndPage(juz * 2);
      final filled =
          ((page - first + 1) / (last - first + 1)).clamp(0.0, 1.0).toDouble();
      final from = -math.pi / 2 + (juz - 1) * step + _gap / 2;
      const sweep = step - _gap;
      canvas.drawArc(arc, from, sweep, false, base..color = track);
      if (filled > 0) canvas.drawArc(arc, from, sweep * filled, false, read);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.stroke != stroke ||
      old.track != track ||
      old.start != start ||
      old.end != end;
}
