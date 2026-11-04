import 'dart:math' as math;

import '../../../../../core/design/design.dart';
import '../../../../../core/localization/tr.dart';
import '../../../../prayer_times/presentation/widgets/prayer_painters.dart';
import 'art_timeline.dart';

/// Page 5: Fajr Call. The Home card's sky warming from night to dawn as the
/// stars go out, the phone sending its rings out, and the list below waking
/// one by one: Mum is called and wakes, then Dad.
class FajrCallArt extends OnboardingArtWidget {
  const FajrCallArt({super.key, required super.active});

  static const Size size = Size(300, 280);

  @override
  State<FajrCallArt> createState() => _FajrCallArtState();
}

class _FajrCallArtState extends OnboardingArtState<FajrCallArt> {
  @override
  Duration get length => const Duration(milliseconds: 4000);

  /// One ring going out.
  @override
  Duration get ambientLength => const Duration(milliseconds: 1600);

  late final Animation<double> _dawn = segment(0, 3600, Curves.easeInOut);

  @override
  void initState() {
    super.initState();
    // Everyone is awake: the phone stops ringing, so stop drawing rings.
    timeline.addStatusListener((status) {
      if (status == AnimationStatus.completed) ambient.stop();
    });
  }

  /// When each one is being called, and when they wake (ms).
  static const _calls = [(400, 1700), (1900, 3200)];

  _Wake _stateOf(int i, double ms) {
    final (from, woke) = _calls[i];
    if (ms >= woke) return _Wake.awake;
    if (ms >= from) return _Wake.calling;
    return _Wake.waiting;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return AnimatedBuilder(
      animation: timeline,
      builder: (context, _) {
        final ms = timeline.value * length.inMilliseconds;
        final states = [_stateOf(0, ms), _stateOf(1, ms)];
        final ringing = states.contains(_Wake.calling);
        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.large),
              child: SizedBox(
                width: 300,
                height: 148,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: PrayerSkyPainter(
                        sky: _sky(_dawn.value),
                        night: false,
                        textDirection: Directionality.of(context),
                      ),
                    ),
                    CustomPaint(painter: _StarsPainter(1 - _dawn.value)),
                    Center(
                      child: _Phone(rings: ambient, ringing: ringing),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.ms),
            Container(
              width: 300,
              decoration: ShapeDecoration(
                color: c.secondaryGroupedBackground,
                shape: AppRadius.continuous(AppRadius.medium,
                    side: BorderSide(
                        color: c.separator, width: AppSpacing.hairline)),
              ),
              child: Column(
                children: [
                  _Contact(
                    name: context.tr('أمي', 'Mum'),
                    awake: context.tr('استيقظت', 'Awake'),
                    color: AppColors.tilePink,
                    state: states[0],
                  ),
                  Container(
                    height: AppSpacing.hairline,
                    margin: const EdgeInsetsDirectional.only(start: 54),
                    color: c.separator,
                  ),
                  _Contact(
                    name: context.tr('أبي', 'Dad'),
                    awake: context.tr('استيقظ', 'Awake'),
                    color: AppColors.tileBlue,
                    state: states[1],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// The night sky turning into the dawn one, stop by stop.
  static List<Color> _sky(double t) => [
        for (var i = 0; i < 3; i++)
          Color.lerp(AppColors.skyNight[i], AppColors.skyDawn[i], t)!,
      ];
}

/// The night's stars, at [opacity].
class _StarsPainter extends CustomPainter {
  const _StarsPainter(this.opacity);

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final rnd = math.Random(7);
    final star = Paint();
    for (var i = 0; i < 18; i++) {
      star.color = AppColors.skyStar
          .withValues(alpha: (0.3 + rnd.nextDouble() * 0.6) * opacity);
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width,
            rnd.nextDouble() * size.height * 0.5),
        0.6 + rnd.nextDouble() * 0.8,
        star,
      );
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => old.opacity != opacity;
}

/// The phone, with rings going out from it while a call is ringing.
class _Phone extends StatelessWidget {
  const _Phone({required this.rings, required this.ringing});

  final Animation<double> rings;
  final bool ringing;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 120,
      child: CustomPaint(
        painter: _RingsPainter(rings: rings, visible: ringing),
        child: Center(
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.onAccent.withValues(alpha: 0.18),
              border: Border.all(
                  color: AppColors.onAccent.withValues(alpha: 0.5), width: 1),
            ),
            child: const Icon(CupertinoIcons.phone_fill,
                size: 24, color: AppColors.onAccent),
          ),
        ),
      ),
    );
  }
}

/// Two rings widening and fading from the phone, half a ring apart.
class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.rings, required this.visible})
      : super(repaint: rings);

  final Animation<double> rings;
  final bool visible;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final center = size.center(Offset.zero);
    for (final lag in const [0.0, 0.5]) {
      final t = (rings.value + lag) % 1;
      canvas.drawCircle(
        center,
        26 + 32 * t,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = AppColors.onAccent.withValues(alpha: 0.55 * (1 - t)),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.visible != visible;
}

enum _Wake { waiting, calling, awake }

class _Contact extends StatelessWidget {
  const _Contact({
    required this.name,
    required this.awake,
    required this.color,
    required this.state,
  });

  final String name;

  /// "Awake", agreeing with [name] in Arabic.
  final String awake;
  final Color color;
  final _Wake state;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final (String label, Color tone, IconData? icon) = switch (state) {
      _Wake.waiting => (
          context.tr('في الانتظار', 'Waiting'),
          c.tertiaryLabel,
          null,
        ),
      _Wake.calling => (
          context.tr('يتصل…', 'Calling…'),
          c.accent,
          CupertinoIcons.phone_fill,
        ),
      _Wake.awake => (awake, c.success, CupertinoIcons.checkmark_circle_fill),
    };
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
        child: Row(
          children: [
            AppIconTile(icon: CupertinoIcons.person_fill, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: AppTypography.subheadline
                    .weight(FontWeight.w600)
                    .copyWith(color: c.label),
              ),
            ),
            AnimatedSwitcher(
              duration: AppMotion.of(context, AppMotion.standard),
              // The old status fades out before the new one fades in.
              switchInCurve: const Interval(0.5, 1, curve: Curves.easeOut),
              switchOutCurve: const Interval(0.5, 1, curve: Curves.easeIn),
              layoutBuilder: (current, previous) => Stack(
                alignment: AlignmentDirectional.centerEnd,
                children: [...previous, if (current != null) current],
              ),
              child: Row(
                key: ValueKey(state),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: AppTypography.footnote
                          .weight(FontWeight.w600)
                          .copyWith(color: tone)),
                  if (icon != null) ...[
                    const SizedBox(width: 4),
                    Icon(icon, size: 15, color: tone),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
