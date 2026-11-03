import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import '../../../../core/design/app_colors.dart';

/// The hero's backdrop: a sky for the time of day, and the city against it
/// — the minaret on the end side, a domed prayer hall, rooftops — down to a
/// solid ground band of [AppColors.prayerSilhouette] [groundHeight] tall,
/// so whatever continues below can pick up that colour without a seam.
class PrayerSkyPainter extends CustomPainter {
  const PrayerSkyPainter({
    required this.sky,
    required this.night,
    required this.textDirection,
  });

  /// Zenith, middle and horizon colours.
  final List<Color> sky;
  final bool night;
  final TextDirection textDirection;

  static const double groundHeight = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final ground = h - groundHeight;
    final horizon = sky.last;
    // [f] is measured from the end edge, so the scene mirrors with the
    // reading direction and the start side stays clear for the title.
    final rtl = textDirection == TextDirection.rtl;
    double x(double f) => (rtl ? f : 1 - f) * w;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
            Offset.zero, Offset(0, h), sky, const [0, 0.55, 1]),
    );

    if (night) {
      final rnd = math.Random(11);
      final star = Paint()..color = AppColors.skyStar;
      for (var i = 0; i < 22; i++) {
        star.color =
            AppColors.skyStar.withValues(alpha: 0.35 + rnd.nextDouble() * 0.55);
        canvas.drawCircle(
            Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.55),
            0.6 + rnd.nextDouble() * 0.7,
            star);
      }
      final moon = Offset(x(0.36), h * 0.16);
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: moon, radius: 8)),
          Path()
            ..addOval(Rect.fromCircle(
                center: moon + Offset(rtl ? 3.5 : -3.5, -2), radius: 7)),
        ),
        Paint()..color = AppColors.skyStar,
      );
    } else {
      final glow = Offset(x(0.62), ground - 18);
      canvas.drawCircle(
        glow,
        w * 0.55,
        Paint()
          ..shader = ui.Gradient.radial(glow, w * 0.55, [
            horizon.withValues(alpha: 0.55),
            horizon.withValues(alpha: 0),
          ]),
      );
    }

    // Distant rooftops, hazed into the horizon.
    final far = Paint()
      ..color = Color.lerp(AppColors.prayerSilhouette, horizon, 0.55)!;
    final rnd = math.Random(7);
    for (var left = 0.0; left < w;) {
      final bw = 14 + rnd.nextDouble() * 20;
      final bh = 10 + rnd.nextDouble() * 16;
      canvas.drawRect(Rect.fromLTWH(left, ground - bh, bw + 1, bh), far);
      if (rnd.nextDouble() < 0.25) {
        canvas.drawCircle(Offset(left + bw / 2, ground - bh), bw * 0.28, far);
      }
      left += bw;
    }

    final near = Paint()..color = AppColors.prayerSilhouette;

    // Near rooftops, low, for an uneven edge.
    for (var left = 0.0; left < w;) {
      final bw = 18 + rnd.nextDouble() * 26;
      final bh = 2 + rnd.nextDouble() * 8;
      canvas.drawRect(Rect.fromLTWH(left, ground - bh, bw + 1, bh), near);
      left += bw;
    }

    // Prayer hall: a block, a drum and a slightly pointed dome.
    final hall = x(0.38);
    final r = w * 0.075;
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(hall, ground - 11), width: w * 0.40, height: 22),
        near);
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(hall, ground - 26), width: r * 2.3, height: 8),
        near);
    final base = ground - 30;
    canvas.drawPath(
      Path()
        ..moveTo(hall - r, base)
        ..cubicTo(hall - r, base - r * 0.9, hall - r * 0.25, base - r * 1.05,
            hall, base - r * 1.18)
        ..cubicTo(hall + r * 0.25, base - r * 1.05, hall + r, base - r * 0.9,
            hall + r, base)
        ..close(),
      near,
    );
    canvas.drawLine(
        Offset(hall, base - r * 1.18),
        Offset(hall, base - r * 1.18 - 7),
        Paint()
          ..color = AppColors.prayerSilhouette
          ..strokeWidth = 1.4);

    // Windows: picked out of the dusk by day, lamplit at night.
    final lit = night
        ? AppColors.skyStar.withValues(alpha: 0.85)
        : Color.lerp(AppColors.prayerSilhouette, horizon, 0.35)!;
    final window = Paint()..color = lit;
    for (var i = -2; i <= 2; i++) {
      canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromCenter(
                center: Offset(hall + i * w * 0.06, ground - 9),
                width: 3,
                height: 7),
            topLeft: const Radius.circular(1.5),
            topRight: const Radius.circular(1.5),
          ),
          window);
    }

    // The minaret: plinth, ribbed shaft, gallery, lantern, cap and spire.
    final mx = x(0.17);
    final mw = math.max(12.0, w * 0.042);
    final top = h * 0.11;
    canvas
      ..drawRect(Rect.fromLTWH(mx - mw * 0.75, ground - 10, mw * 1.5, 10), near)
      ..drawRect(
          Rect.fromLTRB(mx - mw / 2, top + 22, mx + mw / 2, ground - 10), near)
      ..drawRect(Rect.fromLTWH(mx - mw * 0.62, top + 18, mw * 1.24, 4), near)
      ..drawRect(Rect.fromLTWH(mx - mw * 0.4, top + 6, mw * 0.8, 12), near)
      ..drawPath(
          Path()
            ..moveTo(mx - mw * 0.4, top + 6)
            ..quadraticBezierTo(mx, top - 5, mx + mw * 0.4, top + 6)
            ..close(),
          near)
      ..drawLine(
          Offset(mx, top),
          Offset(mx, top - 12),
          Paint()
            ..color = AppColors.prayerSilhouette
            ..strokeWidth = 1.4);
    final rib = Paint()
      ..color = Color.lerp(AppColors.prayerSilhouette, horizon, 0.35)!
          .withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (final dx in [-mw * 0.18, mw * 0.18]) {
      canvas.drawLine(
          Offset(mx + dx, top + 30), Offset(mx + dx, ground - 22), rib);
    }
    canvas.drawRect(
        Rect.fromLTWH(mx - mw * 0.12, top + 8, mw * 0.24, 8), window);

    canvas.drawRect(Rect.fromLTWH(0, ground, w, groundHeight), near);

    // Shade the top so white text reads on any sky.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h * 0.55), [
          AppColors.shadow.withValues(alpha: 0.28),
          AppColors.shadow.withValues(alpha: 0),
        ]),
    );
  }

  @override
  bool shouldRepaint(PrayerSkyPainter old) =>
      old.sky != sky ||
      old.night != night ||
      old.textDirection != textDirection;
}

