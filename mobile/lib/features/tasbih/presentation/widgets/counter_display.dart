import 'dart:math' as math;
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/tasbih.dart';
import 'tasbih_labels.dart';

/// The centre of the misbaha: the dhikr, the count, what it counts towards,
/// inside a thin progress ring.
///
/// With a target the ring fills towards it (green once reached); without one
/// it fills once per round of 33 beads.
class CounterDisplay extends StatelessWidget {
  const CounterDisplay({
    super.key,
    required this.dhikr,
    required this.count,
    required this.diameter,
  });

  final TasbihDhikr dhikr;
  final int count;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final target = dhikr.target;
    final reached = target != null && count >= target;

    final double progress;
    final int ringKey;
    if (target != null) {
      progress = math.min(1, count / target);
      ringKey = 0;
    } else {
      // 1…33 of the current round; a new round starts the ring afresh.
      progress = count == 0 ? 0 : ((count - 1) % tasbihBeads + 1) / tasbihBeads;
      ringKey = count == 0 ? 0 : (count - 1) ~/ tasbihBeads;
    }

    final numberSize = (diameter * 0.3).clamp(40.0, 96.0);
    final textSize = (diameter * 0.085).clamp(15.0, 26.0);

    return SizedBox.square(
      dimension: diameter,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(ringKey),
        tween: Tween(end: progress),
        duration: AppMotion.of(context, AppMotion.fast),
        curve: AppMotion.curve,
        builder: (context, value, child) => CustomPaint(
          painter: _RingPainter(
            value: value,
            track: c.fill,
            fill: reached
                ? c.success
                : target == null
                    ? c.accent.withValues(alpha: 0.6)
                    : c.accent,
          ),
          child: child,
        ),
        child: Padding(
          padding: EdgeInsets.all(diameter * 0.1),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: diameter * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TasbihDhikrText(dhikr.text, size: textSize, maxLines: 2),
                    _Number(count: count, size: numberSize),
                    Text(
                      target == null
                          ? targetLabel(context, null)
                          : context.tr('من ${ltr(formatCount(target))}',
                              'of ${formatCount(target)}'),
                      style: AppTypography.subheadline
                          .copyWith(color: reached ? c.success : c.secondaryLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The count, rolling up as it changes.
class _Number extends StatelessWidget {
  const _Number({required this.count, required this.size});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.tabular(
      AppTypography.largeTitle.copyWith(fontSize: size, height: 1.15),
    ).copyWith(color: context.palette.label);
    return AnimatedSwitcher(
      duration: AppMotion.of(context, const Duration(milliseconds: 160)),
      switchInCurve: AppMotion.curve,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.18), end: Offset.zero)
              .animate(animation),
          child: child,
        ),
      ),
      // Old and new numbers share one slot.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: [...previous, if (current != null) current],
      ),
      child: LtrText(
        formatCount(count),
        key: ValueKey(count),
        style: style,
        maxLines: 1,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.track, required this.fill});

  final double value;
  final Color track;
  final Color fill;

  static const double _stroke = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value.clamp(0, 1),
          false, paint..color = fill);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.track != track || old.fill != fill;
}
