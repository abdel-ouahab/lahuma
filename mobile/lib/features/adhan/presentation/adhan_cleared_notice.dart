import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/design/design.dart';
import '../../../core/localization/tr.dart';
import '../data/adhan_alarm_platform.dart';
import 'screens/adhan_reliability_screen.dart';

/// How often the notice may come back while the phone keeps cancelling
/// the adhans (someone who swipes the app away every day).
const Duration adhanClearedNoticeGap = Duration(days: 3);

bool shouldShowAdhanClearedNotice(DateTime? lastShown, DateTime now) =>
    lastShown == null || now.difference(lastShown) >= adhanClearedNoticeGap;

/// Android: when this launch found the adhan alarms cancelled (the app was
/// force-stopped, on ColorOS by a swipe from Recents), says so over Home
/// and offers the reliability steps. The launch sync re-arms them.
Future<void> showAdhanClearedNoticeIfNeeded(
    GoRouter router, AdhanAlarmPlatform platform) async {
  if (!await platform.takeCleared()) return;
  final prefs = await SharedPreferences.getInstance();
  final at = prefs.getInt(StorageKeys.adhanClearedNoticeAt);
  final now = DateTime.now();
  if (!shouldShowAdhanClearedNotice(
      at == null ? null : DateTime.fromMillisecondsSinceEpoch(at), now)) {
    return;
  }
  final context = router.routerDelegate.navigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  await prefs.setInt(
      StorageKeys.adhanClearedNoticeAt, now.millisecondsSinceEpoch);
  if (!context.mounted) return;

  final steps = await showAppDialog<bool>(
    context,
    title: context.tr('توقّف الأذان', 'The adhan was stopped'),
    message: context.tr(
      'أوقف هاتفك تطبيق «إحسان» بالكامل، غالباً عند إغلاقه من قائمة التطبيقات الأخيرة، فلم يُرفع الأذان منذ ذلك الحين. أعدنا تفعيله الآن. لكي لا يتكرر هذا لا تغلق «إحسان» من التطبيقات الأخيرة، واتبع خطوات هاتفك.',
      'Your phone fully stopped Ihsan, usually when it is swiped away from Recents, so no adhan has played since. It is back on now. To keep it on, don\'t swipe Ihsan away, and follow the steps for your phone.',
    ),
    actions: [
      AppDialogAction(label: context.tr('حسناً', 'OK'), value: false),
      AppDialogAction(
          label: context.tr('الخطوات', 'Show steps'),
          value: true,
          isDefault: true),
    ],
  );
  if (steps == true) router.push(AdhanReliabilityScreen.path);
}
