import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import '../app_colors.dart';
import 'app_ornaments.dart';

/// What a shortcut card shows behind its text, in the grammar of the
/// prayer-times hero: a sky washed in the card's own jewel tone and a
/// silhouette of its subject against it, kept to the end side so the
/// glyph and text on the start side stay clear.
enum TileScene {
  /// Sun half-risen over dunes, rays fanning out. Morning adhkar.
  sunrise,

  /// Crescent and first stars over the last glow. Evening adhkar.
  dusk,

  /// A sleeping town under a crescent and many stars. Before sleep.
  night,

  /// Sunlight through an arched window. On waking up.
  window,

  /// A closed Mushaf, gilded border and medallion. The Mushaf.
  mushaf,

  /// An open Mushaf on its folding stand (rahl). Khatma, Quranic duas.
  openMushaf,

  /// Sound spreading in rings. Listening to reciters.
  listen,

  /// An Andalusian arcade of horseshoe arches. The Quran's surahs.
  arcade,

  /// Ribbon bookmarks hanging from the top. Bookmarks, favourites.
  ribbons,

  /// A trail up a hill to a flag. Daily goal.
  summit,

  /// A minaret and dome at first light. Fajr Call.
  minaret,

  /// A string of prayer beads. Tasbih.
  beads,

  /// A mihrab with a hanging lamp. After prayer.
  mihrab,

  /// A domed mosque between two minarets. The mosque.
  mosque,

  /// Cubic houses with arched doors. Home.
  houses,

  /// A fountain spilling into its basin. Ablution.
  water,

  /// Date palms heavy with fruit. Food and drink.
  palms,

  /// A plane on its dashed route over a far city. Travel.
  flight,

  /// A road running to the horizon between palms. Riding.
  road,

  /// Clouds and slanting rain. Rain and wind.
  rain,

  /// Light breaking out from behind a cloud. Distress and worry.
  rays,

  /// A path forking in two. Istikhara.
  paths,

  /// A seedling in the sun. Visiting the sick.
  sprout,

  /// A gilded eight-pointed star among small ones. Prophetic duas.
  star,
}

/// Paints a [TileScene] for [tone]. Same in both themes: it is a picture.
/// Measured from the end edge, so it mirrors with [textDirection].
class TileScenePainter extends CustomPainter {
  const TileScenePainter({
    required this.scene,
    required this.tone,
    required this.textDirection,
  });

  final TileScene scene;

  /// The card's jewel tone (light value), e.g. [AppColors.tileYellow].
  final Color tone;
  final TextDirection textDirection;

  /// What every sky deepens towards.
  static const Color deep = Color(0xFF071A17);

  static const Set<TileScene> _nightScenes = {
    TileScene.dusk,
    TileScene.night,
    TileScene.star,
  };

  /// The flat colour under the scene: what the card reads as before it is
  /// painted, and the fill behind its text.
  static Color baseFor(Color tone) => Color.lerp(tone, deep, 0.32)!;

