import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import '../../../../core/design/design.dart';
import '../../data/onboarding_pages.dart';
import 'onboarding_chrome.dart';

/// One page: the illustration on top (about 60% of the height, a little
/// less as the text grows), then the title and the body. The illustration
/// trails the page at 0.6× its speed; the words move with it. At very
/// large text sizes the page scrolls instead of clipping.
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
                child: _Parallax(
                  controller: controller,
                  index: index,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          context.trPair(page.title),
                          textAlign: TextAlign.center,
                          style: AppTypography.title1.copyWith(color: c.label),
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
            ],
          ),
        ),
      );
    });
  }
}

/// Holds [child] back as the page turns, so it moves at 0.6× the page's
/// speed, in either direction.
class _Parallax extends StatelessWidget {
  const _Parallax({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  static const double _lag = 0.4;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, box) => AnimatedBuilder(
        animation: controller,
        child: child,
        builder: (context, child) {
          final offset =
              (onboardingPageOf(controller) - index).clamp(-1.0, 1.0);
          return Transform.translate(
            offset: Offset((rtl ? -1 : 1) * offset * box.maxWidth * _lag, 0),
            child: child,
          );
        },
      ),
    );
  }
}
