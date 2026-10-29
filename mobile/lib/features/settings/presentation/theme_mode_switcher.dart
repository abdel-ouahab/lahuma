import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_settings_enum.dart';
import '../../../core/design/app_theme.dart';
import 'settings_providers.dart';

typedef SwitchThemeMode = void Function(AppThemeMode mode);

/// Gives [builder] a callback that changes the theme mode with a circular
/// reveal centred on the widget it builds.
///
/// [themeModeProvider] stays the source of truth: the reveal only plays when
/// the visible brightness actually flips, and not under reduce motion.
class ThemeModeSwitcher extends ConsumerWidget {
  const ThemeModeSwitcher({super.key, required this.builder});

  final Widget Function(BuildContext context, SwitchThemeMode switchTo) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ThemeSwitcher.switcher(
      builder: (context, switcher) => builder(context, (mode) {
        final notifier = ref.read(themeModeProvider.notifier);
        final model = ThemeModelInheritedNotifier.of(context);
        if (model.controller.isAnimating) return;

        final target = switch (mode) {
          AppThemeMode.light => Brightness.light,
          AppThemeMode.dark => Brightness.dark,
          AppThemeMode.system => MediaQuery.platformBrightnessOf(context),
        };
        if (target == Theme.of(context).brightness ||
            MediaQuery.disableAnimationsOf(context)) {
          notifier.update(mode);
          return;
        }

        // The switcher snapshots the old screen before it starts revealing.
        // Rebuilding the app in the new theme before that snapshot is up
        // would flash it, so the mode is only committed once the model
        // notifies that the snapshot is ready.
        var committed = false;
        void commit() {
          if (committed) return;
          committed = true;
          model.removeListener(commit);
          notifier.update(mode);
        }

        model.addListener(commit);
        switcher.changeTheme(
          theme: target == Brightness.dark ? AppTheme.dark : AppTheme.light,
          // Dark grows out of the control; light shrinks the dark away into it.
          isReversed: target == Brightness.light,
          onAnimationFinish: commit,
        );
      }),
    );
  }
}
