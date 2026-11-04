import 'dart:math' as math;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/design.dart';
import '../../../core/localization/tr.dart';
import '../../fajr_call/presentation/screens/fajr_call_lists_screen.dart';
import '../../khatma/presentation/screens/khatma_screen.dart';
import '../../qibla/presentation/screens/qibla_screen.dart';
import '../../quran/mushaf/presentation/screens/mushaf_screen.dart';
import '../../tasbih/presentation/screens/tasbih_screen.dart';

/// Home's side menu: a panel that slides in from the start edge (the right
/// in RTL, where Arabic apps keep their menu) and lists the app's places, grouped as
/// Quran, prayer and dhikr. It is headed by a horseshoe-arch niche carrying
/// the app's name and the dua the name comes from.
///
/// Closes on a tap outside, a swipe back towards its edge, or a pick; the
/// pick is opened once the panel has been popped.
class HomeSidebar {
  HomeSidebar._();

  static Future<void> show(BuildContext context) async {
    final router = GoRouter.of(context);
    final place = await Navigator.of(context, rootNavigator: true).push(
      _SidebarRoute<_Place>(
        barrierColor:
            CupertinoDynamicColor.resolve(kCupertinoModalBarrierColor, context),
        barrierLabel: context.tr('إغلاق القائمة', 'Close menu'),
        transitionDuration: AppMotion.of(context),
      ),
    );
    place?.open(router);
  }

  /// Panel width: most of a phone, capped for tablets.
  static double width(BuildContext context) =>
      math.min(320, MediaQuery.sizeOf(context).width * 0.84);
}

/// One destination in the menu.
class _Place {
  const _Place(this.label, this.icon, this.color, this.open);

  final String label;
  final IconData icon;

  /// An icon-tile token, as on the Home shortcut cards.
  final Color color;
  final void Function(GoRouter router) open;
}

List<List<_Place>> _groups(BuildContext context) => [
      [
        _Place(
          context.tr('القرآن الكريم', 'The Quran'),
          CupertinoIcons.book_fill,
          AppColors.accent,
          (r) => r.go('/quran'),
        ),
        _Place(
          context.tr('الاستماع', 'Listen'),
          CupertinoIcons.headphones,
          AppColors.tilePurple,
          (r) => r.go('/quran?tab=2'),
        ),
        _Place(
          context.tr('المصحف الشريف', 'The Mushaf'),
          // The Mushaf tab's open book.
          Icons.menu_book_rounded,
          AppColors.tileGreen,
          (r) => r.push(MushafScreen.path),
        ),
        _Place(
          context.tr('ختمة القرآن', 'Quran khatma'),
          Icons.auto_stories_rounded,
          AppColors.tileYellow,
          (r) => r.push(KhatmaScreen.path),
        ),
      ],
      [
        _Place(
          context.tr('القبلة', 'Qibla'),
          CupertinoIcons.compass_fill,
          AppColors.tileBlue,
          (r) => r.push(QiblaScreen.path),
        ),
        _Place(
          context.tr('نداء الفجر', 'Fajr Call'),
          CupertinoIcons.sunrise_fill,
          AppColors.tileOrange,
          (r) => r.go(FajrCallListsScreen.path),
        ),
      ],
      [
        _Place(
          context.tr('الأذكار', 'Adhkar'),
          CupertinoIcons.moon_stars_fill,
          AppColors.tileIndigo,
          (r) => r.go('/home/adhkar'),
        ),
        _Place(
          context.tr('التسبيح', 'Tasbih'),
          CupertinoIcons.circle_grid_hex_fill,
          AppColors.tileTeal,
          (r) => r.push(TasbihScreen.path),
        ),
      ],
    ];

/// Slides the panel in from the start edge over a dimmed page. While the user
/// drags it the panel follows the finger linearly, then settles from there.
class _SidebarRoute<T> extends PopupRoute<T> {
  _SidebarRoute({
    required this.barrierColor,
    required this.barrierLabel,
    required this.transitionDuration,
  });

  @override
  final Color barrierColor;

  @override
  final String barrierLabel;

  @override
  final Duration transitionDuration;

  @override
  bool get barrierDismissible => true;

  /// Flings faster than this (logical px/s) close or keep the panel open
  /// whatever its position; the same threshold as the iOS back swipe.
  static const double _flingVelocity = 365;

  late final CurvedAnimation _curved = CurvedAnimation(
    parent: animation!,
    curve: AppMotion.curve,
    reverseCurve: AppMotion.curve.flipped,
  );