  @override
  void paint(Canvas canvas, Size size) {
    final night = _nightScenes.contains(scene);
    final s = _Stage(
      canvas: canvas,
      size: size,
      rtl: textDirection == TextDirection.rtl,
      tone: tone,
      night: night,
    );
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
          Color.lerp(tone, deep, night ? 0.8 : 0.6)!,
          Color.lerp(tone, deep, night ? 0.5 : 0.26)!,
        ]),
    );

    switch (scene) {
      case TileScene.sunrise:
        _sunrise(s);
      case TileScene.dusk:
        _dusk(s);
      case TileScene.night:
        _night(s);
      case TileScene.window:
        _window(s);
      case TileScene.mushaf:
        _mushaf(s);
      case TileScene.openMushaf:
        _openMushaf(s);
      case TileScene.listen:
        _listen(s);
      case TileScene.arcade:
        _arcade(s);
      case TileScene.ribbons:
        _ribbons(s);
      case TileScene.summit:
        _summit(s);
      case TileScene.minaret:
        _minaretDawn(s);
      case TileScene.beads:
        _beads(s);
      case TileScene.mihrab:
        _mihrab(s);
      case TileScene.mosque:
        _mosque(s);
      case TileScene.houses:
        _houses(s, lit: false);
      case TileScene.water:
        _water(s);
      case TileScene.palms:
        _palms(s);
      case TileScene.flight:
        _flight(s);
      case TileScene.road:
        _road(s);
      case TileScene.rain:
        _rain(s);
      case TileScene.rays:
        _rays(s);
      case TileScene.paths:
        _paths(s);
      case TileScene.sprout:
        _sprout(s);
      case TileScene.star:
        _star(s);
    }

    // Shade the bottom so the title and caption read on any scene.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
            Offset(0, size.height * 0.4), Offset(0, size.height), [
          deep.withValues(alpha: 0),
          deep.withValues(alpha: 0.42),
        ]),
    );
  }

  // ─── Scenes ──────────────────────────────────────────────────────────────

  void _sunrise(_Stage s) {
    final c = Offset(s.x(0.26), s.ground);
    final r = s.u * 0.17;
    s.glow(c, s.u * 1.1, 0.7);
    final ray = Paint()
      ..color = AppColors.lanternFlame.withValues(alpha: 0.45)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final a = math.pi + (i + 0.5) * math.pi / 9;
      final d = Offset(math.cos(a), math.sin(a));
      s.canvas
          .drawLine(c + d * r * 1.35, c + d * r * (i.isEven ? 2.3 : 1.9), ray);
    }
    s.sun(c, r);
    s.dunes();
  }

  void _dusk(_Stage s) {
    s.glow(Offset(s.x(0.45), s.ground), s.u * 1.0, 0.45,
        color: AppColors.lanternGlass);
    s.stars(9, seed: 3);
    s.moon(Offset(s.x(0.24), s.h * 0.3), s.u * 0.1);
    s.dunes();
  }

  void _night(_Stage s) {
    s.stars(18, seed: 5);
    s.moon(Offset(s.x(0.2), s.h * 0.26), s.u * 0.09);
    _houses(s, lit: true);
  }

  void _window(_Stage s) {
    // A wall with an arched opening; the morning beyond it.
    final ww = s.u * 0.42;
    final wh = s.u * 0.62;
    final cx = s.x(0.26);
    final bottom = s.ground;
    final open =
        horseshoeArch(Size(ww, wh), 0).shift(Offset(cx - ww / 2, bottom - wh));
    s.canvas.save();
    s.canvas.clipPath(open);
    s.glow(Offset(cx, bottom - wh * 0.2), ww * 1.2, 0.9);
    s.sun(Offset(cx, bottom - wh * 0.18), ww * 0.22);
    s.canvas.drawRect(
        Rect.fromLTRB(cx - ww, bottom - wh * 0.12, cx + ww, bottom),
        Paint()..color = s.far);
    s.canvas.restore();
    // Sunlight falling into the room through the opening.
    s.canvas.drawPath(
      Path()
        ..moveTo(cx - ww * 0.4, bottom)
        ..lineTo(cx + ww * 0.4, bottom)
        ..lineTo(cx + ww * 0.9 * -s.e + ww * 0.5, s.h)
        ..lineTo(cx + ww * 0.9 * -s.e - ww * 0.5, s.h)
        ..close(),
      Paint()..color = AppColors.lanternFlame.withValues(alpha: 0.12),
    );
    // Frame: a gold line round the arch and a sill.
    s.canvas.drawPath(
        open,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = AppColors.gold.color.withValues(alpha: 0.8));
    s.canvas.drawRect(
        Rect.fromCenter(
            center: Offset(cx, bottom + 1.5), width: ww * 1.2, height: 3),
        Paint()..color = AppColors.gold.color.withValues(alpha: 0.8));
  }

  void _mushaf(_Stage s) {
    final bw = s.u * 0.36;
    final bh = s.u * 0.5;
    final c = Offset(s.x(0.27), s.ground - bh / 2 - 1);
    s.glow(c, s.u * 0.9, 0.5);
    s.canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(-0.1 * s.e);
    final cover = Rect.fromCenter(center: Offset.zero, width: bw, height: bh);
    final gold = AppColors.gold.color;
    // Page edges peeking out, then the leather cover.
    s.canvas.drawRRect(
        RRect.fromRectAndRadius(
            cover.translate(s.e * 2.5, 2.5), const Radius.circular(2)),
        Paint()..color = AppColors.skyStar.withValues(alpha: 0.85));
    s.canvas.drawRRect(
        RRect.fromRectAndRadius(cover, const Radius.circular(2.5)),
        Paint()..color = Color.lerp(s.tone, TileScenePainter.deep, 0.55)!);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = gold
      ..strokeWidth = 1;
    s.canvas.drawRect(cover.deflate(bw * 0.09), line);
    s.canvas.drawRect(cover.deflate(bw * 0.14), line..strokeWidth = 0.6);
    // The medallion: a gold star in a ring.
    final mr = bw * 0.2;
    s.canvas
      ..drawCircle(Offset.zero, mr * 1.15, line..strokeWidth = 1)
      ..drawPath(rubElHizb(Offset.zero, mr), Paint()..color = gold)
      ..drawCircle(Offset.zero, mr * 0.35,
          Paint()..color = Color.lerp(s.tone, TileScenePainter.deep, 0.55)!);
    // Small lozenges top and bottom of the medallion.
    for (final dy in [-mr * 2.1, mr * 2.1]) {
      s.canvas.drawPath(
          Path()
            ..addPolygon([
              Offset(0, dy - 3),
              Offset(3, dy),
              Offset(0, dy + 3),
              Offset(-3, dy),
            ], true),
          Paint()..color = gold);
    }
    s.canvas.restore();
    s.flat();
  }

  void _openMushaf(_Stage s) {
    final cx = s.x(0.27);
    final pw = s.u * 0.25;
    final ph = s.u * 0.15;
    final top = s.ground - s.u * 0.42;
    s.glow(Offset(cx, top), s.u * 0.95, 0.65);

    // The rahl: two boards crossed in an X, in warm wood.
    final wood = Paint()
      ..color = Color.lerp(AppColors.lanternGlass, TileScenePainter.deep, 0.55)!
      ..strokeWidth = s.u * 0.045
      ..strokeCap = StrokeCap.round;
    s.canvas
      ..drawLine(Offset(cx - pw * 0.85, s.ground),
          Offset(cx + pw * 0.55, top + ph), wood)
      ..drawLine(Offset(cx + pw * 0.85, s.ground),
          Offset(cx - pw * 0.55, top + ph), wood);

    // The open pages, cream, with a gold edge and lines of text.
    final gold = AppColors.gold.color;
    for (final side in [-1.0, 1.0]) {
      final page = Path()
        ..moveTo(cx, top + ph * 0.25)
        ..quadraticBezierTo(
            cx + side * pw * 0.5, top - ph * 0.05, cx + side * pw, top)
        ..lineTo(cx + side * pw, top + ph)
        ..quadraticBezierTo(
            cx + side * pw * 0.5, top + ph * 0.95, cx, top + ph * 1.25)
        ..close();
      s.canvas
        ..drawPath(page, Paint()..color = AppColors.skyStar)
        ..drawPath(
            page,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = gold);
      final text = Paint()
        ..color = s.tone.withValues(alpha: 0.55)
        ..strokeWidth = 0.9;
      for (var i = 1; i <= 3; i++) {
        final y = top + ph * (0.22 + i * 0.2);
        s.canvas.drawLine(Offset(cx + side * pw * 0.15, y + ph * 0.08),
            Offset(cx + side * pw * 0.85, y), text);
      }
    }
    s.flat();
  }

  void _listen(_Stage s) {
    final c = Offset(s.x(0.06), s.ground - s.u * 0.12);
    s.glow(c, s.u * 0.8, 0.5);
    for (var i = 0; i < 5; i++) {
      final r = s.u * (0.14 + i * 0.13);
      s.canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        s.e > 0 ? math.pi * 0.95 : -math.pi * 0.45,
        math.pi * 0.5,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = AppColors.lanternFlame.withValues(alpha: 0.75 - i * 0.13),
      );
    }
    s.canvas.drawCircle(c, s.u * 0.05, Paint()..color = AppColors.lanternFlame);
    s.dunes();
  }

  void _arcade(_Stage s) {
    s.glow(Offset(s.x(0.25), s.ground), s.u * 1.0, 0.6);
    final wallTop = s.ground - s.u * 0.5;
    final start = s.x(0.5);
    final end = s.x(0);
    final wall = Path()
      ..addRect(Rect.fromLTRB(
          math.min(start, end), wallTop, math.max(start, end), s.ground));
    final aw = s.u * 0.15;
    final ah = s.u * 0.36;
    var openings = Path();
    for (var i = 0; i < 3; i++) {
      final cx = s.x(0.1 + i * 0.13 * s.u / s.w * 1.4);
      openings = Path.combine(
          PathOperation.union,
          openings,
          horseshoeArch(Size(aw, ah), 0)
              .shift(Offset(cx - aw / 2, s.ground - ah)));
    }
    final building = Path.combine(PathOperation.difference, wall, openings);
    s.canvas.drawPath(building, Paint()..color = s.sil);
    // Crenellations along the top.
    final merlon = Paint()..color = s.sil;
    final lo = math.min(start, end);
    final hi = math.max(start, end);
    for (var x = lo + 2; x < hi - 4; x += s.u * 0.09) {
      s.canvas.drawRect(
          Rect.fromLTWH(x, wallTop - s.u * 0.05, s.u * 0.05, s.u * 0.05),
          merlon);
    }
    // A thin gold band under the merlons.
    s.canvas.drawRect(
        Rect.fromLTRB(lo, wallTop + s.u * 0.04, hi, wallTop + s.u * 0.04 + 1),
        Paint()..color = AppColors.gold.color.withValues(alpha: 0.6));
    s.flat();
  }

  void _ribbons(_Stage s) {
    final colors = [
      AppColors.gold.color,
      AppColors.skyStar.withValues(alpha: 0.9),
      Color.lerp(s.tone, AppColors.skyStar, 0.45)!,
    ];
    final lengths = [0.78, 0.6, 0.7];
    final rw = s.u * 0.085;
    for (var i = 0; i < 3; i++) {
      final cx = s.x(0.1 + i * 0.13 * s.u / s.w * 1.6);
      final bottom = s.h * lengths[i];
      s.canvas.drawPath(
        Path()
          ..moveTo(cx - rw / 2, 0)
          ..lineTo(cx + rw / 2, 0)
          ..lineTo(cx + rw / 2, bottom)
          ..lineTo(cx, bottom - rw * 0.6)
          ..lineTo(cx - rw / 2, bottom)
          ..close(),
        Paint()..color = colors[i],
      );
      // A stitched fold line.
      s.canvas.drawLine(
          Offset(cx - rw / 2, s.h * 0.08),
          Offset(cx + rw / 2, s.h * 0.08),
          Paint()
            ..color = TileScenePainter.deep.withValues(alpha: 0.25)
            ..strokeWidth = 1);
    }
  }

  void _summit(_Stage s) {
    final peak = Offset(s.x(0.24), s.ground - s.u * 0.42);
    s.glow(peak, s.u * 0.7, 0.4);
    final hill = Path()
      ..moveTo(s.x(0.75), s.h)
      ..quadraticBezierTo(s.x(0.45), s.ground - s.u * 0.1, peak.dx, peak.dy)
      ..quadraticBezierTo(
          s.x(0.08), peak.dy + s.u * 0.08, s.x(-0.05), s.ground - s.u * 0.2)
      ..lineTo(s.x(-0.05), s.h)
      ..close();
    s.canvas.drawPath(hill, Paint()..color = s.sil);
    // The trail: dots climbing to the top.
    final dot = Paint()..color = AppColors.skyStar.withValues(alpha: 0.6);
    for (var i = 0; i < 6; i++) {
      final t = i / 6;
      final p = Offset.lerp(Offset(s.x(0.55), s.ground), peak, t)! +
          Offset(math.sin(t * math.pi * 2) * s.u * 0.05, s.u * 0.03);
      s.canvas.drawCircle(p, 1.2, dot);
    }
    // The flag, fluttering towards the start side.
    final pole = s.u * 0.24;
    s.canvas.drawLine(
        peak,
        peak - Offset(0, pole),
        Paint()
          ..color = AppColors.skyStar
          ..strokeWidth = 1.4);
    final f = -s.e * s.u * 0.16;
    s.canvas.drawPath(
      Path()
        ..moveTo(peak.dx, peak.dy - pole)
        ..quadraticBezierTo(peak.dx + f * 0.5, peak.dy - pole - 3, peak.dx + f,
            peak.dy - pole + s.u * 0.04)
        ..quadraticBezierTo(peak.dx + f * 0.5, peak.dy - pole + s.u * 0.06,
            peak.dx, peak.dy - pole + s.u * 0.1)
        ..close(),
      Paint()..color = AppColors.gold.color,
    );
  }

  void _minaretDawn(_Stage s) {
    s.glow(Offset(s.x(0.4), s.ground), s.u * 1.6, 0.75);
    s.sun(Offset(s.x(0.42), s.ground), s.u * 0.16);
    final p = Paint()..color = s.sil;
    // Dome on its hall.
    final hall = s.x(0.36);
    final r = s.u * 0.2;
    s.canvas.drawRect(
        Rect.fromCenter(
            center: Offset(hall, s.ground - r * 0.4),
            width: r * 3.6,
            height: r * 0.8),
        p);
    final base = s.ground - r * 0.8;
    s.canvas.drawPath(
      Path()
        ..moveTo(hall - r, base)
        ..cubicTo(hall - r, base - r * 0.9, hall - r * 0.25, base - r * 1.05,
            hall, base - r * 1.2)
        ..cubicTo(hall + r * 0.25, base - r * 1.05, hall + r, base - r * 0.9,
            hall + r, base)
        ..close(),
      p,
    );
    _minaretAt(s, s.x(0.12), s.h * 0.12, s.u * 0.1);
    s.flat();
  }

  /// A minaret of shaft width [mw] on [cx], its spire tip at [top].
  void _minaretAt(_Stage s, double cx, double top, double mw) {
    final p = Paint()..color = s.sil;
    final g = s.ground;
    s.canvas
      ..drawRect(Rect.fromLTRB(cx - mw / 2, top + mw * 2.6, cx + mw / 2, g), p)
      ..drawRect(
          Rect.fromLTWH(cx - mw * 0.66, top + mw * 2.2, mw * 1.32, mw * 0.4), p)
      ..drawRect(
          Rect.fromLTWH(cx - mw * 0.4, top + mw * 1.1, mw * 0.8, mw * 1.1), p)
      ..drawPath(
          Path()
            ..moveTo(cx - mw * 0.45, top + mw * 1.1)
            ..quadraticBezierTo(
                cx, top + mw * 0.1, cx + mw * 0.45, top + mw * 1.1)
            ..close(),
          p)
      ..drawLine(
          Offset(cx, top),
          Offset(cx, top + mw * 0.6),
          Paint()
            ..color = s.sil
            ..strokeWidth = 1.2)
      ..drawRect(
          Rect.fromLTWH(cx - mw * 0.12, top + mw * 1.35, mw * 0.24, mw * 0.6),
          Paint()..color = AppColors.lanternFlame.withValues(alpha: 0.8));
  }

  void _beads(_Stage s) {
    final a = Offset(s.x(0.04), s.h * 0.08);
    final b = Offset(s.x(0.46), s.h * 0.02);
    final sag = s.h * 0.62;
    const n = 15;
    final r = math.max(2.6, s.u * 0.05);
    Offset at(double t) {
      final p = Offset.lerp(a, b, t)!;
      return p + Offset(0, math.sin(t * math.pi) * sag);
    }

    s.glow(at(0.5), s.u * 0.8, 0.35);
    s.canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(
            (a.dx + b.dx) / 2, (a.dy + b.dy) / 2 + sag * 2, b.dx, b.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = AppColors.skyStar.withValues(alpha: 0.5),
    );
    for (var i = 0; i <= n; i++) {
      final p = at(i / n);
      s.canvas.drawCircle(
          p,
          r,
          Paint()
            ..shader =
                ui.Gradient.radial(p - Offset(r * 0.35, r * 0.35), r * 1.3, [
              AppColors.lanternFlame,
              AppColors.lanternGlass,
              Color.lerp(AppColors.lanternGlass, TileScenePainter.deep, 0.5)!,
            ], const [
              0,
              0.45,
              1
            ]));
    }
    // The tassel under the middle bead.
    final m = at(0.5) + Offset(0, r);
    final gold = AppColors.gold.color;
    s.canvas.drawCircle(m + Offset(0, r * 1.2), r * 0.9, Paint()..color = gold);
    for (var i = -2; i <= 2; i++) {
      s.canvas.drawLine(
          m + Offset(0, r * 2),
          m + Offset(i * r * 0.35, r * 5),
          Paint()
            ..color = gold
            ..strokeWidth = 0.9);
    }
  }

  void _mihrab(_Stage s) {
    final cx = s.x(0.26);
    final mw = s.u * 0.4;
    final mh = math.min(s.u * 0.78, s.ground - 6);
    final niche = horseshoeArch(Size(mw, mh), 0)
        .shift(Offset(cx - mw / 2, s.ground - mh));
    // Wall round the niche, the niche lit from within.
    s.canvas.drawPath(niche,
        Paint()..color = Color.lerp(s.tone, TileScenePainter.deep, 0.15)!);
    s.canvas.save();
    s.canvas.clipPath(niche);
    s.glow(Offset(cx, s.ground - mh * 0.45), mw, 0.55);
    s.canvas.restore();
    s.canvas.drawPath(
        niche,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.gold.color);
    s.canvas.drawPath(
        horseshoeArch(Size(mw * 1.22, mh * 1.1), 0)
            .shift(Offset(cx - mw * 0.61, s.ground - mh * 1.1)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = AppColors.gold.color.withValues(alpha: 0.55));
    // The lamp on its chain.
    final lampY = s.ground - mh * 0.42;
    final chainTop = s.ground - mh + mw * 0.12;
    s.canvas.drawLine(
        Offset(cx, chainTop),
        Offset(cx, lampY - mw * 0.08),
        Paint()
          ..color = AppColors.gold.color
          ..strokeWidth = 0.8);
    s.canvas.drawPath(
      Path()
        ..moveTo(cx - mw * 0.14, lampY - mw * 0.08)
        ..lineTo(cx + mw * 0.14, lampY - mw * 0.08)
        ..quadraticBezierTo(
            cx + mw * 0.12, lampY + mw * 0.1, cx, lampY + mw * 0.12)
        ..quadraticBezierTo(
            cx - mw * 0.12, lampY + mw * 0.1, cx - mw * 0.14, lampY - mw * 0.08)
        ..close(),
      Paint()..color = AppColors.lanternGlass,
    );
    s.canvas.drawCircle(
        Offset(cx, lampY), mw * 0.05, Paint()..color = AppColors.lanternFlame);
    s.flat();
  }

  void _mosque(_Stage s) {
    s.glow(Offset(s.x(0.26), s.ground), s.u * 1.0, 0.55);
    s.stars(4, seed: 9);
    final p = Paint()..color = s.sil;
    final hall = s.x(0.27);
    final r = s.u * 0.17;
    s.canvas.drawRect(
        Rect.fromCenter(
            center: Offset(hall, s.ground - r * 0.5),
            width: r * 3.2,
            height: r),
        p);
    final base = s.ground - r;
    s.canvas.drawPath(
      Path()
        ..moveTo(hall - r, base)
        ..cubicTo(hall - r, base - r * 0.9, hall - r * 0.25, base - r * 1.05,
            hall, base - r * 1.25)
        ..cubicTo(hall + r * 0.25, base - r * 1.05, hall + r, base - r * 0.9,
            hall + r, base)
        ..close(),
      p,
    );
    paintHilal(s.canvas, Offset(hall, base - r * 1.25 - s.u * 0.06),
        s.u * 0.035, AppColors.gold.color);
    final win = Paint()..color = AppColors.lanternFlame.withValues(alpha: 0.75);
    for (var i = -1; i <= 1; i++) {
      s.canvas.drawRRect(
          RRect.fromRectAndCorners(
              Rect.fromCenter(
                  center: Offset(hall + i * r * 0.8, s.ground - r * 0.45),
                  width: 3,
                  height: r * 0.5),
              topLeft: const Radius.circular(1.5),
              topRight: const Radius.circular(1.5)),
          win);
    }
    final mw = s.u * 0.065;
    _minaretAt(s, hall - r * 2, s.ground - s.u * 0.72, mw);
    _minaretAt(s, hall + r * 2, s.ground - s.u * 0.72, mw);
    s.flat();
  }

  void _houses(_Stage s, {required bool lit}) {
    if (!lit) s.glow(Offset(s.x(0.3), s.ground), s.u * 1.0, 0.5);
    final rnd = math.Random(17);
    final body = Paint()..color = s.sil;
    final window = Paint()
      ..color = lit
          ? AppColors.lanternFlame.withValues(alpha: 0.85)
          : Color.lerp(s.sil, AppColors.skyStar, 0.25)!;
    var f = 0.0;
    while (f < 0.55) {
      final bw = s.u * (0.16 + rnd.nextDouble() * 0.1);
      final bh = s.u * (0.18 + rnd.nextDouble() * 0.22);
      final fw = bw / s.w;
      final cx = s.x(f + fw / 2);
      final r = Rect.fromLTWH(cx - bw / 2, s.ground - bh, bw + 0.5, bh);
      s.canvas.drawRect(r, body);
      // An arched door or window, sometimes a small dome.
      final dw = bw * 0.26;
      final dh = math.min(bh * 0.5, dw * 1.8);
      s.canvas.drawRRect(
          RRect.fromRectAndCorners(
              Rect.fromLTWH(cx - dw / 2, s.ground - dh, dw, dh),
              topLeft: Radius.circular(dw / 2),
              topRight: Radius.circular(dw / 2)),
          window);
      if (rnd.nextDouble() < 0.3) {
        s.canvas.drawArc(
            Rect.fromCircle(
                center: Offset(cx, s.ground - bh), radius: bw * 0.28),
            math.pi,
            math.pi,
            true,
            body);
      }
      f += fw;
    }
    s.flat();
  }

  void _water(_Stage s) {
    final cx = s.x(0.27);
    final bw = s.u * 0.48;
    final basinTop = s.ground - s.u * 0.12;
    final spout = Offset(cx, s.ground - s.u * 0.5);
    s.glow(spout, s.u * 0.8, 0.4);
    final water = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.skyStar.withValues(alpha: 0.8);
    for (final side in [-1.0, 1.0]) {
      for (final k in [0.55, 0.85]) {
        s.canvas.drawPath(
          Path()
            ..moveTo(spout.dx, spout.dy)
            ..quadraticBezierTo(
                spout.dx + side * bw * 0.3 * k,
                spout.dy - s.u * 0.12,
                spout.dx + side * bw * 0.42 * k,
                basinTop),
          water,
        );
      }
    }
    // Drops.
    final drop = Paint()..color = AppColors.skyStar.withValues(alpha: 0.7);
    for (final o in [
      const Offset(-0.32, -0.32),
      const Offset(0.3, -0.28),
      const Offset(-0.12, -0.62),
      const Offset(0.14, -0.66),
    ]) {
      s.canvas.drawCircle(
          Offset(cx + o.dx * s.u, s.ground + o.dy * s.u), 1.4, drop);
    }
    // Column and basin.
    final stone = Paint()..color = s.sil;
    s.canvas.drawRect(
        Rect.fromLTRB(cx - s.u * 0.03, spout.dy, cx + s.u * 0.03, basinTop),
        stone);
    s.canvas.drawCircle(spout, s.u * 0.045, stone);
    s.canvas.drawPath(
      Path()
        ..moveTo(cx - bw / 2, basinTop)
        ..lineTo(cx + bw / 2, basinTop)
        ..quadraticBezierTo(cx + bw * 0.45, s.ground, cx + bw * 0.3, s.ground)
        ..lineTo(cx - bw * 0.3, s.ground)
        ..quadraticBezierTo(cx - bw * 0.45, s.ground, cx - bw / 2, basinTop)
        ..close(),
      stone,
    );
    s.canvas.drawLine(
        Offset(cx - bw / 2, basinTop),
        Offset(cx + bw / 2, basinTop),
        Paint()
          ..color = AppColors.gold.color.withValues(alpha: 0.8)
          ..strokeWidth = 1.2);
    s.flat();
  }

  void _palms(_Stage s) {
    s.glow(Offset(s.x(0.3), s.ground), s.u * 1.0, 0.55);
    _palm(s, Offset(s.x(0.18), s.ground), s.u * 0.62, lean: 0.12, fruit: true);
    _palm(s, Offset(s.x(0.38), s.ground), s.u * 0.42, lean: -0.1, fruit: false);
    s.dunes();
  }

  /// A date palm rooted at [foot], [height] tall, its crown leaning by
  /// [lean] of its height towards the start side.
  void _palm(_Stage s, Offset foot, double height,
      {required double lean, required bool fruit}) {
    final crown = foot + Offset(-s.e * lean * height, -height);
    final trunk = Paint()
      ..color = s.sil
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.5, height * 0.06)
      ..strokeCap = StrokeCap.round;
    s.canvas.drawPath(
      Path()
        ..moveTo(foot.dx, foot.dy)
        ..quadraticBezierTo(
            foot.dx, foot.dy - height * 0.5, crown.dx, crown.dy),
      trunk,
    );
    final frond = Paint()..color = s.sil;
    final len = height * 0.5;
    for (var i = 0; i < 7; i++) {
      final a = -math.pi * (0.08 + i * 0.14);
      final tip = crown + Offset(math.cos(a), math.sin(a) * 0.55 + 0.45) * len;
      final mid = crown + Offset(math.cos(a), math.sin(a)) * len * 0.55;
      final n = Offset(-math.sin(a), math.cos(a)) * len * 0.09;
      s.canvas.drawPath(
        Path()
          ..moveTo(crown.dx, crown.dy)
          ..quadraticBezierTo(mid.dx + n.dx, mid.dy + n.dy, tip.dx, tip.dy)
          ..quadraticBezierTo(mid.dx - n.dx, mid.dy - n.dy, crown.dx, crown.dy)
          ..close(),
        frond,
      );
    }
    if (fruit) {
      final date = Paint()..color = AppColors.lanternGlass;
      final rnd = math.Random(4);
      for (var i = 0; i < 7; i++) {
        s.canvas.drawCircle(
            crown +
                Offset((rnd.nextDouble() - 0.5) * height * 0.14,
                    height * (0.05 + rnd.nextDouble() * 0.1)),
            math.max(1.4, height * 0.022),
            date);
      }
    }
  }

  void _flight(_Stage s) {
    s.glow(Offset(s.x(0.2), s.h * 0.3), s.u * 0.9, 0.35);
    // A far city on the horizon.
    final rnd = math.Random(2);
    final city = Paint()..color = s.far;
    for (var f = 0.0; f < 0.62;) {
      final bw = s.u * (0.05 + rnd.nextDouble() * 0.06);
      final bh = s.u * (0.04 + rnd.nextDouble() * 0.12);
      final cx = s.x(f);
      s.canvas.drawRect(
          Rect.fromLTWH(cx - bw / 2, s.ground - bh, bw + 0.5, bh), city);
      if (rnd.nextDouble() < 0.2) {
        s.canvas.drawRect(
            Rect.fromLTWH(
                cx - 1.2, s.ground - bh - s.u * 0.12, 2.4, s.u * 0.12),
            city);
      }
      f += bw / s.w;
    }
    // The route: a dashed arc rising towards the end edge.
    final from = Offset(s.x(0.62), s.ground - s.u * 0.05);
    final to = Offset(s.x(0.16), s.h * 0.24);
    final ctrl = Offset(s.x(0.48), s.h * 0.05);
    final dash = Paint()
      ..color = AppColors.skyStar.withValues(alpha: 0.55)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    Offset q(double t) =>
        from * ((1 - t) * (1 - t)) + ctrl * (2 * (1 - t) * t) + to * (t * t);
    for (var i = 0; i < 14; i += 2) {
      s.canvas.drawLine(q(i / 15), q((i + 1) / 15), dash);
    }
    // The plane, along the route's last tangent.
    final dir = to - q(0.93);
    final angle = math.atan2(dir.dy, dir.dx);
    final l = s.u * 0.16;
    s.canvas
      ..save()
      ..translate(to.dx, to.dy)
      ..rotate(angle);
    s.canvas.drawPath(
      Path()
        ..moveTo(l * 0.55, 0)
        ..quadraticBezierTo(l * 0.45, -l * 0.06, l * 0.3, -l * 0.06)
        ..lineTo(l * 0.05, -l * 0.06)
        ..lineTo(-l * 0.15, -l * 0.5)
        ..lineTo(-l * 0.28, -l * 0.5)
        ..lineTo(-l * 0.14, -l * 0.06)
        ..lineTo(-l * 0.38, -l * 0.06)
        ..lineTo(-l * 0.48, -l * 0.22)
        ..lineTo(-l * 0.56, -l * 0.22)
        ..lineTo(-l * 0.5, 0)
        ..lineTo(-l * 0.56, l * 0.22)
        ..lineTo(-l * 0.48, l * 0.22)
        ..lineTo(-l * 0.38, l * 0.06)
        ..lineTo(-l * 0.14, l * 0.06)
        ..lineTo(-l * 0.28, l * 0.5)
        ..lineTo(-l * 0.15, l * 0.5)
        ..lineTo(l * 0.05, l * 0.06)
        ..lineTo(l * 0.3, l * 0.06)
        ..quadraticBezierTo(l * 0.45, l * 0.06, l * 0.55, 0)
        ..close(),
      Paint()..color = AppColors.skyStar,
    );
    s.canvas.restore();
    s.flat();
  }

  void _road(_Stage s) {
    final horizon = s.ground - s.u * 0.32;
    final vp = Offset(s.x(0.26), horizon);
    s.glow(vp, s.u * 0.9, 0.6);
    s.canvas
        .drawRect(Rect.fromLTRB(0, horizon, s.w, s.h), Paint()..color = s.far);
    final half = s.u * 0.36;
    s.canvas.drawPath(
      Path()
        ..moveTo(vp.dx - 1.5, vp.dy)
        ..lineTo(vp.dx + 1.5, vp.dy)
        ..lineTo(vp.dx + half, s.h)
        ..lineTo(vp.dx - half, s.h)
        ..close(),
      Paint()..color = s.sil,
    );
    // Centre dashes, longer as they come nearer.
    final dash = Paint()
      ..color = AppColors.gold.color.withValues(alpha: 0.85)
      ..strokeCap = StrokeCap.round;
    for (final (t0, t1) in [(0.15, 0.22), (0.35, 0.48), (0.65, 0.88)]) {
      dash.strokeWidth = 0.8 + t1 * 1.6;
      s.canvas.drawLine(Offset(vp.dx, vp.dy + (s.h - vp.dy) * t0),
          Offset(vp.dx, vp.dy + (s.h - vp.dy) * t1), dash);
    }
    _palm(s, Offset(vp.dx - s.e * s.u * 0.42, horizon + s.u * 0.12), s.u * 0.4,
        lean: 0.1, fruit: false);
    _palm(s, Offset(vp.dx + s.e * s.u * 0.2, horizon + 2), s.u * 0.22,
        lean: -0.1, fruit: false);
  }

  void _rain(_Stage s) {
    final rain = Paint()
      ..color = AppColors.skyStar.withValues(alpha: 0.5)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    final rnd = math.Random(8);
    final cloudY = s.h * 0.28;
    for (var i = 0; i < 16; i++) {
      final f = 0.04 + rnd.nextDouble() * 0.48;
      final y = cloudY +
          s.u * 0.12 +
          rnd.nextDouble() * (s.ground - cloudY - s.u * 0.2);
      final p = Offset(s.x(f), y);
      s.canvas.drawLine(p, p + Offset(-s.e * 3, s.u * 0.08), rain);
    }
    _cloud(s, Offset(s.x(0.18), cloudY), s.u * 0.16,
        Color.lerp(s.tone, AppColors.skyStar, 0.55)!);
    _cloud(s, Offset(s.x(0.38), cloudY + s.u * 0.08), s.u * 0.12,
        Color.lerp(s.tone, AppColors.skyStar, 0.3)!);
    s.dunes();
  }

  /// A cloud of puffs around [c], [r] its largest puff.
  void _cloud(_Stage s, Offset c, double r, Color color) {
    final p = Paint()..color = color;
    s.canvas
      ..drawCircle(c, r, p)
      ..drawCircle(c + Offset(-r * 1.0, r * 0.35), r * 0.7, p)
      ..drawCircle(c + Offset(r * 1.05, r * 0.3), r * 0.75, p)
      ..drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(c.dx - r * 1.6, c.dy + r * 0.1, c.dx + r * 1.75,
                  c.dy + r * 1.05),
              Radius.circular(r * 0.5)),
          p);
  }

  void _rays(_Stage s) {
    final c = Offset(s.x(0.26), s.h * 0.34);
    s.glow(c, s.u * 1.0, 0.8);
    final ray = Paint()..color = AppColors.lanternFlame.withValues(alpha: 0.35);
    for (var i = 0; i < 7; i++) {
      final a = math.pi * (0.12 + i * 0.13);
      const w = 0.05;
      final far = s.u * 1.2;
      s.canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + math.cos(a - w) * far, c.dy + math.sin(a - w) * far)
          ..lineTo(c.dx + math.cos(a + w) * far, c.dy + math.sin(a + w) * far)
          ..close(),
        ray,
      );
    }
    s.sun(c + Offset(0, -s.u * 0.04), s.u * 0.12);
    _cloud(s, c + Offset(0, s.u * 0.02), s.u * 0.13,
        Color.lerp(s.tone, AppColors.skyStar, 0.5)!);
    s.dunes();
  }

  void _paths(_Stage s) {
    final horizon = s.ground - s.u * 0.32;
    s.glow(Offset(s.x(0.28), horizon), s.u * 0.9, 0.55);
    s.canvas
        .drawRect(Rect.fromLTRB(0, horizon, s.w, s.h), Paint()..color = s.sil);
    final light = Paint()..color = Color.lerp(s.far, AppColors.skyStar, 0.6)!;
    final fork = Offset(s.x(0.3), s.ground - s.u * 0.04);
    final base = s.u * 0.3;
    // Trunk of the path from the bottom edge to the fork.
    s.canvas.drawPath(
      Path()
        ..moveTo(fork.dx - base * 0.18, fork.dy)
        ..lineTo(fork.dx + base * 0.18, fork.dy)
        ..lineTo(fork.dx + base * 0.5, s.h)
        ..lineTo(fork.dx - base * 0.5, s.h)
        ..close(),
      light,
    );
    for (final f in [0.12, 0.46]) {
      final vp = Offset(s.x(f), horizon);
      s.canvas.drawPath(
        Path()
          ..moveTo(fork.dx - base * 0.18, fork.dy)
          ..quadraticBezierTo(
              (fork.dx + vp.dx) / 2, fork.dy - s.u * 0.02, vp.dx - 1, vp.dy)
          ..lineTo(vp.dx + 1, vp.dy)
          ..quadraticBezierTo((fork.dx + vp.dx) / 2, fork.dy - s.u * 0.1,
              fork.dx + base * 0.18, fork.dy)
          ..close(),
        light,
      );
    }
    // A signpost at the fork.
    final post = Offset(fork.dx + s.e * s.u * 0.14, fork.dy);
    final wood = Paint()..color = AppColors.gold.color;
    s.canvas.drawRect(
        Rect.fromLTWH(post.dx - 1, post.dy - s.u * 0.3, 2, s.u * 0.3), wood);
    for (final (dy, d) in [(0.28, 1.0), (0.2, -1.0)]) {
      final y = post.dy - s.u * dy;
      final len = s.u * 0.12 * d;
      s.canvas.drawPath(
        Path()
          ..addPolygon([
            Offset(post.dx, y),
            Offset(post.dx + len, y),
            Offset(post.dx + len * 1.25, y + s.u * 0.025),
            Offset(post.dx + len, y + s.u * 0.05),
            Offset(post.dx, y + s.u * 0.05),
          ], true),
        wood,
      );
    }
  }

  void _sprout(_Stage s) {
    final foot = Offset(s.x(0.27), s.ground);
    s.glow(foot - Offset(0, s.u * 0.25), s.u * 0.9, 0.6);
    s.sun(Offset(s.x(0.1), s.h * 0.28), s.u * 0.08);
    final stem = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, s.u * 0.025)
      ..strokeCap = StrokeCap.round
      ..color = AppColors.skyStar;
    final top = foot - Offset(0, s.u * 0.42);
    s.canvas.drawPath(
      Path()
        ..moveTo(foot.dx, foot.dy)
        ..quadraticBezierTo(
            foot.dx + s.e * s.u * 0.06, foot.dy - s.u * 0.2, top.dx, top.dy),
      stem,
    );
    final leaf = Paint()
      ..color = Color.lerp(AppColors.tileGreen.color, AppColors.skyStar, 0.45)!;
    void leafAt(Offset base, double angle, double len) {
      final tip = base + Offset(math.cos(angle), math.sin(angle)) * len;
      final mid = Offset.lerp(base, tip, 0.5)!;
      final n = Offset(-math.sin(angle), math.cos(angle)) * len * 0.32;
      s.canvas.drawPath(
        Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(mid.dx + n.dx, mid.dy + n.dy, tip.dx, tip.dy)
          ..quadraticBezierTo(mid.dx - n.dx, mid.dy - n.dy, base.dx, base.dy)
          ..close(),
        leaf,
      );
    }

    leafAt(top, -math.pi / 2 - 0.5, s.u * 0.2);
    leafAt(top, -math.pi / 2 + 0.5, s.u * 0.2);
    leafAt(foot - Offset(0, s.u * 0.18), s.e > 0 ? -0.4 : math.pi + 0.4,
        s.u * 0.16);
    // The mound it grows from.
    s.canvas.drawOval(
        Rect.fromCenter(center: foot, width: s.u * 0.45, height: s.u * 0.12),
        Paint()..color = s.sil);
    s.flat();
  }

  void _star(_Stage s) {
    s.stars(14, seed: 21);
    final c = Offset(s.x(0.24), s.h * 0.42);
    final r = s.u * 0.17;
    s.glow(c, r * 4, 0.55);
    final gold = AppColors.gold.color;
    s.canvas
      ..drawPath(
          rubElHizb(c, r),
          Paint()
            ..shader = ui.Gradient.radial(c, r, [AppColors.lanternFlame, gold]))
      ..drawPath(
          rubElHizb(c, r * 0.62),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9
            ..color = Color.lerp(gold, TileScenePainter.deep, 0.45)!)
      ..drawCircle(c, r * 0.18,
          Paint()..color = Color.lerp(gold, TileScenePainter.deep, 0.45)!);
    s.dunes();
  }

  @override
  bool shouldRepaint(TileScenePainter old) =>
      old.scene != scene ||
      old.tone != tone ||
      old.textDirection != textDirection;
}

