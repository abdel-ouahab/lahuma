import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/design.dart';
import '../../core/notifications/notification_providers.dart';
import '../adhan/presentation/adhan_cleared_notice.dart';
import '../adhan/presentation/adhan_providers.dart';

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
      if (!mounted) return;
      // A tapped notification (the Fajr wake list or its results) launched
      // the app: open it on top of Home so "back" lands somewhere sensible.
      final container = ProviderScope.containerOf(context, listen: false);
      final launch =
          container.read(localNotificationsProvider).takeLaunchRoute();
      final router = GoRouter.of(context);
      context.go('/home');
      if (launch != null) {
        context.push(launch);
      } else {
        // The phone cancelled the adhans since the last launch: say so.
        showAdhanClearedNoticeIfNeeded(
            router, container.read(adhanAlarmPlatformProvider));
      }
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
                  // The logo is artwork: it keeps its size under large text.
                  // The tagline below still scales.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(44),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow.withValues(alpha: 0.25),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 200,
                      height: 200,
                      semanticLabel: 'لهما',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
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