  /// True from a drag's start to its end; a drag that starts while the
  /// panel is already closing is ignored.
  bool _dragging = false;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      const _SidebarPanel();

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final width = HomeSidebar.width(context);
    // Towards the panel's edge: right in RTL, left in LTR.
    final out = rtl ? 1.0 : -1.0;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: GestureDetector(
        onHorizontalDragStart: (_) => _dragStart(),
        onHorizontalDragUpdate: (d) {
          if (_dragging) controller!.value -= out * d.primaryDelta! / width;
        },
        onHorizontalDragEnd: (d) => _dragEnd(out * (d.primaryVelocity ?? 0)),
        onHorizontalDragCancel: () => _dragEnd(0),
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final t = navigator!.userGestureInProgress
                ? animation.value
                : _curved.value;
            return FractionalTranslation(
              translation: Offset(out * (1 - t), 0),
              child: child,
            );
          },
          child: child,
        ),
      ),
    );
  }

  void _dragStart() {
    if (!isCurrent) return;
    _dragging = true;
    navigator!.didStartUserGesture();
  }

  /// Settles the panel after a drag: [velocity] is positive towards its
  /// edge.
  void _dragEnd(double velocity) {
    if (!_dragging) return;
    _dragging = false;
    final close = velocity > _flingVelocity ||
        (velocity > -_flingVelocity && controller!.value < 0.5);
    if (close) {
      navigator!.pop();
    } else {
      controller!.forward();
    }
    if (!controller!.isAnimating) {
      navigator!.didStopUserGesture();
      return;
    }
    late final AnimationStatusListener done;
    done = (status) {
      if (status == AnimationStatus.forward ||
          status == AnimationStatus.reverse) {
        return;
      }
      navigator?.didStopUserGesture();
      controller?.removeStatusListener(done);
    };
    controller!.addStatusListener(done);
  }

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }
}

class _SidebarPanel extends StatelessWidget {
  const _SidebarPanel();

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final groups = _groups(context);

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: context.tr('القائمة', 'Menu'),
      child: Container(
        width: HomeSidebar.width(context),
        height: double.infinity,
        decoration: BoxDecoration(
          color: c.resolve(AppColors.prayerFrame),
          // The open edge is gilded like the prayer-times frame.
          border: BorderDirectional(
            end: BorderSide(color: c.gold.withValues(alpha: 0.55)),
          ),
          boxShadow: [BoxShadow(color: c.shadow(0.6), blurRadius: 32)],
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Masthead(),
                const SizedBox(height: AppSpacing.lg),
                for (var g = 0; g < groups.length; g++) ...[
                  if (g > 0)
                    Container(
                      height: AppSpacing.hairline,
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.ml,
                        vertical: AppSpacing.sm,
                      ),
                      color: c.separator,
                    ),
                  for (final place in groups[g]) _SidebarRow(place: place),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The niche with a gilded hilal and the app's name, and under it the dua
/// it is named after (al-Isra 17:23).
class _Masthead extends StatelessWidget {
  const _Masthead();

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Column(
      children: [
        SizedBox(
          width: _NichePainter.size.width,
          height: _NichePainter.size.height,
          child: CustomPaint(
            painter: _NichePainter(gold: c.gold),
            child: Column(
              children: [
                // The hilal and its star in the crown of the arch.
                const SizedBox(height: 18),
                CustomPaint(
                  size: const Size.square(38),
                  painter: HilalPainter(c.gold),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'إحسان',
                      textDirection: TextDirection.rtl,
                      style: AppTypography.title1
                          .copyWith(color: AppColors.onAccent, height: 1.2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.ms),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            '﴿وَبِالْوَالِدَيْنِ إِحْسَانًا﴾',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: AppTypography.quran(size: 19, height: 1.7)
                .copyWith(color: c.secondaryLabel),
          ),
        ),
      ],
    );
  }
}

/// A Maghrebi horseshoe arch: the arc runs past its half-circle before
/// dropping into the jambs, so the opening is narrower than the arch.
/// Filled with the hero green, outlined twice in gold like a zellige frame.
class _NichePainter extends CustomPainter {
  const _NichePainter({required this.gold});

  final Color gold;

  static const Size size = Size(112, 144);

  static Path _arch(Size size, double inset) => horseshoeArch(size, inset);

  @override
  void paint(Canvas canvas, Size size) {
    final outer = _arch(size, 0.5);
    canvas
      ..drawPath(
        outer,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.heroGradient,
          ).createShader(Offset.zero & size),
      )
      ..drawPath(
        outer,
        Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      )
      ..drawPath(
        _arch(size, 5),
        Paint()
          ..color = gold.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7,
      );
  }

  @override
  bool shouldRepaint(_NichePainter old) => old.gold != gold;
}

class _SidebarRow extends StatefulWidget {
  const _SidebarRow({required this.place});

  final _Place place;

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final place = widget.place;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).pop(place);
        },
        child: Container(
          constraints:
              const BoxConstraints(minHeight: AppSpacing.minTouchTarget + 8),
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.ms,
            vertical: AppSpacing.sm,
          ),
          decoration: ShapeDecoration(
            color: _pressed ? c.accentTint : CupertinoColors.transparent,
            shape: AppRadius.continuous(AppRadius.medium),
          ),
          child: Row(
            children: [
              AppIconTile(icon: place.icon, color: place.color, size: 32),
              const SizedBox(width: AppSpacing.ms + 2),
              Expanded(
                child: Text(
                  place.label,
                  style: AppTypography.headline.copyWith(color: c.label),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
