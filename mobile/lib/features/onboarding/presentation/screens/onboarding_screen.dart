import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_settings_enum.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../settings/presentation/settings_providers.dart';
import '../../../settings/presentation/theme_mode_switcher.dart';
import '../../data/onboarding_pages.dart';
import '../onboarding_controller.dart';
import '../widgets/onboarding_art.dart';
import '../widgets/onboarding_chrome.dart';
import '../widgets/onboarding_page_view.dart';

/// The introduction: six pages on the app's features, then a short last
/// step. Shown once after the first launch (the splash decides), and again
/// from Settings. Skip and Start both mark it seen. It asks for no
/// permission: each feature asks for its own, in context.
///
/// In Arabic the first page is on the right and the next one comes in from
/// the left, as the Mushaf turns.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.replay = false});

  static const path = '/onboarding';

  /// Opened again from Settings: finishing returns there.
  static const replayPath = '$path?replay=1';

  final bool replay;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();

  /// The current page, for the pieces that change with it (Skip, the
  /// button, which illustration plays) without rebuilding the page view.
  final _current = ValueNotifier<int>(0);

  /// A button is turning the page: it already gave its own haptic.
  bool _turning = false;
  bool _finishing = false;

  int get _count => onboardingPages.length;

  @override
  void dispose() {
    _pages.dispose();
    _current.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    _current.value = index;
    ref.read(onboardingControllerProvider.notifier).pageChanged(index);
    if (!_turning) HapticFeedback.selectionClick();
  }

  Future<void> _turnTo(int index) async {
    final duration = AppMotion.of(context, const Duration(milliseconds: 450));
    if (duration == Duration.zero) {
      _pages.jumpToPage(index);
      return;
    }
    _turning = true;
    await _pages.animateToPage(index,
        duration: duration, curve: Curves.easeInOutCubic);
    _turning = false;
  }

  Future<void> _next() async {
    final index = _current.value;
    if (index >= _count - 1) return _finish(start: true);
    await _turnTo(index + 1);
  }

  Future<void> _finish({required bool start}) async {
    if (_finishing) return;
    _finishing = true;
    if (start) HapticFeedback.mediumImpact();
    await ref
        .read(onboardingControllerProvider.notifier)
        .complete(firstRun: !widget.replay);
    if (!mounted) return;
    if (widget.replay && context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: c.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: ValueListenableBuilder<int>(
        valueListenable: _current,
        // Back goes to the previous page; on the first, it leaves as usual.
        builder: (context, current, child) => PopScope(
          canPop: current == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && current > 0) _turnTo(current - 1);
          },
          child: child!,
        ),
        child: Stack(
          children: [
            OnboardingBackdrop(
              controller: _pages,
              tints: [for (final p in onboardingPages) p.tint],
            ),
            SafeArea(
              child: Column(
                children: [
                  _SkipBar(
                      current: _current,
                      count: _count,
                      onSkip: () {
                        _finish(start: false);
                      }),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: _count,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, index) {
                        final page = onboardingPages[index];
                        return OnboardingPageView(
                          page: page,
                          index: index,
                          controller: _pages,
                          art: ValueListenableBuilder<int>(
                            valueListenable: _current,
                            builder: (context, current, _) => OnboardingArt(
                                id: page.id, active: current == index),
                          ),
                          footer: page.isLast ? const _StartChoices() : null,
                        );
                      },
                    ),
                  ),
                  _BottomBar(
                    controller: _pages,
                    current: _current,
                    count: _count,
                    onNext: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skip at the top's trailing edge (the left in Arabic), gone on the last
/// page.
class _SkipBar extends StatelessWidget {
  const _SkipBar({
    required this.current,
    required this.count,
    required this.onSkip,
  });

  final ValueListenable<int> current;
  final int count;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: ValueListenableBuilder<int>(
            valueListenable: current,
            builder: (context, index, child) {
              final last = index == count - 1;
              return IgnorePointer(
                ignoring: last,
                child: AnimatedOpacity(
                  opacity: last ? 0 : 1,
                  duration: AppMotion.of(context, AppMotion.fast),
                  child: ExcludeSemantics(excluding: last, child: child!),
                ),
              );
            },
            child: AppButton.plain(
              label: context.tr('تخطي', 'Skip'),
              onPressed: onSkip,
            ),
          ),
        ),
      ),
    );
  }
}

/// The page dots and the one primary action: Next, then Start.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.controller,
    required this.current,
    required this.count,
    required this.onNext,
  });

  final PageController controller;
  final ValueListenable<int> current;
  final int count;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
      child: ValueListenableBuilder<int>(
        valueListenable: current,
        builder: (context, index, _) {
          final last = index == count - 1;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: context.tr(
                    'الصفحة ${ltr('${index + 1}')} من ${ltr('$count')}',
                    'Page ${index + 1} of $count'),
                child:
                    OnboardingIndicator(controller: controller, count: count),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton.filled(
                label: last
                    ? context.tr('ابدأ', 'Start')
                    : context.tr('التالي', 'Next'),
                trailingIcon: last ? null : CupertinoIcons.chevron_forward,
                expand: true,
                onPressed: onNext,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The last page's choices: the language and the look, applied at once.
class _StartChoices extends ConsumerWidget {
  const _StartChoices();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeOptionProvider);
    final mode = ref.watch(themeModeProvider);
    return Column(
      children: [
        Semantics(
          label: context.tr('اللغة', 'Language'),
          child: AppSegmentedControl<AppLocaleOption>(
            segments: const {
              AppLocaleOption.arabic: 'العربية',
              AppLocaleOption.english: 'English',
            },
            value: locale,
            onChanged: (value) =>
                ref.read(localeOptionProvider.notifier).update(value),
          ),
        ),
        const SizedBox(height: AppSpacing.ms),
        Semantics(
          label: context.tr('المظهر', 'Appearance'),
          child: ThemeModeSwitcher(
            builder: (context, switchTo) => AppSegmentedControl<AppThemeMode>(
              segments: {
                AppThemeMode.light: context.tr('فاتح', 'Light'),
                AppThemeMode.dark: context.tr('داكن', 'Dark'),
                AppThemeMode.system: context.tr('تلقائي', 'Auto'),
              },
              value: mode,
              onChanged: switchTo,
            ),
          ),
        ),
      ],
    );
  }
}
