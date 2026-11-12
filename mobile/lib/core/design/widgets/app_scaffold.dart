import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';
import '../app_motion.dart';
import '../app_spacing.dart';
import '../app_typography.dart';
import 'app_states.dart';

/// Page scaffold.
///
/// * [AppScaffold.new] — pushed screens: standard (small, centred) title bar
///   with the system back chevron (mirrored and on the right in RTL).
/// * [AppScaffold.largeTitle] — tab roots: a large title that collapses into
///   the bar on scroll, optional search / segmented control under it and
///   pull-to-refresh. Without a title, only a slim bar with [leading] /
///   [trailing] sits on top and scrolls away with the page (Home, whose
///   hero carries its own title).
///
/// Bars are translucent: content scrolls under them, and their height reaches
/// the page as `MediaQuery` padding. A `ListView` / `GridView` child picks that
/// up only when it has **no explicit `padding`** — give it spacer children (or
/// pad its items) instead, or the first rows hide under the nav bar.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.title,
    this.leading,
    this.trailing,
    this.previousPageTitle,
    required Widget this.child,
    this.backgroundColor,
    this.navigationBar,
    this.resizeToAvoidBottomInset = true,
  })  : slivers = null,
        bottom = null,
        onRefresh = null,
        scrollController = null,
        _large = false;

  const AppScaffold.largeTitle({
    super.key,
    this.title,
    required List<Widget> this.slivers,
    this.leading,
    this.trailing,
    this.bottom,
    this.onRefresh,
    this.scrollController,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  })  : child = null,
        previousPageTitle = null,
        navigationBar = null,
        _large = true;

  final String? title;
  final Widget? leading;
  final Widget? trailing;
  final String? previousPageTitle;
  final Widget? child;
  final List<Widget>? slivers;

  /// Pinned under the large title (search field, segmented control).
  final PreferredSizeWidget? bottom;
  final Future<void> Function()? onRefresh;
  final ScrollController? scrollController;
  final Color? backgroundColor;

  /// Replaces the default bar (e.g. an [AppNavBar] with custom options).
  final ObstructingPreferredSizeWidget? navigationBar;
  final bool resizeToAvoidBottomInset;
  final bool _large;

  @override
  Widget build(BuildContext context) {
    if (!_large) {
      return CupertinoPageScaffold(
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        navigationBar: navigationBar ??
            (title == null && leading == null && trailing == null
                ? null
                : AppNavBar(
                    title: title,
                    leading: leading,
                    trailing: trailing,
                    previousPageTitle: previousPageTitle,
                  )),
        child: child!,
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      child: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          if (title == null)
            SliverToBoxAdapter(
              child: CupertinoNavigationBar(
                leading: leading,
                trailing: trailing,
                automaticallyImplyLeading: false,
                automaticallyImplyMiddle: false,
                transitionBetweenRoutes: false,
                backgroundColor: backgroundColor ?? AppColors.groupedBackground,
                border: null,
              ),
            )
          else
            CupertinoSliverNavigationBar(
              // Long titles (e.g. adhkar category names) shrink to fit the
              // width instead of being cut off with an ellipsis.
              largeTitle: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.bottomStart,
                child: Text(title!, maxLines: 1, softWrap: false),
              ),
              leading: leading,
              trailing: trailing,
              bottom: bottom,
              bottomMode:
                  bottom == null ? null : NavigationBarBottomMode.always,
            ),
          if (onRefresh != null) AppRefreshSliver(onRefresh: onRefresh!),
          ...slivers!,
          // Room for the home indicator and, inside the tab shell, the tab
          // bar / mini-player (both arrive through MediaQuery padding).
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps a widget so it can sit in [AppScaffold.largeTitle]'s `bottom` slot.
///
/// The slot has a fixed height, so text inside it does not grow with Dynamic
/// Type (like UIKit's bar accessories); everything below the bar still does.
class AppNavBarBottom extends StatelessWidget implements PreferredSizeWidget {
  const AppNavBarBottom({super.key, required this.child, this.height = 52});

  final Widget child;
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) => MediaQuery.withNoTextScaling(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screenMargin,
            0,
            AppSpacing.screenMargin,
            AppSpacing.sm,
          ),
          child:
              Align(alignment: AlignmentDirectional.centerStart, child: child),
        ),
      );
}

