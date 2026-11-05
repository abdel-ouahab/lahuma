import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/design.dart';
import '../../core/localization/tr.dart';
import '../adhan/presentation/adhan_cleared_notice.dart';
import '../adhan/presentation/adhan_providers.dart';
import '../onboarding/presentation/screens/onboarding_screen.dart';
import 'bootstrap.dart';

/// Where the splash's pieces sit. The wordmark matches the native launch
/// screen exactly (tools/generate_icon/generate.py, SPLASH_WIDTH), so the
/// first Flutter frame is the same picture.
class SplashLayout {
  SplashLayout._();

  static const String wordmarkAsset = 'assets/images/wordmark.png';
  static const double wordmarkWidth = 160;

  /// Height over width of [wordmarkAsset].
  static const double wordmarkAspect = 407 / 640;

  /// The shamsa's scalloped ring around the wordmark; smaller on narrow
  /// phones, so its rays (to [ShamsaPainter.reach] radii) stay on screen.
  static const double shamsaRadius = 112;
}

/// Decodes the wordmark before the first frame (call it in `main`), so that
/// frame draws it where the native launch screen did instead of blinking it
/// out while the image loads. Gives up after a moment rather than hold the
/// launch.
Future<void> precacheSplashWordmark() {
  final done = Completer<void>();
  void finish([Object? _, StackTrace? __]) {
    if (!done.isCompleted) done.complete();
  }

  final stream = const AssetImage(SplashLayout.wordmarkAsset)
      .resolve(ImageConfiguration.empty);
  final listener = ImageStreamListener((_, __) => finish(), onError: finish);
  stream.addListener(listener);
  return done.future
      .timeout(const Duration(milliseconds: 500), onTimeout: () {})
      .whenComplete(() => stream.removeListener(listener));
}

