import '../design/design.dart';

/// A count drawn as a row of segments, one per unit, the first [filled] lit
/// from the reading direction's start. Falls back to a plain bar when the
/// segments would be too thin to tell apart.
class SegmentBar extends StatelessWidget {
  const SegmentBar({
    super.key,
    required this.filled,
    required this.total,
    required this.color,
    this.height = 4,
  });

  final int filled;
  final int total;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _SegmentsPainter(
              filled: filled.clamp(0, total),
              total: total,
              lit: color,
              track: color.withValues(alpha: 0.22),
              rtl: Directionality.of(context) == TextDirection.rtl,
            ),
          ),
        ),
      );
}

class _SegmentsPainter extends CustomPainter {
  const _SegmentsPainter({
    required this.filled,
    required this.total,
    required this.lit,
    required this.track,
    required this.rtl,
  });

  final int filled;
  final int total;
  final Color lit;
  final Color track;
  final bool rtl;

  static const double _gap = 2;
  static const double _minSegment = 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final radius = Radius.circular(size.height / 2);
    final segment = (size.width - _gap * (total - 1)) / total;
    if (segment < _minSegment) {
      final whole = RRect.fromRectAndRadius(Offset.zero & size, radius);
      canvas.drawRRect(whole, Paint()..color = track);
      final width = size.width * filled / total;
      final left = rtl ? size.width - width : 0.0;
      canvas.drawRRect(
          RRect.fromLTRBR(left, 0, left + width, size.height, radius),
          Paint()..color = lit);
      return;
    }
    for (var i = 0; i < total; i++) {
      final start = i * (segment + _gap);
      final left = rtl ? size.width - start - segment : start;
      canvas.drawRRect(
        RRect.fromLTRBR(left, 0, left + segment, size.height, radius),
        Paint()..color = i < filled ? lit : track,
      );
    }
  }

  @override
  bool shouldRepaint(_SegmentsPainter old) =>
      old.filled != filled ||
      old.total != total ||
      old.lit != lit ||
      old.track != track ||
      old.rtl != rtl;
}
