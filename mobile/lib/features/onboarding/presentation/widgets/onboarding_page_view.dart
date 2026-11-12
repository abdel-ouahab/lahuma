import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import '../../../../core/design/design.dart';
import '../../data/onboarding_pages.dart';
import 'onboarding_chrome.dart';

/// One page: the illustration on top (about 60% of the height, a little
/// less as the text grows), then the title and the body. As the page
/// turns, its illustration trails just behind it, shrinks a touch and fades,
/// and its words fade, so the leaving page and the arriving one never draw
/// over each other. At very large text sizes the page scrolls instead of
/// clipping.
class OnboardingPageView extends StatelessWidget {
  const OnboardingPageView({
    super.key,
    required this.page,
    required this.index,
    required this.controller,
    required this.art,
    this.footer,
  });

  final OnboardingPage page;
  final int index;
  final PageController controller;
  final Widget art;

  /// Extra controls under the words (the last page's choices).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final grown = ((scale - 1) / 1).clamp(0.0, 1.0);
    final share = lerpDouble(0.6, 0.4, grown)! * (footer == null ? 1 : 0.6);
    final iosNote =
        page.iosNote != null && defaultTargetPlatform == TargetPlatform.iOS;

    return LayoutBuilder(builder: (context, box) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Column(
            children: [
              SizedBox(
                height: box.maxHeight * share,
                child: _TurnMotion(
                  controller: controller,
                  index: index,
                  lag: 0.1,
                  shrink: 0.06,
                  fadeBy: 1,
                  child: Semantics(
                    image: true,
                    label: context.trPair(page.art),
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg),
                        child: RepaintBoundary(child: art),
                      ),
                    ),
                  ),
                ),
              ),
              _TurnMotion(
                controller: controller,
                index: index,
                fadeBy: 0.8,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl,
                      AppSpacing.lg, AppSpacing.xl, AppSpacing.md),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            context.trPair(page.title),
                            textAlign: TextAlign.center,
                            style:
                                AppTypography.title1.copyWith(color: c.label),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          context.trPair(page.body),
                          textAlign: TextAlign.center,
                          style: AppTypography.callout
                              .copyWith(color: c.secondaryLabel, height: 1.6),
                        ),
                        if (iosNote) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            context.trPair(page.iosNote!),
                            textAlign: TextAlign.center,
                            style: AppTypography.footnote
                                .copyWith(color: c.secondaryLabel),
                          ),
                        ],
                        if (footer != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          footer!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// How a page's part moves as the page turns, from how far its page is
/// from the middle (0 in place, ±1 a whole page away):
///
/// * [lag]: held back by this share of the page width, for a little depth.
///   Kept small: a large lag slides the leaving page's part over the
///   arriving one's.
/// * [shrink]: scaled down by this much a page away.
/// * [fadeBy]: fully faded this far from the middle; the leaving and the
///   arriving page cross-fade instead of drawing over each other.
///
/// The [child] is built once; each frame only moves and fades it, so a
/// swipe composites what is already drawn instead of repainting it.
class _TurnMotion extends StatelessWidget {
  const _TurnMotion({
    required this.controller,
    required this.index,
    required this.child,
    this.lag = 0,
    this.shrink = 0,
    this.fadeBy = 1,
  });

  final PageController controller;
  final int index;
  final Widget child;
  final double lag;
  final double shrink;
  final double fadeBy;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // Reduce Motion: no drift or zoom, the parts only fade.
    final still = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, box) => AnimatedBuilder(
        animation: controller,
        child: child,
        builder: (context, child) {
          final t = (onboardingPageOf(controller) - index).clamp(-1.0, 1.0);
          final away = t.abs();
          // Linear: the two pages cross-fade evenly, so the middle of a
          // swipe is never empty.
          final fade = (away / fadeBy).clamp(0.0, 1.0);
          final moving = !still && (lag > 0 || shrink > 0);
          final scale = moving ? 1 - shrink * away : 1.0;
          // Always the same two wrappers, so the child keeps its state (a
          // miniature mid-animation) whatever the page's position.
          return Opacity(
            opacity: 1 - fade,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translateByDouble(
                    moving ? (rtl ? -1 : 1) * t * box.maxWidth * lag : 0,
                    0,
                    0,
                    1)
                ..scaleByDouble(scale, scale, 1, 1),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
