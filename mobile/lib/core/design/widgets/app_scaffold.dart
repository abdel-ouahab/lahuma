import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';
import '../app_spacing.dart';
import 'app_states.dart';

/// Page scaffold.
///
/// * [AppScaffold.new] — pushed screens: standard (small, centred) title bar
///   with the system back chevron (mirrored and on the right in RTL).
/// * [AppScaffold.largeTitle] — tab roots: a large title that collapses into
///   the bar on scroll, optional search / segmented control under it and
///   pull-to-refresh.
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
    required String this.title,
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
          CupertinoSliverNavigationBar(
            largeTitle: Text(title!),
            leading: leading,
            trailing: trailing,
            bottom: bottom,
            bottomMode: bottom == null ? null : NavigationBarBottomMode.always,
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

/// iOS tab bar: translucent blurred material, hairline top border, icon +
/// short label, accent for the selected tab, selection haptic on change.
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

  /// Bar height above the home indicator.
  static const double height = 50;

  /// Height including the bottom safe area.
  static double totalHeight(BuildContext context) =>
      height + MediaQuery.viewPaddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.0,
      child: CupertinoTabBar(
        currentIndex: currentIndex,
        height: height,
        iconSize: 26,
        activeColor: AppColors.accent,
        backgroundColor: AppColors.barBackground,
        border: Border(
            top: BorderSide(color: c.separator, width: AppSpacing.hairline)),
        onTap: (i) {
          if (i != currentIndex) HapticFeedback.selectionClick();
          onTap(i);
        },
        items: [
          for (final item in items)
            BottomNavigationBarItem(
              icon: Icon(item.icon),
              activeIcon: Icon(item.activeIcon),
              label: item.label,
            ),
        ],
      ),
    );
  }
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
