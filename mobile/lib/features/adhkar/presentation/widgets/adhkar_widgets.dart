import 'dart:math' as math;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/dhikr.dart';

extension AdhkarCategoryLabel on AdhkarCategory {
  String label(BuildContext context) => context.tr(title, titleEn);
}

extension AdhkarPeriodLabel on AdhkarPeriod {
  String title(BuildContext context) => switch (this) {
        AdhkarPeriod.morning => context.tr('أذكار الصباح', 'Morning adhkar'),
        AdhkarPeriod.evening => context.tr('أذكار المساء', 'Evening adhkar'),
      };
}

extension AdhkarGroupLabel on AdhkarGroup {
  String title(BuildContext context) => switch (this) {
        AdhkarGroup.day => context.tr('اليوم والليلة', 'Day and night'),
        AdhkarGroup.places =>
          context.tr('في البيت والمسجد', 'At home and in the mosque'),
        AdhkarGroup.travel => context.tr('السفر', 'Travel'),
        AdhkarGroup.duas => context.tr('أدعية', 'Duas'),
      };
}

/// Glyph for a category's `icon` name in the dataset.
IconData adhkarIcon(String name) => switch (name) {
      'sunrise' => CupertinoIcons.sunrise_fill,
      'moon' => CupertinoIcons.moon_fill,
      'prayer' => CupertinoIcons.hand_raised_fill,
      'bed' => CupertinoIcons.bed_double_fill,
      'sun' => CupertinoIcons.sun_max_fill,
      'house' => CupertinoIcons.house_fill,
      'mosque' => Icons.mosque_rounded,
      'drop' => CupertinoIcons.drop_fill,
      'food' => Icons.restaurant_rounded,
      'airplane' => CupertinoIcons.airplane,
      'car' => CupertinoIcons.car_fill,
      'heart' => CupertinoIcons.heart_fill,
      'compass' => Icons.alt_route_rounded,
      'cloud' => CupertinoIcons.cloud_rain_fill,
      'bandage' => CupertinoIcons.bandage_fill,
      'book' => CupertinoIcons.book_fill,
      'sparkle' => CupertinoIcons.sparkles,
      _ => CupertinoIcons.moon_stars_fill,
    };

/// Painted scene behind a category's tile, by its `icon` name.
TileScene adhkarScene(String name) => switch (name) {
      'sunrise' => TileScene.sunrise,
      'moon' => TileScene.dusk,
      'prayer' => TileScene.mihrab,
      'bed' => TileScene.night,
      'sun' => TileScene.window,
      'house' => TileScene.houses,
      'mosque' => TileScene.mosque,
      'drop' => TileScene.water,
      'food' => TileScene.palms,
      'airplane' => TileScene.flight,
      'car' => TileScene.road,
      'heart' => TileScene.rays,
      'compass' => TileScene.paths,
      'cloud' => TileScene.rain,
      'bandage' => TileScene.sprout,
      'book' => TileScene.openMushaf,
      'sparkle' => TileScene.star,
      _ => TileScene.star,
    };

/// Tile colour token for a category's `tone` name in the dataset.
Color adhkarTone(String name) => switch (name) {
      'yellow' => AppColors.tileYellow,
      'indigo' => AppColors.tileIndigo,
      'teal' => AppColors.tileTeal,
      'purple' => AppColors.tilePurple,
      'orange' => AppColors.tileOrange,
      'green' => AppColors.tileGreen,
      'blue' => AppColors.tileBlue,
      'pink' => AppColors.tilePink,
      'red' => AppColors.tileRed,
      _ => AppColors.tileTeal,
    };

/// "مرة واحدة" / "3 مرات" / "Once" / "3 times".
String repetitionLabel(BuildContext context, int count) {
  if (context.isArabic) {
    if (count == 1) return 'مرة واحدة';
    if (count == 2) return 'مرتان';
    return '${ltr('$count')} ${count <= 10 ? 'مرات' : 'مرة'}';
  }
  return count == 1 ? 'Once' : '$count times';
}