/// The countdown ring: a track, the elapsed arc clockwise from the top,
/// and a gold knob riding its head.
class PrayerRingPainter extends CustomPainter {
  const PrayerRingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.knob,
    required this.rim,
    required this.shadow,
    this.stroke = 12,
  });

  /// 0…1.
  final double progress;
  final Color color;
  final Color track;
  final Color knob;
  final Color rim;
  final Color shadow;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Inset by a full stroke so the knob, wider than the ring, still fits.
    final radius = size.shortestSide / 2 - stroke;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, line..color = track);
    final sweep = 2 * math.pi * progress;
    if (progress > 0) {
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -math.pi / 2,
          sweep,
          false,
          line
            ..color = color
            ..strokeCap = StrokeCap.round);
    }
    final head = center +
        Offset(math.cos(sweep - math.pi / 2), math.sin(sweep - math.pi / 2)) *
            radius;
    canvas
      ..drawCircle(
          head + const Offset(0, 1.5),
          stroke * 0.8,
          Paint()
            ..color = shadow
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3))
      ..drawCircle(head, stroke * 0.8, Paint()..color = rim)
      ..drawCircle(head, stroke * 0.55, Paint()..color = knob);
  }

  @override
  bool shouldRepaint(PrayerRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.knob != knob ||
      old.rim != rim ||
      old.shadow != shadow;
}

/// The two lanterns' current angles; repaints [PrayerLanternsPainter].
class LanternSway extends ChangeNotifier {
  /// Radians, clockwise; the lantern on the short chain, then the long.
  double shortChain = 0;
  double longChain = 0;

  void set(double shortChain, double longChain) {
    this.shortChain = shortChain;
    this.longChain = longChain;
    notifyListeners();
  }
}

/// Two Ramadan lanterns (fawanees) hanging from the card's top corners on
/// chains of different lengths: a gilded dome, collar and foot around
/// three panes of candlelit amber glass, the middle one with a pointed
/// arch, all in a soft halo of their own light. [sway] tilts each one
/// about the top of its chain.
class PrayerLanternsPainter extends CustomPainter {
  PrayerLanternsPainter({required this.gold, required this.glow, this.sway})
      : super(repaint: sway);

  /// Current swing; null hangs them straight.
  final LanternSway? sway;

  /// The metalwork and chains.
  final Color gold;

  /// Strength of the halo, 0…1: stronger on dark surfaces.
  final double glow;

  /// Lantern width.
  static const double _w = 24;

  /// From the side edges to each lantern's axis.
  static const double _inset = 34;

  @override
  void paint(Canvas canvas, Size size) {
    _swung(canvas, _inset, 6, sway?.shortChain ?? 0);
    _swung(canvas, size.width - _inset, 22, sway?.longChain ?? 0);
  }

