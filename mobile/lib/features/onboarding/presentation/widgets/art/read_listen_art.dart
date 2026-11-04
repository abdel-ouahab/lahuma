import 'dart:math' as math;

import '../../../../../core/design/design.dart';
import '../../../../../core/localization/tr.dart';
import '../../../../quran/mushaf/domain/mushaf_meta.dart';
import 'art_timeline.dart';

/// Page 2: read and listen. A Mushaf page with the opening of al-Fatiha
/// (the app's own Quran text), the ayah being recited lit in turn, and the
/// reciter playing in a bar below with a moving waveform.
class ReadListenArt extends OnboardingArtWidget {
  const ReadListenArt({super.key, required super.active});

  static const Size size = Size(300, 280);

  @override
  State<ReadListenArt> createState() => _ReadListenArtState();
}

class _ReadListenArtState extends OnboardingArtState<ReadListenArt> {
  @override
  Duration get length => const Duration(milliseconds: 900);

  /// One pass through the four ayahs.
  @override
  Duration get ambientLength => const Duration(milliseconds: 6400);

  static const int _ayahs = 4;

  late final Animation<double> _pageIn = segment(0, 600);
  late final Animation<double> _barIn = segment(250, 900);

  /// The ayah being recited. Before playing (and with Reduce Motion) the
  /// first one is lit. Changes four times a pass, so the page's text is
  /// laid out again only then, not every frame.
  int _current = 1;

  @override
  void initState() {
    super.initState();
    ambient.addListener(() {
      final next = (ambient.value * _ayahs).floor().clamp(0, _ayahs - 1) + 1;
      if (next != _current) setState(() => _current = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Column(
      children: [
        FadeTransition(
          opacity: _pageIn,
          child: SizedBox(
            width: 264,
            height: 196,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: c.resolve(AppColors.prayerFrame),
                shape: AppRadius.continuous(AppRadius.small,
                    side: BorderSide(color: c.gold, width: 1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: AppRadius.continuous(4,
                        side: BorderSide(
                            color: c.gold.withValues(alpha: 0.6), width: 0.6)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Column(
                      children: [
                        _SurahBand(gold: c.gold, ink: c.label),
                        const SizedBox(height: 6),
                        Expanded(child: _AyahLines(current: _current)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.ms),
        FadeTransition(
          opacity: _barIn,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.25), end: Offset.zero)
                .animate(_barIn),
            child: _NowPlaying(wave: ambient),
          ),
        ),
      ],
    );
  }
}

/// The surah's name in a gilded cartouche.
class _SurahBand extends StatelessWidget {
  const _SurahBand({required this.gold, required this.ink});

  final Color gold;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: gold.withValues(alpha: 0.12),
        shape: StadiumBorder(side: BorderSide(color: gold, width: 0.8)),
      ),
      child: Text(
        'سورة الفاتحة',
        textDirection: TextDirection.rtl,
        style: AppTypography.quran(size: 14, height: 1.2).copyWith(color: ink),
      ),
    );
  }
}

/// Al-Fatiha 1–4, each ayah closed by its verse-end rosette; [current] is
/// lit as it is recited.
class _AyahLines extends StatelessWidget {
  const _AyahLines({required this.current});

  final int current;

  static const _numerals = ['١', '٢', '٣', '٤'];

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final style =
        AppTypography.quran(size: 16.5, height: 1.95).copyWith(color: c.label);
    InlineSpan ayah(int n) => TextSpan(children: [
          TextSpan(
            text: MushafMeta.ayahText(1, n),
            style: style.copyWith(
              backgroundColor: n == current ? c.accentTint : null,
            ),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: CustomPaint(
                size: const Size.square(17),
                painter: _MarkerPainter(
                    gold: c.gold, fill: c.resolve(AppColors.prayerFrame)),
                child: SizedBox.square(
                  dimension: 17,
                  child: Center(
                    child: Text(
                      _numerals[n - 1],
                      style: AppTypography.quran(size: 9, height: 1)
                          .copyWith(color: c.label),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const TextSpan(text: ' '),
        ]);

    // One line per ayah, the short third and fourth sharing one, centred
    // as on the Fatiha's page in the Madani Mushaf.
    Widget line(List<int> ayahs) => FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(children: [for (final n in ayahs) ayah(n)]),
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        );
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          line([1]),
          line([2]),
          line([3, 4]),
        ],
      ),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  const _MarkerPainter({required this.gold, required this.fill});

  final Color gold;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final marker = ayahMarker(size.center(Offset.zero), size.shortestSide / 2);
    canvas
      ..drawPath(marker, Paint()..color = fill)
      ..drawPath(
        marker,
        Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
  }

  @override
  bool shouldRepaint(_MarkerPainter old) =>
      old.gold != gold || old.fill != fill;
}

/// The mini player: the reciter's monogram, name and surah, a waveform that
/// moves while playing, and the pause glyph.
class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.wave});

  final Animation<double> wave;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Container(
      width: 264,
      height: 56,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
      decoration: ShapeDecoration(
        color: c.secondaryGroupedBackground,
        shape: AppRadius.continuous(AppRadius.medium,
            side: BorderSide(color: c.separator, width: AppSpacing.hairline)),
        shadows: [
          BoxShadow(
              color: c.shadow(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: AppColors.accentGradient,
              shape: BoxShape.circle,
            ),
            child: Text(
              context.tr('ع', 'A'),
              style: AppTypography.headline.copyWith(color: AppColors.onAccent),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('أحمد العجمي', 'Ahmed Al-Ajmi'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.subheadline
                      .weight(FontWeight.w600)
                      .copyWith(color: c.label, height: 1.2),
                ),
                Text(
                  context.tr('سورة الفاتحة', 'Al-Fatiha'),
                  maxLines: 1,
                  style: AppTypography.caption1
                      .copyWith(color: c.secondaryLabel, height: 1.2),
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(58, 24),
            painter: _WavePainter(wave: wave, color: c.accent),
          ),
          const SizedBox(width: 10),
          Icon(CupertinoIcons.pause_fill, size: 20, color: c.label),
        ],
      ),
    );
  }
}

/// Eleven bars rising and falling at their own pace while [wave] runs;
/// still, a resting profile.
class _WavePainter extends CustomPainter {
  _WavePainter({required this.wave, required this.color})
      : super(repaint: wave);

  final Animation<double> wave;
  final Color color;

  static const int _bars = 11;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final step = size.width / _bars;
    final t = wave.value * 2 * math.pi * 6;
    final playing = wave is AnimationController &&
        (wave as AnimationController).isAnimating;
    for (var i = 0; i < _bars; i++) {
      final rest = 0.35 + 0.3 * math.sin(i * 1.7).abs();
      final level = playing
          ? 0.25 +
              0.75 *
                  (0.5 +
                          0.5 *
                              math.sin(t * (1 + (i % 3) * 0.35) + i * 1.3) *
                              math.cos(t * 0.5 + i))
                      .abs()
          : rest;
      final h = size.height * level.clamp(0.15, 1.0);
      final x = step * (i + 0.5);
      canvas.drawLine(Offset(x, (size.height - h) / 2),
          Offset(x, (size.height + h) / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.color != color;
}