/// "٥ أذكار" style item count under a category tile.
String adhkarCountLabel(BuildContext context, int n) {
  if (context.isArabic) {
    if (n == 1) return 'ذكر واحد';
    if (n == 2) return 'ذكران';
    return '${ltr('$n')} ${n <= 10 ? 'أذكار' : 'ذكرًا'}';
  }
  return n == 1 ? '1 item' : '$n items';
}

/// Dhikr text: Arabic, right-to-left even in the English UI, in the app's
/// Quran face (Scheherazade New), which draws full tashkeel clearly.
class DhikrText extends StatelessWidget {
  const DhikrText(this.text,
      {super.key, this.size = 22, this.textAlign = TextAlign.start});

  final String text;
  final double size;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final base =
        AppTypography.quran(size: size, height: 1.95).copyWith(color: c.label);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text.rich(
        TextSpan(children: dhikrSpans(text, base, c.tertiaryLabel)),
        textAlign: textAlign,
        style: base,
      ),
    );
  }
}

/// [text] as spans: the book's own brackets — `(( ))` round the Prophet's
/// words, `( )` round counts, `[ ]` round the evening wording — are kept but
/// set back in [muted], and what `[ ]` encloses is smaller, so the dhikr
/// itself leads. Not one letter is changed.
List<TextSpan> dhikrSpans(String text, TextStyle base, Color muted) {
  final spans = <TextSpan>[];
  final note =
      base.copyWith(color: muted, fontSize: (base.fontSize ?? 22) * 0.78);
  final mark = base.copyWith(color: muted);
  final buffer = StringBuffer();
  var inNote = 0;
  void flush() {
    if (buffer.isEmpty) return;
    spans.add(
        TextSpan(text: buffer.toString(), style: inNote > 0 ? note : null));
    buffer.clear();
  }

  for (final ch in text.characters) {
    if (ch == '(' || ch == ')' || ch == '[' || ch == ']') {
      if (ch == '[') {
        flush();
        inNote++;
      }
      flush();
      spans.add(TextSpan(text: ch, style: inNote > 0 ? note : mark));
      if (ch == ']' && inNote > 0) inNote--;
    } else {
      buffer.write(ch);
    }
  }
  flush();
  return spans;
}

/// What a dhikr looks like when copied or shared: the text, then its
/// virtue and reference as the book gives them.
String dhikrShareText(Dhikr dhikr) => [
      dhikr.text,
      if (dhikr.virtue != null) dhikr.virtue!,
      if (dhikr.reference != null) '[${dhikr.reference}]',
    ].join('\n\n');

/// Where the text comes from. Shown under every list.
class AdhkarSourceNote extends StatelessWidget {
  const AdhkarSourceNote({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Text(
      context.tr(
        'المصدر: حصن المسلم من أذكار الكتاب والسنة، لسعيد بن علي بن وهف القحطاني. '
            'النصوص من موقع hisnmuslim.com، والتخريج والفضل من حواشي الكتاب. '
            'آيات الأدعية القرآنية من نص المصحف في التطبيق.',
        'Source: Hisn al-Muslim by Sa\'id ibn Wahf al-Qahtani. Texts from '
            'hisnmuslim.com; references and virtues from the book\'s footnotes. '
            'Quranic duas are read from the app\'s Mushaf text.',
      ),
      textAlign: TextAlign.center,
      style: AppTypography.caption1.copyWith(color: c.tertiaryLabel),
    );
  }
}

/// Shown if the bundled adhkar can't be read (a broken build).
class AdhkarErrorView extends StatelessWidget {
  const AdhkarErrorView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppEmptyState(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: context.tr('تعذّرت قراءة الأذكار', 'Could not read the adhkar'),
        message: context.tr('أعد المحاولة. إن تكرّر ذلك فأعد تثبيت التطبيق.',
            'Try again. If it keeps happening, reinstall the app.'),
        action: AppButton.tinted(
          label: context.tr('إعادة المحاولة', 'Try again'),
          icon: CupertinoIcons.arrow_clockwise,
          onPressed: onRetry,
        ),
      );
}

/// Where a dhikr stands, for its counter.
enum DhikrState { ahead, current, done }

/// The counter: a Mushaf verse-end rosette holding the repetitions left.
/// Green and gilded on the dhikr being said now, outlined on those ahead,
/// gold with a check once said. A gold arc round it fills as it is counted
/// (only for adhkar said more than once); each count gives it a small pulse.
class DhikrRosette extends StatelessWidget {
  const DhikrRosette({
    super.key,
    required this.done,
    required this.total,
    required this.state,
    this.diameter = 54,
  });