  void _swung(Canvas canvas, double cx, double drop, double angle) {
    canvas
      ..save()
      ..translate(cx, 0)
      ..rotate(angle)
      ..translate(-cx, 0);
    _lantern(canvas, cx, drop);
    canvas.restore();
  }

  /// One lantern on the axis [cx], its ring [drop] below the top edge.
  void _lantern(Canvas canvas, double cx, double drop) {
    const w = _w;
    final metal = Paint()..color = gold;
    final line = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    // Chain: oval links alternating with links seen edge-on.
    var face = true;
    for (var y = 0.0; y < drop; y += 4) {
      if (face) {
        canvas.drawOval(
            Rect.fromCenter(center: Offset(cx, y + 2), width: 2.6, height: 5),
            line);
      } else {
        canvas.drawLine(Offset(cx, y), Offset(cx, y + 4), line);
      }
      face = !face;
    }

    final ringY = drop + w * 0.09;
    canvas.drawCircle(Offset(cx, ringY), w * 0.09, line);
    canvas.drawCircle(Offset(cx, drop + w * 0.26), w * 0.06, metal);

    // Dome, slightly onion-shaped, on a collar.
    final domeTop = drop + w * 0.3;
    final domeBase = drop + w * 0.62;
    canvas.drawPath(
      Path()
        ..moveTo(cx - w * 0.3, domeBase)
        ..cubicTo(cx - w * 0.32, domeBase - w * 0.2, cx - w * 0.06,
            domeTop + w * 0.12, cx, domeTop)
        ..cubicTo(cx + w * 0.06, domeTop + w * 0.12, cx + w * 0.32,
            domeBase - w * 0.2, cx + w * 0.3, domeBase)
        ..close(),
      metal,
    );
    final top = domeBase + w * 0.08;
    canvas.drawRect(
        Rect.fromLTRB(cx - w * 0.38, domeBase, cx + w * 0.38, top), metal);

    // Body: six-sided profile, widest in the middle.
    const h = w * 0.95;
    final bottom = top + h;
    final body = Path()
      ..addPolygon([
        Offset(cx - w * 0.3, top),
        Offset(cx - w * 0.44, top + h * 0.28),
        Offset(cx - w * 0.44, top + h * 0.72),
        Offset(cx - w * 0.3, bottom),
        Offset(cx + w * 0.3, bottom),
        Offset(cx + w * 0.44, top + h * 0.72),
        Offset(cx + w * 0.44, top + h * 0.28),
        Offset(cx + w * 0.3, top),
      ], true);
    final heart = Offset(cx, top + h * 0.5);

    canvas.drawCircle(
      heart,
      w * 1.3,
      Paint()
        ..shader = ui.Gradient.radial(heart, w * 1.3, [
          AppColors.lanternGlass.withValues(alpha: glow),
          AppColors.lanternGlass.withValues(alpha: 0),
        ]),
    );
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.radial(heart, w * 0.5, [
          AppColors.lanternFlame,
          AppColors.lanternGlass,
          Color.lerp(AppColors.lanternGlass, AppColors.prayerSilhouette, 0.35)!,
        ], const [
          0,
          0.55,
          1
        ]),
    );

    // Panes, the middle one arched, and the frame round them.
    for (final dx in [-w * 0.15, w * 0.15]) {
      canvas.drawLine(Offset(cx + dx, top), Offset(cx + dx, bottom), line);
    }
    final archTop = top + h * 0.2;
    final archFoot = bottom - h * 0.14;
    canvas.drawPath(
      Path()
        ..moveTo(cx - w * 0.09, archFoot)
        ..lineTo(cx - w * 0.09, archTop + w * 0.12)
        ..quadraticBezierTo(cx - w * 0.09, archTop + w * 0.02, cx, archTop)
        ..quadraticBezierTo(cx + w * 0.09, archTop + w * 0.02, cx + w * 0.09,
            archTop + w * 0.12)
        ..lineTo(cx + w * 0.09, archFoot),
      line..color = gold.withValues(alpha: 0.75),
    );
    line.color = gold;
    canvas.drawPath(body, line..strokeWidth = 1.2);

    // Foot: a band, a cone and a drop.
    final foot = bottom + w * 0.07;
    canvas.drawRect(
        Rect.fromLTRB(cx - w * 0.32, bottom, cx + w * 0.32, foot), metal);
    final tip = foot + w * 0.32;
    canvas.drawPath(
      Path()
        ..addPolygon([
          Offset(cx - w * 0.26, foot),
          Offset(cx + w * 0.26, foot),
          Offset(cx, tip),
        ], true),
      metal,
    );
    canvas.drawCircle(Offset(cx, tip + w * 0.06), w * 0.05, metal);
  }

  @override
  bool shouldRepaint(PrayerLanternsPainter old) =>
      old.gold != gold || old.glow != glow || old.sway != sway;
}
