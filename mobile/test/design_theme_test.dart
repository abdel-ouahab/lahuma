import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lahuma/core/design/app_colors.dart';
import 'package:lahuma/core/design/app_theme.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<BuildContext> pumpApp(
    WidgetTester tester, {
    required ThemeMode mode,
    required Brightness platform,
  }) async {
    tester.platformDispatcher.platformBrightnessTestValue = platform;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    late BuildContext captured;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      builder: AppTheme.builder,
      home: Builder(builder: (context) {
        captured = context;
        return const SizedBox();
      }),
    ));
    return captured;
  }

  testWidgets('forced dark wins over a light system setting', (tester) async {
    final context =
        await pumpApp(tester, mode: ThemeMode.dark, platform: Brightness.light);
    expect(context.palette.isDark, isTrue);
    expect(
        context.palette.label, isSameColorAs(AppColors.label.darkColor));
    expect(context.palette.accent, isSameColorAs(AppColors.accent.darkColor));
    expect(context.palette.groupedBackground,
        isSameColorAs(AppColors.groupedBackground.darkColor));
  });

  testWidgets('forced light wins over a dark system setting', (tester) async {
    final context =
        await pumpApp(tester, mode: ThemeMode.light, platform: Brightness.dark);
    expect(context.palette.isDark, isFalse);
    expect(context.palette.label, isSameColorAs(AppColors.label.color));
    expect(context.palette.accent, isSameColorAs(AppColors.accent.color));
  });

  testWidgets('system mode follows the platform brightness', (tester) async {
    final context = await pumpApp(tester,
        mode: ThemeMode.system, platform: Brightness.dark);
    expect(
        context.palette.label, isSameColorAs(AppColors.label.darkColor));
    expect(CupertinoTheme.of(context).primaryColor,
        isSameColorAs(AppColors.accent.darkColor));
  });

  testWidgets('routes get the Cupertino body style, not the debug error style',
      (tester) async {
    final context = await pumpApp(tester,
        mode: ThemeMode.light, platform: Brightness.light);
    final style = DefaultTextStyle.of(context).style;
    expect(style.decoration, TextDecoration.none);
    expect(style.fontSize, 17);
    expect(style.color, isSameColorAs(AppColors.label.color));
  });
}
