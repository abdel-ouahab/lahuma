import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/design.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce Motion: show the final frame straight away.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const onBrand = AppColors.onAccent;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.splashGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The mark and wordmark are artwork: they keep their size
                  // under large text. The tagline below still scales.
                  MediaQuery.withNoTextScaling(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: onBrand.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            'ل',
                            style: AppTypography.quran(
                              size: 52,
                              weight: FontWeight.w700,
                              height: 1.2,
                            ).copyWith(color: onBrand),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'لهما',
                          style: AppTypography.quran(
                            size: 52,
                            weight: FontWeight.w700,
                            height: 1.4,
                          ).copyWith(color: onBrand),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.ms),
                  Text(
                    'قرآنٌ يُتلى، وأجرٌ يُهدى.',
                    textAlign: TextAlign.center,
                    style: AppTypography.quran(size: 17, height: 1.6)
                        .copyWith(color: onBrand.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
