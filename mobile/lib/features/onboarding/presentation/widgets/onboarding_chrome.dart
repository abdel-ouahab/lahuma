import '../../../../core/design/design.dart';

/// Where [controller] is, in pages, before and after it has a position.
double onboardingPageOf(PageController controller) => controller.hasClients
    ? controller.page ?? controller.initialPage.toDouble()
    : controller.initialPage.toDouble();

/// Behind the pages: the page colour and a wash of each page's [tints]
/// falling from the top, cross-fading as the pages turn (dawn on the Fajr
/// page). Only the wash repaints while swiping.
class OnboardingBackdrop extends StatelessWidget {
  const OnboardingBackdrop({
    super.key,
    required this.controller,
    required this.tints,
  });

  final PageController controller;
  final List<Color> tints;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final strength = c.isDark ? 0.2 : 0.13;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: c.groupedBackground),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final page =
                  onboardingPageOf(controller).clamp(0.0, tints.length - 1.0);
              final i = page.floor();
              final j = (i + 1).clamp(0, tints.length - 1);
              final tint = Color.lerp(
                  c.resolve(tints[i]), c.resolve(tints[j]), page - i)!;
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.8),
                    radius: 1.15,
                    colors: [
                      tint.withValues(alpha: strength),
                      tint.withValues(alpha: 0),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The page dots: the current one stretches into a green pill with a gold
/// rim, following the finger between pages. Reads in the layout's
/// direction (the first page's dot on the right in Arabic).
class OnboardingIndicator extends StatelessWidget {
  const OnboardingIndicator({
    super.key,
    required this.controller,
    required this.count,
  });

  final PageController controller;
  final int count;

  static const double _dot = 8;
  static const double _pill = 28;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final page = onboardingPageOf(controller);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++)
                () {
                  // 1 on the current page, falling to 0 one page away.
                  final t = (1 - (page - i).abs()).clamp(0.0, 1.0);
                  return Container(
                    width: _dot + (_pill - _dot) * t,
                    height: _dot,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Color.lerp(c.tertiaryLabel, c.accent, t),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: c.gold.withValues(alpha: t),
                        width: 1.2,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      ),
                    ),
                  );
                }(),
            ],
          );
        },
      ),
    );
  }
}

/// The gilded frame each illustration sits in: the corners of a Mushaf
/// page's frame, the miniature centred inside at its designed size or
/// smaller. Miniatures are artwork, so their own words don't grow with the
/// text size (their meaning is in the page's semantic label).
class OnboardingArtFrame extends StatelessWidget {
  const OnboardingArtFrame({
    super.key,
    required this.child,
    this.size = const Size(300, 280),
  });

  final Widget child;

  /// The miniature's design size; it scales down to fit.
  final Size size;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return CustomPaint(
      foregroundPainter: FrameCornersPainter(c.gold),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: MediaQuery.withNoTextScaling(
          child: FittedBox(
            child: SizedBox.fromSize(size: size, child: child),
          ),
        ),
      ),
    );
  }
}
