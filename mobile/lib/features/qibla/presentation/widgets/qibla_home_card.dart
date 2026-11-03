import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../qibla_providers.dart';
import '../screens/qibla_screen.dart';
import 'compass_dial.dart' show paintKaaba;
import 'qibla_labels.dart';

/// Home's Qibla card: the bearing from north and the distance to Makkah,
/// beside a small map-style dial — north up, the Kaaba on the rim where the
/// Qibla lies. It is a fixed diagram, not a live compass; tapping opens the
/// compass. Without a location it says how to get one.
class QiblaHomeCard extends ConsumerWidget {
  const QiblaHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(qiblaInfoProvider);
    final c = context.palette;
    final green = c.resolve(AppColors.prayerGreen);

    return AppCard(
      onTap: () => context.push(QiblaScreen.path),
      semanticLabel: info == null
          ? context.tr('اتجاه القبلة', 'Qibla direction')
          : context.tr('اتجاه القبلة، ${qiblaFromNorth(context, info.bearing)}',
              'Qibla direction, ${qiblaFromNorth(context, info.bearing)}'),
      borderColor: c.gold.withValues(alpha: 0.35),
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.ml, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('اتجاه القبلة', 'Qibla direction'),
                  style: AppTypography.headline
                      .weight(FontWeight.w700)
                      .copyWith(color: c.label),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (info != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      LtrText(
                        degrees(info.bearing),
                        style: AppTypography.tabular(AppTypography.title1)
                            .copyWith(color: green, height: 1.1),
                      ),
                      const SizedBox(width: AppSpacing.xs + 2),
                      Flexible(
                        child: Text(
                          context.tr('من الشمال', 'from north'),
                          style: AppTypography.footnote
                              .copyWith(color: c.secondaryLabel),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    context.tr(
                        '${ltr(kilometres(info.distanceKm))} كم إلى مكة المكرمة',
                        '${kilometres(info.distanceKm)} km to Makkah'),
                    style: AppTypography.footnote
                        .copyWith(color: c.secondaryLabel),
                  ),
                ] else
                  Text(
                    context.tr('حدّد موقعك لمعرفة اتجاه القبلة',
                        'Set your location to find the Qibla'),
                    style: AppTypography.footnote
                        .copyWith(color: c.secondaryLabel),
                  ),
                const SizedBox(height: AppSpacing.ms),
                // The whole card is the tap target; the pill says what it
                // does.
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.ms, vertical: AppSpacing.xs + 1),
                  decoration: ShapeDecoration(
                    color: c.accentTint,
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.compass_fill, size: 15, color: green),
                      const SizedBox(width: AppSpacing.xs + 2),
                      Flexible(
                        child: Text(
                          context.tr('افتح البوصلة', 'Open the compass'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.footnote
                              .weight(FontWeight.w600)
                              .copyWith(color: green),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          ExcludeSemantics(
            child: CustomPaint(
              size: const Size.square(112),
              painter: _QiblaDialPainter(
                bearing: info?.bearing,
                ring: c.gold,
                tick: c.tertiaryLabel,
                needle: green,
                face: c.secondaryGroupedBackground,
                north: TextPainter(
                  text: TextSpan(
                    text: cardinals(context).first,
                    style: AppTypography.caption2
                        .weight(FontWeight.w700)
                        .copyWith(color: c.gold, height: 1),
                  ),
                  textDirection: TextDirection.ltr,
                )..layout(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dial: a gold ring with ticks, a gilded crescent and five-pointed
/// star at its heart (horns to north), north marked at the top, and — when the
/// [bearing] is known — a needle from the centre to the Kaaba on the rim.
class _QiblaDialPainter extends CustomPainter {
  const _QiblaDialPainter({
    required this.bearing,
    required this.ring,
    required this.tick,
    required this.needle,
    required this.face,
    required this.north,
  });

  /// Degrees clockwise from north; null draws the dial alone.
  final double? bearing;
  final Color ring;
  final Color tick;
  final Color needle;

  /// The card's fill, used as a halo so the Kaaba sits cleanly on the ring.
  final Color face;
  final TextPainter north;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 10;
    Offset at(double degrees, double radius) {
      final a = (degrees - 90) * math.pi / 180;
      return center + Offset(math.cos(a), math.sin(a)) * radius;
    }

    final stroke = Paint()..style = PaintingStyle.stroke;
    canvas.drawCircle(
        center,
        r,
        stroke
          ..color = ring
          ..strokeWidth = 1.5);
    canvas.drawCircle(
        center,
        r - 5,
        stroke
          ..color = ring.withValues(alpha: 0.35)
          ..strokeWidth = 0.8);

    for (var d = 0; d < 360; d += 15) {
      if (d == 0) continue;
      final major = d % 90 == 0;
      canvas.drawLine(
        at(d.toDouble(), r - 5),
        at(d.toDouble(), r - (major ? 12 : 8)),
        Paint()
          ..color = major ? ring : tick
          ..strokeWidth = major ? 1.4 : 1
          ..strokeCap = StrokeCap.round,
      );
    }

    // The hilal at the heart of the dial, horns up towards north.
    paintHilal(canvas, center, r * 0.5, ring);

    // North: a small gold wedge on the ring and its letter inside.
    canvas.drawPath(
      Path()..addPolygon([at(0, r + 6), at(-6, r - 3), at(6, r - 3)], true),
      Paint()..color = ring,
    );
    north.paint(
        canvas, at(0, r - 20) - Offset(north.width / 2, north.height / 2));

    final b = bearing;
    if (b == null) return;
    final tip = at(b, r);
    canvas.drawLine(
      center,
      at(b, r - 13),
      Paint()
        ..color = needle
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 4, Paint()..color = ring);
    canvas.drawCircle(center, 1.6, Paint()..color = face);
    canvas.drawCircle(tip, 13, Paint()..color = face);
    canvas.drawCircle(
        tip,
        13,
        stroke
          ..color = needle
          ..strokeWidth = 1.5);
    paintKaaba(canvas, tip, 15);
  }

  @override
  bool shouldRepaint(_QiblaDialPainter old) =>
      old.bearing != bearing ||
      old.ring != ring ||
      old.tick != tick ||
      old.needle != needle ||
      old.face != face ||
      old.north.text != north.text;
}