/// Standard navigation bar. The back button is the system chevron (it
/// mirrors and moves to the right in RTL); never pass a custom arrow.
class AppNavBar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  const AppNavBar({
    super.key,
    this.title,
    this.leading,
    this.trailing,
    this.previousPageTitle,
    this.transparent = false,
    this.automaticallyImplyLeading = true,
  });

  final String? title;
  final Widget? leading;
  final Widget? trailing;
  final String? previousPageTitle;

  /// No background or hairline (over artwork / full-bleed headers).
  final bool transparent;
  final bool automaticallyImplyLeading;

  CupertinoNavigationBar _bar() {
    final middle = title == null
        ? null
        : Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (transparent) {
      return CupertinoNavigationBar(
        middle: middle,
        leading: leading,
        trailing: trailing,
        previousPageTitle: previousPageTitle,
        automaticallyImplyLeading: automaticallyImplyLeading,
        backgroundColor: CupertinoColors.transparent,
        enableBackgroundFilterBlur: false,
        border: null,
      );
    }
    return CupertinoNavigationBar(
      middle: middle,
      leading: leading,
      trailing: trailing,
      previousPageTitle: previousPageTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
    );
  }

  @override
  Size get preferredSize => _bar().preferredSize;

  @override
  bool shouldFullyObstruct(BuildContext context) =>
      _bar().shouldFullyObstruct(context);

  @override
  Widget build(BuildContext context) => _bar();
}

/// One tab of [AppTabBar].
class AppTabItem {
  const AppTabItem(
      {required this.icon, required this.activeIcon, required this.label});

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Floating tab bar, after the "Modern Floating Navbar" Figma kit: a bar
/// (accent blue in light mode, navy in dark) whose top edge dips into a
/// curved notch under the selected tab, which rises out of it as a circle of
/// the same colour. The notch and circle glide between tabs
/// (instantly with Reduce Motion); selection haptic on change.
/// Labels don't grow with Dynamic Type (as on iOS); the bar keeps its height.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<AppTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Height of the bar body, excluding the home-indicator extension.
  static const double height = 68;

  /// How far the selected tab's circle rises above the bar body.
  static const double _rise = 30;
  static const double _circleSize = 50;

  /// Side inset of the tab row; keeps the outer notches clear of the
  /// bar's rounded corners.
  static const double _inset = 24;

  /// The labels already sit 13pt above the bar's bottom edge, so only the
  /// rest of the home-indicator area is added below them.
  static double _bottomExtension(BuildContext context) =>
      math.max(0, MediaQuery.viewPaddingOf(context).bottom - 12);

  /// Height including the raised circle and the bottom safe area.
  static double totalHeight(BuildContext context) =>
      _rise + height + _bottomExtension(context);

