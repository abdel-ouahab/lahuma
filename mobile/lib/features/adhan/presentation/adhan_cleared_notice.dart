import 'package:go_router/go_router.dart';
import '../../../core/design/design.dart';
import '../../../core/localization/tr.dart';
import '../data/adhan_alarm_platform.dart';
import 'screens/adhan_reliability_screen.dart';

/// The answers to the "the adhan was stopped" notice.
enum AdhanClearedChoice { hideFromRecents, steps, ok }

/// The notice's buttons, main one first: hiding from Recents is offered
/// until it is on.
List<AdhanClearedChoice> adhanClearedChoices({required bool hidden}) => [
      if (!hidden) AdhanClearedChoice.hideFromRecents,
      AdhanClearedChoice.steps,
      AdhanClearedChoice.ok,
    ];

/// Android: when this launch found the adhan alarms cancelled (the app was
/// force-stopped, on ColorOS by a swipe from Recents), says so over Home,
/// each time it happens: the adhans due since then didn't play. Asks the
/// user to leave Ihsan with Home rather than swiping it, and offers to hide
/// it from Recents and the reliability steps. Hiding only keeps it out of
/// Recents opened elsewhere (and Clear all): Android still lists the app
/// you're in, so a swipe from inside Ihsan stops it all the same (seen on
/// ColorOS). The launch sync has already re-armed them.
Future<void> showAdhanClearedNoticeIfNeeded(
    GoRouter router, AdhanAlarmPlatform platform) async {
  if (!await platform.takeCleared()) return;
  final hidden = (await platform.reliability()).hiddenFromRecents;
  final context = router.routerDelegate.navigatorKey.currentContext;
  if (context == null || !context.mounted) return;

  final choices = adhanClearedChoices(hidden: hidden);
  final choice = await showAppDialog<AdhanClearedChoice>(
    context,
    title: context.tr('توقّف الأذان', 'The adhan was stopped'),
    message: hidden
        ? context.tr(
            'أوقف هاتفك تطبيق «إحسان» بالكامل، غالباً لأنه سُحب من التطبيقات الأخيرة وأنت داخله، فلم يُرفع الأذان منذ ذلك الحين. أعدنا تفعيله الآن. «إحسان» مخفي من التطبيقات الأخيرة، لكنه يظهر فيها إن فتحتها وأنت داخله. لكي لا يتكرر هذا، اخرج منه إلى الشاشة الرئيسية ولا تسحبه.',
            'Your phone fully stopped Ihsan, usually because it was swiped away from recent apps while you were in it, so no adhan has played since. It is back on now. Ihsan is hidden from recent apps, but it still shows there when you open them from inside Ihsan. To keep this from happening, leave it by going to the Home screen, not by swiping it away.',
          )
        : context.tr(
            'أوقف هاتفك تطبيق «إحسان» بالكامل، غالباً لأنه سُحب من التطبيقات الأخيرة، فلم يُرفع الأذان منذ ذلك الحين. أعدنا تفعيله الآن. لكي لا يتكرر هذا، اخرج من «إحسان» إلى الشاشة الرئيسية ولا تسحبه. وإخفاؤه من التطبيقات الأخيرة يحميه أيضاً من «مسح الكل».',
            'Your phone fully stopped Ihsan, usually because it was swiped away from recent apps, so no adhan has played since. It is back on now. To keep this from happening, leave Ihsan by going to the Home screen, not by swiping it away. Hiding it from recent apps also keeps it out of Clear all.',
          ),
    actions: [
      for (final c in choices)
        AppDialogAction(
          label: switch (c) {
            AdhanClearedChoice.hideFromRecents => context.tr(
                'أخفِه من التطبيقات الأخيرة', 'Hide from recent apps'),
            AdhanClearedChoice.steps => context.tr('الخطوات', 'Show steps'),
            AdhanClearedChoice.ok => context.tr('حسناً', 'OK'),
          },
          value: c,
          isDefault: c == choices.first,
        ),
    ],
  );

  switch (choice) {
    case AdhanClearedChoice.hideFromRecents:
      // The message has said what this does; no toast, since this runs at
      // launch outside any page (no overlay to show one in).
      await platform.setHiddenFromRecents(true);
    case AdhanClearedChoice.steps:
      router.push(AdhanReliabilityScreen.path);
    case AdhanClearedChoice.ok:
    case null:
      break;
  }
}