/// The canvas and the scene's measures, shared by the motifs.
class _Stage {
  _Stage({
    required this.canvas,
    required Size size,
    required this.rtl,
    required this.tone,
    required bool night,
  })  : w = size.width,
        h = size.height,
        // Narrow tiles (three to a row) keep their subject smaller, so it
        // stays clear of the title.
        u = math.min(size.width, size.height) * (size.width < 150 ? 0.82 : 1),
        ground = size.height - math.min(size.height * 0.14, 12.0),
        sil = Color.lerp(tone, TileScenePainter.deep, night ? 0.88 : 0.8)!,
        far = Color.lerp(tone, TileScenePainter.deep, night ? 0.68 : 0.52)!;

  final Canvas canvas;
  final double w;
  final double h;

  /// The scene's unit: the card's shorter side.
  final double u;
  final bool rtl;
  final Color tone;

  /// Where the land starts.
  final double ground;

  /// The near silhouette, and the hazier far one.
  final Color sil;
  final Color far;

  /// +1 when the end edge is on the right.
  double get e => rtl ? -1 : 1;

  /// [f] of the width in from the end edge.
  double x(double f) => (rtl ? f : 1 - f) * w;

  /// A soft pool of light round [c].
  void glow(Offset c, double radius, double strength,
      {Color color = AppColors.lanternFlame}) {
    final tint = Color.lerp(tone, color, 0.6)!;
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(c, radius, [
          tint.withValues(alpha: strength),
          tint.withValues(alpha: 0),
        ]),
    );
  }

  void sun(Offset c, double r) => canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
              c, r, const [AppColors.lanternFlame, AppColors.lanternGlass]),
      );

  void moon(Offset c, double r) => canvas.drawPath(
        crescent(c, r, rtl ? math.pi * 0.15 : math.pi * 0.85),
        Paint()..color = AppColors.skyStar,
      );

  void stars(int n, {required int seed}) {
    final rnd = math.Random(seed);
    final p = Paint();
    for (var i = 0; i < n; i++) {
      p.color =
          AppColors.skyStar.withValues(alpha: 0.35 + rnd.nextDouble() * 0.55);
      canvas.drawCircle(
          Offset(x(rnd.nextDouble() * 0.6), rnd.nextDouble() * h * 0.6),
          0.6 + rnd.nextDouble() * 0.7,
          p);
    }
  }

  /// Two rows of low dunes, far then near, down to the bottom edge.
  void dunes() {
    for (final (color, lift, phase) in [(far, 0.1, 0.3), (sil, 0.0, 1.4)]) {
      final path = Path()..moveTo(0, h);
      for (var px = 0.0; px <= w; px += 4) {
        final y = ground -
            u * lift -
            u * 0.05 * (1 + math.sin(px / w * math.pi * 2.2 + phase));
        path.lineTo(px, y);
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }
  }

  /// Level ground.
  void flat() =>
      canvas.drawRect(Rect.fromLTRB(0, ground, w, h), Paint()..color = sil);
}