  void _select(int index) {
    if (index != currentIndex) HapticFeedback.selectionClick();
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final duration = AppMotion.of(context);
    final c = context.palette;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.0,
      child: SizedBox(
        height: totalHeight(context),
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          final slot = (width - 2 * _inset) / items.length;
          final x = _inset + slot * (currentIndex + 0.5);

          return TweenAnimationBuilder<double>(
            tween: Tween(end: rtl ? width - x : x),
            duration: duration,
            curve: AppMotion.curve,
            builder: (context, notchX, _) => Stack(
              children: [
                Positioned.fill(
                  top: _rise,
                  child: CustomPaint(
                    painter: _NotchedBarPainter(
                      notchX: notchX,
                      color: c.tabBarBackground,
                    ),
                  ),
                ),
                Positioned(
                  left: notchX - _circleSize / 2,
                  top: _rise - _circleSize / 2,
                  width: _circleSize,
                  height: _circleSize,
                  child: GestureDetector(
                    onTap: () => _select(currentIndex),
                    child: DecoratedBox(
                      // The gold ring echoes the prayer-times frame.
                      decoration: BoxDecoration(
                        color: c.tabBarBackground,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.gold, width: 1.5),
                      ),
                      child: AnimatedSwitcher(
                        duration: duration,
                        child: Icon(
                          items[currentIndex].activeIcon,
                          key: ValueKey(currentIndex),
                          size: 24,
                          color: c.tabBarActive,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _inset,
                  right: _inset,
                  top: _rise,
                  height: height,
                  child: Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _TabSlot(
                            item: items[i],
                            selected: i == currentIndex,
                            duration: duration,
                            onTap: () => _select(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// One tab's tap target. The selected tab's icon lives in the raised circle,
/// so here it fades out while the label lifts slightly and brightens.
class _TabSlot extends StatelessWidget {
  const _TabSlot({
    required this.item,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final AppTabItem item;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        excludeSemantics: true,
        child: Stack(
          children: [
            Positioned(
              top: 15,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: selected ? 0 : 1,
                duration: duration,
                child: Icon(item.icon, size: 20, color: c.tabBarInactive),
              ),
            ),
            AnimatedPositioned(
              top: selected ? 36 : 39,
              left: 0,
              right: 0,
              duration: duration,
              curve: AppMotion.curve,
              child: AnimatedDefaultTextStyle(
                duration: duration,
                style: AppTypography.caption2.copyWith(
                  fontSize: 10,
                  height: 1.6,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? c.tabBarActive : c.tabBarInactive,
                ),
                child: Text(
                  item.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bar body: a rounded rectangle with a curved notch cut from its top
/// edge, centred on [notchX]. Curve geometry is taken from the Figma
/// "Subtract" shape (92pt wide, 30pt deep).
class _NotchedBarPainter extends CustomPainter {
  const _NotchedBarPainter({required this.notchX, required this.color});

  final double notchX;
  final Color color;

  static const double _radius = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final x = notchX;
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(_radius)));
    final notch = Path()
      ..moveTo(x - 46, -1)
      ..lineTo(x - 46, 0)
      ..cubicTo(x - 37.16, 0, x - 30.34, 7.65, x - 25.84, 15.25)
      ..cubicTo(x - 20.62, 24.08, x - 11, 30, x, 30)
      ..cubicTo(x + 11, 30, x + 20.62, 24.08, x + 25.84, 15.25)
      ..cubicTo(x + 30.34, 7.65, x + 37.16, 0, x + 46, 0)
      ..lineTo(x + 46, -1)
      ..close();
    canvas.drawPath(
      Path.combine(PathOperation.difference, body, notch),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_NotchedBarPainter old) =>
      old.notchX != notchX || old.color != color;
}

/// Tab shell: [body] fills the screen and scrolls under the translucent
/// [tabBar]; an optional [accessory] (mini-player) sits just above the bar.
///
/// Per-tab navigation stacks come from the router (go_router's
/// `StatefulShellRoute` gives every branch its own Navigator), so this widget
/// only does layout. The bar + accessory height reaches the pages as bottom
/// `MediaQuery` padding, which `AppScaffold`, `ListView` and `SafeArea`
/// already honour — no screen pads for the bar by hand.
class AppTabScaffold extends StatelessWidget {
  const AppTabScaffold({
    super.key,
    required this.body,
    required this.tabBar,
    this.accessory,
    this.accessoryHeight = 0,
  });

  final Widget body;
  final AppTabBar tabBar;
  final Widget? accessory;

  /// Height reserved for [accessory] (0 when it is hidden).
  final double accessoryHeight;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final barHeight = AppTabBar.totalHeight(context);
    final reserved = barHeight + (accessory == null ? 0 : accessoryHeight);

    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: false,
      child: Stack(
        children: [
          Positioned.fill(
            child: MediaQuery(
              data: media.copyWith(
                padding: media.padding.copyWith(bottom: reserved),
                viewPadding: media.viewPadding.copyWith(bottom: reserved),
              ),
              child: body,
            ),
          ),
          if (accessory != null)
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: barHeight,
              child: accessory!,
            ),
          PositionedDirectional(start: 0, end: 0, bottom: 0, child: tabBar),
        ],
      ),
    );
  }
}
