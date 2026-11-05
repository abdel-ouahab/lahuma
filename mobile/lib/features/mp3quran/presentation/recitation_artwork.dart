import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/widgets/app_ornaments.dart';

/// The recitation artwork: the app's mark, the gold إحسان wordmark inside
/// the shamsa (the medallion that opens an illuminated Mushaf, as on the
/// splash), on a deep green tile.
///
/// While [animate] is on (the recitation is playing) the shamsa turns once
/// every two minutes and a gold glow breathes behind it; paused, it holds
/// where it is. Reduce Motion keeps it still. Below [_shamsaMinSize] only
/// the wordmark is drawn, as on the app icon: 72 rays are noise at 40 px.
class RecitationArtwork extends StatefulWidget {
  const RecitationArtwork({
    super.key,
    required this.size,
    this.radius = 0,
    this.shadow = false,
    this.animate = false,
    this.scale = 1,
  });

  final double size;
  final double radius;
  final bool shadow;
  final bool animate;

  /// The mark's size within the tile: 1 fills a card; a full-screen tile
  /// takes a smaller one, so the medallion doesn't crowd the screen.
  final double scale;

  static const String wordmarkAsset = 'assets/images/wordmark.png';

  /// Height over width of [wordmarkAsset].
  static const double wordmarkAspect = 407 / 640;

  static const double _shamsaMinSize = 96;

  /// One turn of the shamsa; the glow breathes [_breaths] times per turn.
  static const Duration turn = Duration(minutes: 2);
  static const int _breaths = 20;

  @override
  State<RecitationArtwork> createState() => _RecitationArtworkState();
}

class _RecitationArtworkState extends State<RecitationArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: RecitationArtwork.turn);

  bool get _running =>
      widget.animate &&
      widget.size >= RecitationArtwork._shamsaMinSize &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RecitationArtwork old) {
    super.didUpdateWidget(old);
    _sync();
  }

  /// Runs or holds the clock; a pause keeps the shamsa where it stopped.
  void _sync() {
    if (_running) {
      if (!_clock.isAnimating) _clock.repeat();
    } else if (_clock.isAnimating) {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final full = size >= RecitationArtwork._shamsaMinSize;
    // The shamsa's rays reach to 1.44 radii; leave a margin round them.
    final shamsa = size / 2 / ShamsaPainter.reach * 0.84 * widget.scale;
    final wordmarkWidth = full ? shamsa * 1.28 : size * 0.68;

    final wordmark = Image.asset(
      RecitationArtwork.wordmarkAsset,
      width: wordmarkWidth,
      height: wordmarkWidth * RecitationArtwork.wordmarkAspect,
      color: AppColors.splashGold,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.prayerSilhouette, AppColors.primaryDark],
          ),
          boxShadow: widget.shadow
              ? [
                  // Cast onto a background video: dark enough to read on a
                  // dark scene, soft enough not to look like a cut-out.
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 36,
                    offset: const Offset(0, 18),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: !full
              ? Center(child: wordmark)
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: _GlowPainter(clock: _clock),
                      ),
                    ),
                    if (widget.radius > 0)
                      Padding(
                        padding: EdgeInsets.all(size * 0.045),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                math.max(0, widget.radius - size * 0.045)),
                            border: Border.all(
                              color:
                                  AppColors.splashGold.withValues(alpha: 0.16),
                              width: 0.8,
                            ),
                          ),
                        ),
                      ),
                    RepaintBoundary(
                      child: RotationTransition(
                        turns: _clock,
                        child: CustomPaint(
                          painter: ShamsaPainter(
                            color: AppColors.splashGold,
                            radius: shamsa,
                          ),
                        ),
                      ),
                    ),
                    Center(child: wordmark),
                  ],
                ),
        ),
      ),
    );
  }
}

/// A soft gold light behind the medallion that swells and settles.
class _GlowPainter extends CustomPainter {
  _GlowPainter({required this.clock}) : super(repaint: clock);

  final Animation<double> clock;

  @override
  void paint(Canvas canvas, Size size) {
    final breath = 0.5 -
        0.5 * math.cos(clock.value * 2 * math.pi * RecitationArtwork._breaths);
    final c = size.center(Offset.zero);
    final r = size.shortestSide * (0.46 + 0.04 * breath);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.splashGold.withValues(alpha: 0.13 + 0.07 * breath),
          AppColors.splashGold.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.clock != clock;
}