  final int done;
  final int total;
  final DhikrState state;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final remaining = math.max(0, total - done);
    final fast = AppMotion.of(context, AppMotion.fast);

    final Widget centre = switch (state) {
      DhikrState.done => Icon(CupertinoIcons.checkmark_alt,
          key: const ValueKey('done'), size: diameter * 0.36, color: c.gold),
      _ => LtrText(
          '$remaining',
          key: ValueKey(remaining),
          style: AppTypography.tabular(remaining >= 100
                  ? AppTypography.footnote
                  : AppTypography.headline)
              .weight(FontWeight.w700)
              .copyWith(
                  color: state == DhikrState.current
                      ? AppColors.onAccent
                      : c.secondaryLabel),
        ),
    };

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: diameter,
        child: TweenAnimationBuilder<double>(
          // Restarts on every count: a short swell back to rest.
          key: ValueKey(done),
          tween: Tween(begin: done == 0 ? 1 : 1.12, end: 1),
          duration: AppMotion.of(context, AppMotion.standard),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: total == 0 ? 0 : done / total),
            duration: fast,
            curve: AppMotion.curve,
            builder: (context, value, child) => CustomPaint(
              painter: _RosettePainter(
                state: state,
                progress: total > 1 ? value : 0,
                gold: c.gold,
                outline: c.separator,
                fill: c.secondaryGroupedBackground,
              ),
              child: child,
            ),
            child: Center(
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.2,
                child: AnimatedSwitcher(duration: fast, child: centre),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RosettePainter extends CustomPainter {
  _RosettePainter({
    required this.state,
    required this.progress,
    required this.gold,
    required this.outline,
    required this.fill,
  });

  final DhikrState state;
  final double progress;
  final Color gold;
  final Color outline;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final arcRadius = size.shortestSide / 2 - 1.5;
    final rosette = ayahMarker(centre, arcRadius - 5);

    switch (state) {
      case DhikrState.current:
        canvas.drawPath(
          rosette,
          Paint()
            ..shader = const LinearGradient(
              colors: AppColors.heroGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(Rect.fromCircle(center: centre, radius: arcRadius)),
        );
        canvas.drawPath(
            rosette,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = gold);
      case DhikrState.ahead:
        canvas.drawPath(rosette, Paint()..color = fill);
        canvas.drawPath(
            rosette,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = outline);
      case DhikrState.done:
        canvas.drawPath(rosette, Paint()..color = gold.withValues(alpha: 0.14));
        canvas.drawPath(
            rosette,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = gold);
    }

    if (progress > 0 && state != DhikrState.done) {
      final rect = Rect.fromCircle(center: centre, radius: arcRadius);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawArc(rect, 0, 2 * math.pi, false,
            paint..color = gold.withValues(alpha: 0.22))
        ..drawArc(rect, -math.pi / 2, 2 * math.pi * progress.clamp(0, 1), false,
            paint..color = gold);
    }
  }

  @override
  bool shouldRepaint(_RosettePainter old) =>
      old.state != state ||
      old.progress != progress ||
      old.gold != gold ||
      old.outline != outline ||
      old.fill != fill;
}

/// Light tap per repetition, a firmer one when the dhikr is complete.
void dhikrHaptic({required bool completed}) =>
    completed ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