/// The opening of an illuminated Mushaf: the gold wordmark the native
/// launch screen showed stays where it is while the shamsa, the medallion
/// that opens a Mushaf, gathers around it: its scalloped ring traces itself
/// from the top down both sides, its rays open out, it settles, and a band
/// of light crosses the gold once; then the tagline rises. One controller
/// drives the timeline:
///
/// | ms        | what                                                    |
/// |-----------|---------------------------------------------------------|
/// | 0         | the native launch screen: flat colour, wordmark         |
/// | 0–600     | the ring traces itself; the glow comes up               |
/// | 250–1000  | the rays open out, from the top round to the bottom     |
/// | 300–900   | the medallion settles from 1.06× (spring)               |
/// | 850–1250  | a band of light crosses the wordmark                    |
/// | 950–1350  | the tagline rises 12 pt and fades in                    |
/// | 1050–1400 | the loader, if start-up is still running                |
///
/// It leaves once [bootstrapProvider] is done and [SplashTiming.minimum]
/// has passed (or after [SplashTiming.maximum]): the content fades out,
/// then Home (with a notification's screen on top) or, on the first
/// launch, the introduction. A launch from a notification never shows the
/// introduction: that screen is needed now. With Reduce Motion the last
/// frame shows at once and the splash leaves as soon as start-up is done.
///
/// The splash follows the phone's appearance, as the native launch screen
/// does, not the app's theme setting.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  static const _timelineLength = Duration(milliseconds: 1600);

  late final AnimationController _timeline =
      AnimationController(vsync: this, duration: _timelineLength);
  late final AnimationController _exit =
      AnimationController(vsync: this, duration: SplashTiming.exit);
  late final AnimationController _breath = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

  late final Animation<double> _trace = _segment(0, 600, Curves.easeInOutCubic);
  late final Animation<double> _bloom =
      _segment(250, 1000, Curves.easeOutCubic);
  late final Animation<double> _ambient = _segment(0, 600, Curves.easeOut);
  late final Animation<double> _settle = Tween<double>(begin: 1.06, end: 1)
      .animate(_segment(
          300, 900, AppMotion.springCurve(const Duration(milliseconds: 600))));
  late final Animation<double> _sweep = _segment(850, 1250, Curves.easeInOut);
  late final Animation<double> _tagline =
      _segment(950, 1350, Curves.easeOutCubic);
  late final Animation<double> _loaderIn = _segment(1050, 1400, Curves.easeOut);

  late final Animation<double> _contentOut =
      Tween<double>(begin: 1, end: 0).animate(_exit);
  late final Animation<double> _contentScale =
      Tween<double>(begin: 1, end: 1.04)
          .animate(CurvedAnimation(parent: _exit, curve: Curves.easeIn));

  /// Start-up work still running: the loader shows only then.
  bool _pending = true;
  bool _started = false;

  Animation<double> _segment(int startMs, int endMs, Curve curve) {
    final total = _timelineLength.inMilliseconds;
    return CurvedAnimation(
      parent: _timeline,
      curve: Interval(startMs / total, endMs / total, curve: curve),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _timeline.value = 1;
      _breath.stop();
    } else if (!_started) {
      _timeline.forward();
    }
    if (!_started) {
      _started = true;
      _leaveWhenReady(reduceMotion: reduceMotion);
    }
  }

  Future<void> _leaveWhenReady({required bool reduceMotion}) async {
    final bootstrap = ref.read(bootstrapProvider.future);
    bootstrap.whenComplete(_settled).ignore();
    if (!reduceMotion) {
      _timeline.addListener(_startBreathing);
    }
    final result = await splashGate(
      bootstrap,
      minimum: reduceMotion ? Duration.zero : SplashTiming.minimum,
      maximum: SplashTiming.maximum,
      fallback: () => BootstrapResult(
        onboardingCompleted: true,
        launchRoute: ref.read(launchRouteProvider),
      ),
    );
    if (!mounted) return;
    if (!MediaQuery.disableAnimationsOf(context)) await _exit.forward();
    if (!mounted) return;

    final router = GoRouter.of(context);
    final launch = result.launchRoute;
    if (launch != null) {
      // A tapped notification (the Fajr wake list, an adhan) launched the
      // app: open it on top of Home so "back" lands somewhere sensible.
      router.go('/home');
      router.push(launch);
    } else if (!result.onboardingCompleted) {
      router.go(OnboardingScreen.path);
    } else {
      router.go('/home');
      // The phone cancelled the adhans since the last launch: say so.
      showAdhanClearedNoticeIfNeeded(
          router, ref.read(adhanAlarmPlatformProvider));
    }
  }

  void _settled() {
    if (!mounted) return;
    setState(() => _pending = false);
    _breath.stop();
  }

  /// The loader breathes from the moment it appears, while still needed.
  void _startBreathing() {
    if (_loaderIn.value == 0) return;
    _timeline.removeListener(_startBreathing);
    if (_pending && mounted) _breath.repeat();
  }

  @override
  void dispose() {
    _timeline.removeListener(_startBreathing);
    _timeline.dispose();
    _exit.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Resolve the splash tokens against the phone, like the launch screen.
    final brightness = MediaQuery.platformBrightnessOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: CupertinoTheme(
        data: CupertinoTheme.of(context).copyWith(brightness: brightness),
        child: Builder(builder: _scene),
      ),
    );
  }

  Widget _scene(BuildContext context) {
    final c = context.palette;
    final background = c.resolve(AppColors.splashBackground);
    final glow = c.resolve(AppColors.splashGlow);
    const gold = AppColors.splashGold;

    return Semantics(
      label: context.tr('إحسان، جارٍ فتح التطبيق', 'Ihsan, opening the app'),
      liveRegion: true,
      child: ColoredBox(
        color: background,
        child: LayoutBuilder(builder: (context, box) {
          final size = box.biggest;
          final radius = math.min(SplashLayout.shamsaRadius,
              (size.width / 2 - AppSpacing.md) / ShamsaPainter.reach);
          return Stack(
            fit: StackFit.expand,
            children: [
              FadeTransition(
                opacity: _ambient,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.9,
                      colors: [glow, glow.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              FadeTransition(
                opacity: _contentOut,
                child: ScaleTransition(
                  scale: _contentScale,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: ShamsaPainter(
                            trace: _trace,
                            bloom: _bloom,
                            scale: _settle,
                            color: gold,
                            radius: radius,
                          ),
                        ),
                      ),
                      Center(child: _Wordmark(sweep: _sweep)),
                      Positioned(
                        top: size.height / 2 +
                            radius * ShamsaPainter.reach +
                            AppSpacing.md,
                        left: AppSpacing.xl,
                        right: AppSpacing.xl,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Rise(
                              animation: _tagline,
                              child: Text(
                                'قرآنٌ يُتلى، وأجرٌ يُهدى.',
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style:
                                    AppTypography.quran(size: 19, height: 1.6)
                                        .copyWith(
                                            color: AppColors.onAccent
                                                .withValues(alpha: 0.85)),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AnimatedOpacity(
                              opacity: _pending ? 1 : 0,
                              duration: AppMotion.of(context, AppMotion.fast),
                              child: _Rise(
                                animation: _loaderIn,
                                child: _BreathingDots(
                                    breath: _breath, color: gold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// The gold wordmark, with a band of light crossing it once as [sweep]
/// runs from 0 to 1. It keeps its size under large text: it is artwork.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.sweep});

  final Animation<double> sweep;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      SplashLayout.wordmarkAsset,
      width: SplashLayout.wordmarkWidth,
      height: SplashLayout.wordmarkWidth * SplashLayout.wordmarkAspect,
      color: AppColors.splashGold,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
      semanticLabel: context.tr('إحسان', 'Ihsan'),
    );
    final light = Color.lerp(AppColors.splashGold, AppColors.onAccent, 0.7)!;
    return AnimatedBuilder(
      animation: sweep,
      child: image,
      builder: (context, child) {
        final t = sweep.value;
        if (t <= 0 || t >= 1) return child!;
        // The band's centre runs from before the left edge to past the
        // right one, tilted like light across a page.
        final p = -0.25 + 1.5 * t;
        double at(double v) => v.clamp(0.0, 1.0);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: const Alignment(-1, -0.7),
            end: const Alignment(1, 0.7),
            colors: [
              light.withValues(alpha: 0),
              light.withValues(alpha: 0.85),
              light.withValues(alpha: 0),
            ],
            stops: [at(p - 0.16), at(p), at(p + 0.16)],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// Fades [child] in while lifting it 12 pt, as [animation] runs 0 → 1.
class _Rise extends StatelessWidget {
  const _Rise({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - animation.value)),
            child: child,
          ),
        ),
      );
}

/// The loader: three small gold dots, like the shamsa's, breathing one
/// after another.
class _BreathingDots extends StatelessWidget {
  const _BreathingDots({required this.breath, required this.color});

  final Animation<double> breath;
  final Color color;

  static const double _dot = 6;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: breath,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Container(
                  width: _dot,
                  height: _dot,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(
                        alpha: _alpha(breath.value, i, breath.isAnimating)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 0.35…1 on a slow sine, each dot a third of a breath behind the last;
  /// a steady 0.6 when not breathing (Reduce Motion).
  static double _alpha(double t, int i, bool breathing) {
    if (!breathing) return 0.6;
    final phase = (t - i / 3) * 2 * math.pi;
    return 0.35 + 0.65 * (0.5 - 0.5 * math.cos(phase));
  }
}
