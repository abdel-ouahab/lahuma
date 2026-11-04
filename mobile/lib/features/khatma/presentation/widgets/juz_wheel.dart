import 'dart:math' as math;
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/quran_pages.dart';

/// The khatma before its first page: the Mushaf's 30 juz' as a ring of
/// segments, the first one lit, around a verse-end marker holding "30".
/// The segments draw in once, in order, when it first appears.
class JuzWheel extends StatelessWidget {
  const JuzWheel({super.key, this.size = 148});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final number = context.isArabic ? '٣٠' : '30';
    return Semantics(
      label: context.tr('القرآن ثلاثون جزءًا', 'The Quran in 30 juz'),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => CustomPaint(
            painter: _JuzWheelPainter(
              shown: t,
              track: c.gold.withValues(alpha: 0.3),
              first: c.accent,
              gold: c.gold,
            ),
            child: child,
          ),
          child: Center(
            child: Text(
              number,
              textDirection: TextDirection.ltr,
              style: AppTypography.quran(size: size * 0.21, height: 1.1)
                  .copyWith(color: c.label),
            ),
          ),
        ),
      ),
    );
  }
}

class _JuzWheelPainter extends CustomPainter {
  const _JuzWheelPainter({
    required this.shown,
    required this.track,
    required this.first,
    required this.gold,
  });

  /// 0–1: how many of the segments have drawn in.
  final double shown;
  final Color track;
  final Color first;
  final Color gold;

  static const double _stroke = 7;
  static const double _gap = 0.05;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final arc = Rect.fromCircle(center: center, radius: radius - _stroke / 2);
    const step = 2 * math.pi / QuranPages.juzCount;
    final segment = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    for (var i = 0; i < QuranPages.juzCount; i++) {
      final appear =
          (shown * QuranPages.juzCount - i).clamp(0.0, 1.0).toDouble();
      if (appear == 0) break;
      segment.color = i == 0 ? first : track;
      canvas.drawArc(arc, -math.pi / 2 + i * step + _gap / 2,
          (step - _gap) * appear, false, segment);
    }

    final marker = ayahMarker(center, radius * 0.5);
    canvas
      ..drawPath(marker, Paint()..color = gold.withValues(alpha: 0.12))
      ..drawPath(
        marker,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = gold,
      )
      ..drawCircle(
        center,
        radius * 0.34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..color = gold.withValues(alpha: 0.7),
      );
  }

  @override
  bool shouldRepaint(_JuzWheelPainter old) =>
      old.shown != shown ||
      old.track != track ||
      old.first != first ||
      old.gold != gold;
}
